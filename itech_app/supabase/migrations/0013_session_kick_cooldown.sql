-- =============================================================================
-- Prevent a force-logged-out user from being resurrected by their heartbeat
-- =============================================================================
-- Bug: `end_active_session` (admin kick) deletes the `active_sessions` row,
-- but the kicked client's 30-second heartbeat calls `start_active_session()`,
-- which is an upsert — so it silently re-inserted the row and the user
-- reappeared on the admin's Live tab seconds after being kicked.
--
-- Fix: record a short "cooldown" when a session ends. `start_active_session`
-- refuses to re-create a row if that same profile's session was ended by an
-- admin within the last 60 seconds. Ordinary paths (sign-out, tab close,
-- expiry) are unaffected — a genuine new sign-in always creates a fresh row
-- because Supabase Auth issues a new sign-in event, and the cooldown only
-- blocks the *heartbeat* path, not explicit logins.
--
-- The cooldown lives in a tiny table rather than in memory so it survives
-- across PostgREST connections. Rows are pruned opportunistically.

create table if not exists public.session_end_cooldown (
  profile_id uuid primary key references public.profiles(id) on delete cascade,
  ended_at timestamptz not null default now(),
  end_reason text not null
);

revoke all on public.session_end_cooldown from public;
revoke all on public.session_end_cooldown from anon;
revoke all on public.session_end_cooldown from authenticated;

-- How long after a force-logout a heartbeat may not resurrect the session.
create or replace function public._session_resurrection_window()
returns interval
language sql
stable
as $$ select interval '60 seconds' $$;

create or replace function public.start_active_session()
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Authentication is required'; end if;

  -- Opportunistic prune of old cooldown rows (cheap, indexed by PK).
  delete from public.session_end_cooldown where ended_at < now() - interval '1 hour';

  -- Block resurrection: if this profile was force-logged-out recently,
  -- ignore the heartbeat instead of re-inserting the row.
  if exists (
    select 1 from public.session_end_cooldown
    where profile_id = auth.uid()
      and end_reason = 'force_logout'
      and ended_at > now() - public._session_resurrection_window()
  ) then
    return;
  end if;

  insert into public.active_sessions(profile_id, logged_in_at, last_activity_at, activity)
  values (auth.uid(), now(), now(), 'active')
  on conflict (profile_id) do update set
    last_activity_at = excluded.last_activity_at,
    activity = 'active';
end; $$;

create or replace function public.end_active_session(p_profile_id uuid, p_reason text)
returns void language plpgsql security definer set search_path = public as $$
declare v_session public.active_sessions; v_reason text;
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
  -- resurrect the row (see start_active_session above).
  insert into public.session_end_cooldown(profile_id, ended_at, end_reason)
  values (p_profile_id, now(), v_reason)
  on conflict (profile_id) do update set ended_at = excluded.ended_at, end_reason = excluded.end_reason;
end; $$;

-- Keep grants consistent with migration 0012.
revoke all on function public.start_active_session() from public;
grant execute on function public.start_active_session() to authenticated;
revoke all on function public.end_active_session(uuid, text) from public;
grant execute on function public.end_active_session(uuid, text) to authenticated;
