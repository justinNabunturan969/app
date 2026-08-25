-- =============================================================================
-- Force-logout notices: tell the kicked user WHY they were signed out
-- =============================================================================
-- Until now an admin force-logout deleted the user's `active_sessions` row
-- and the kicked device simply signed out silently. The user had no idea
-- what happened. This migration adds a one-shot notice:
--
--   1. `force_logout_notices` — one row per profile, holding the admin's
--      reason. RLS lets a user read ONLY their own notice; writes happen
--      exclusively inside the SECURITY DEFINER `end_active_session` RPC.
--
--   2. `end_active_session` gains an optional `p_note` parameter. When the
--      action is a force_logout, the note is stored as the notice. Adding a
--      parameter changes the signature, so the old two-argument overload is
--      dropped after the replacement is created.
--
--   3. `consume_force_logout_notice()` — the kicked device calls this ONCE
--      while still authenticated: it returns the reason and deletes the
--      row atomically, so the message is shown exactly once.

create table if not exists public.force_logout_notices (
  profile_id uuid primary key references public.profiles (id) on delete cascade,
  reason text not null default 'Your session was ended by an administrator.',
  ended_at timestamptz not null default now(),
  ended_by uuid references public.profiles (id) on delete set null
);

alter table public.force_logout_notices enable row level security;

revoke all on public.force_logout_notices from public;
revoke all on public.force_logout_notices from anon;
revoke all on public.force_logout_notices from authenticated;

-- The kicked user may read their own notice (that is the whole point).
-- There are deliberately no insert/update/delete policies: only the
-- SECURITY DEFINER RPCs below may write.
create policy "force_logout_notice_select_own"
  on public.force_logout_notices for select
  to authenticated
  using ((select auth.uid()) = profile_id);

grant select on public.force_logout_notices to authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- end_active_session: same behaviour as 0013 plus the notice write.
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.end_active_session(
  p_profile_id uuid,
  p_reason text,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_session public.active_sessions;
  v_reason text;
  v_notice text;
begin
  if auth.uid() is null then raise exception 'Authentication is required'; end if;
  if p_profile_id <> auth.uid() and not public.is_admin() then raise exception 'Not allowed'; end if;
  v_reason := case when p_profile_id <> auth.uid() then 'force_logout' else p_reason end;
  if v_reason not in ('closed', 'signed_out', 'force_logout') then raise exception 'Invalid session end reason'; end if;

  select * into v_session from public.active_sessions where profile_id = p_profile_id for update;
  if not found then return; end if;

  insert into public.session_history(profile_id, logged_in_at, last_activity_at, end_reason)
    values (v_session.profile_id, v_session.logged_in_at, v_session.last_activity_at, v_reason);
  delete from public.active_sessions where profile_id = p_profile_id;

  -- Record the cooldown so the kicked client's next heartbeat cannot
  -- resurrect the row (see start_active_session in 0013).
  insert into public.session_end_cooldown(profile_id, ended_at, end_reason)
    values (p_profile_id, now(), v_reason)
    on conflict (profile_id) do update set ended_at = excluded.ended_at, end_reason = excluded.end_reason;

  -- Force logout: leave a one-shot reason the kicked device shows on the
  -- login screen. Blank notes fall back to the default wording.
  if v_reason = 'force_logout' then
    v_notice := coalesce(
      nullif(btrim(coalesce(p_note, '')), ''),
      'Your session was ended by an administrator.'
    );
    insert into public.force_logout_notices (profile_id, reason, ended_by)
      values (p_profile_id, v_notice, auth.uid())
      on conflict (profile_id) do update
        set reason = excluded.reason,
            ended_at = now(),
            ended_by = excluded.ended_by;
  end if;
end;
$$;

-- The two-argument overload from 0013 is superseded; drop it so there is
-- exactly one surface, then re-apply the grants on the new signature.
drop function if exists public.end_active_session(uuid, text);

revoke all on function public.end_active_session(uuid, text, text) from public;
revoke all on function public.end_active_session(uuid, text, text) from anon;
grant execute on function public.end_active_session(uuid, text, text) to authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- One-shot read: returns the reason and deletes the notice atomically.
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.consume_force_logout_notice()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reason text;
begin
  if auth.uid() is null then return null; end if;

  delete from public.force_logout_notices
   where profile_id = auth.uid()
   returning reason into v_reason;

  return v_reason;
end;
$$;

revoke all on function public.consume_force_logout_notice() from public;
revoke all on function public.consume_force_logout_notice() from anon;
grant execute on function public.consume_force_logout_notice() to authenticated;
