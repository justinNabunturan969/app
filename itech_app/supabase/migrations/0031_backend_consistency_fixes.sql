-- =============================================================================
-- 0031 — Backend consistency fixes
-- =============================================================================
-- Four fixes found in a full backend audit:
--
--   1. SESSION WINDOW REGRESSION: 0020's cron sweep `_sweep_expired_sessions`
--      hard-coded the OLD 2-minute stale window, silently reverting the
--      deliberate 2 -> 5 minute loosening from 0009 (mobile browsers throttle
--      JS timers when backgrounded, so a 2-minute drop was too aggressive).
--      Since 0020 also delegates expire_stale_sessions() to this function,
--      the 5-minute behaviour was gone everywhere. Restored below.
--
--   2. CHANGE EMAIL BROKE when Supabase applied the change immediately:
--      protect_profile_identity (0011) rejected ANY owner update of
--      profiles.email, including the legitimate mirror of the NEW auth email
--      performed by the app right after a successful updateUser. The trigger
--      now allows the update when the new email EXACTLY mirrors the caller's
--      auth.users email — arbitrary rewrites stay blocked.
--
--   3. CHANGE STUDENT ID COULD NEVER SUCCEED: the same trigger rejected every
--      owner change of a non-null student_id, but the product ships that
--      feature. Direct Data-API updates remain BLOCKED; a new controlled RPC
--      `change_own_student_id(text)` allows it with server-side format
--      validation, uniqueness check, and a 7-day-per-account cooldown so the
--      number cannot be cycled to impersonate or squat other students' IDs.
--
--   4. NOTIFICATION UNDO WAS DEAD: 0003 dropped the self-insert policy and
--      0011 granted no INSERT on notifications, but the app kept (and still
--      surfaces) a delete->undo flow that INSERTs the row back. Forging a
--      notification addressed TO YOURSELF is harmless (only you see it), so
--      the scoped policy and grant are reinstated.
--
-- Safe to re-run.
-- =============================================================================

-- ── Fix 1: restore the 5-minute stale window on the shared cron core ────────
create or replace function public._sweep_expired_sessions()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer;
begin
  -- Heartbeat cadence is 30s. 5 minutes matches migration 0009's rationale:
  -- mobile-web clients get timer-throttled while backgrounded, and a student
  -- who briefly backgrounds the app must not be expired before they return.
  with expired as (
    delete from public.active_sessions
     where last_activity_at < now() - interval '5 minutes'
     returning profile_id, logged_in_at, last_activity_at
  ), logged as (
    insert into public.session_history(profile_id, logged_in_at, last_activity_at, end_reason)
    select profile_id, logged_in_at, last_activity_at, 'expired' from expired
    returning 1
  )
  select count(*) into v_count from logged;
  return v_count;
end;
$$;

revoke all on function public._sweep_expired_sessions() from public;
revoke all on function public._sweep_expired_sessions() from anon;
revoke all on function public._sweep_expired_sessions() from authenticated;

-- ── Fixes 2 + 3: relax identity protection the safe way ────────────────────
create or replace function public.protect_profile_identity()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() = old.id then
    -- Email: the profile column mirrors auth.users. Allow the mirror (the
    -- app syncs it after Supabase applies an email change); block anything
    -- that does not match the real auth address.
    if new.email is distinct from old.email then
      if new.email is distinct from
         (select u.email from auth.users u where u.id = old.id) then
        raise exception 'Profile email is managed by authentication';
      end if;
    end if;

    -- Student ID: direct updates stay blocked. The controlled
    -- `change_own_student_id()` RPC sets this transaction-local flag after
    -- validating format, uniqueness, and the cooldown.
    if old.student_id is not null
       and new.student_id is distinct from old.student_id then
      if coalesce(current_setting('app.student_id_change', true), '') <> 'on' then
        raise exception 'Student ID cannot be changed';
      end if;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists on_profile_identity_change on public.profiles;
create trigger on_profile_identity_change
  before update on public.profiles
  for each row execute function public.protect_profile_identity();

-- ── Fix 3 (cont.): controlled student-ID change RPC ─────────────────────────
-- Cooldown ledger. RLS enabled with NO policies and no table grants: invisible
-- to both Data API roles; only the SECURITY DEFINER RPC touches it.
create table if not exists public.student_id_changes (
  profile_id uuid primary key references public.profiles (id) on delete cascade,
  changed_at timestamptz not null default now()
);

alter table public.student_id_changes enable row level security;

revoke all on public.student_id_changes from public;
revoke all on public.student_id_changes from anon;
revoke all on public.student_id_changes from authenticated;

create or replace function public.change_own_student_id(p_new_student_id text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_new text := btrim(coalesce(p_new_student_id, ''));
begin
  if auth.uid() is null then
    raise exception 'Authentication is required';
  end if;

  -- Strict school format, same regex the client validates with.
  if v_new !~ '^[0-9]{4}-[0-9]{5}-[A-Za-z]{2}-[0-9]$' then
    raise exception 'Invalid format. Expected YYYY-XXXXX-XX-X (e.g., 2024-08721-MN-0).';
  end if;

  -- Abuse guard: an ID cannot be cycled frequently to impersonate other
  -- students or to probe/squat their numbers. Seven days per account.
  if exists (
    select 1 from public.student_id_changes
     where profile_id = auth.uid()
       and changed_at > now() - interval '7 days'
  ) then
    raise exception 'You can change your student ID only once every 7 days.';
  end if;

  -- Friendly duplicate check (the unique constraint is the backstop).
  if exists (
    select 1 from public.profiles p
     where lower(btrim(coalesce(p.student_id, ''))) = lower(v_new)
       and p.id <> auth.uid()
  ) then
    raise exception 'That student ID is already linked to another account.';
  end if;

  -- Unblocks protect_profile_identity for exactly this transaction.
  perform set_config('app.student_id_change', 'on', true);

  update public.profiles
     set student_id = v_new
   where id = auth.uid();
  if not found then
    raise exception 'You are no longer signed in.';
  end if;

  insert into public.student_id_changes (profile_id)
  values (auth.uid())
  on conflict (profile_id) do update set changed_at = excluded.changed_at;
end;
$$;

revoke all on function public.change_own_student_id(text) from public;
revoke all on function public.change_own_student_id(text) from anon;
grant execute on function public.change_own_student_id(text) to authenticated;

-- ── Fix 4: reinstated scoped self-insert for the notification undo flow ────
-- A user can only ever forge rows into their OWN inbox, which they can
-- already clear at will — no information gained, no one else affected.
grant insert on public.notifications to authenticated;

drop policy if exists "notifications_insert_self" on public.notifications;
create policy "notifications_insert_self"
  on public.notifications for insert to authenticated
  with check ((select auth.uid()) = recipient_id);

-- ── Improvement: lock the equipment row during the availability check ──────
-- Matches the approve path (`FOR UPDATE`), so two concurrent requests cannot
-- both pass the count check before either commits. Same body as 0029 plus
-- the row lock and a friendlier availability message.
create or replace function public.request_borrowing(
  p_equipment_id uuid,
  p_purpose text default '',
  p_quantity integer default 1
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_borrowing public.borrowings;
  v_available_count integer;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required';
  end if;
  if p_quantity is null or p_quantity < 1 then
    raise exception 'Choose at least one item';
  end if;

  select available_count into v_available_count
    from public.equipment
   where id = p_equipment_id and status = 'available'
   for update;
  if not found or v_available_count < p_quantity then
    raise exception 'Only % unit(s) remain available', coalesce(v_available_count, 0);
  end if;

  begin
    insert into public.borrowings (student_id, equipment_id, status, purpose, quantity)
    values (auth.uid(), p_equipment_id, 'pending', left(coalesce(p_purpose, ''), 500), p_quantity)
    returning * into v_borrowing;
  exception when unique_violation then
    select * into v_borrowing
      from public.borrowings
     where student_id = auth.uid()
       and equipment_id = p_equipment_id
       and status in ('pending', 'approved', 'active', 'overdue')
     order by requested_at desc
     limit 1;
    if not found then raise; end if;
  end;

  return public._borrowing_json(v_borrowing.id);
end;
$$;

revoke all on function public.request_borrowing(uuid, text, integer) from public;
grant execute on function public.request_borrowing(uuid, text, integer) to authenticated;
