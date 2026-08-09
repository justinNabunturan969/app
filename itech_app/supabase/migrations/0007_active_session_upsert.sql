-- Live session upsert: keep `logged_in_at` stable across heartbeats.
--
-- Before this migration, `start_active_session()` did
--   `on conflict (profile_id) do update set logged_in_at = excluded.logged_in_at, ...`
-- which reset `logged_in_at` to `now()` on every heartbeat. That broke the
-- admin's "Logged in Xm ago" display and, more importantly, was the only
-- function in the client that could re-create a deleted `active_sessions`
-- row — so once `expire_stale_sessions` (or the `onPause` / `onHide`
-- lifecycle hook) removed the row, a returning student could not come back
-- online without a full sign-out + sign-in cycle.
--
-- The new behaviour:
--   * On INSERT  — set `logged_in_at` and `last_activity_at` to `now()`
--                   and `activity = 'active'`. (Same as before.)
--   * On CONFLICT — only refresh `last_activity_at` and `activity`.
--                   `logged_in_at` is left untouched, so the displayed
--                   "Logged in Xm ago" reflects the original sign-in.
--
-- This makes the function safe to call from both the login flow
-- (`auth_session_storage._signInOrThrow`) and the heartbeat
-- (`SessionLifecycleGuard`'s 30s tick), so a missing row is always
-- restored on the next heartbeat.

create or replace function public.start_active_session()
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Authentication is required'; end if;
  insert into public.active_sessions(profile_id, logged_in_at, last_activity_at, activity)
  values (auth.uid(), now(), now(), 'active')
  on conflict (profile_id) do update set
    last_activity_at = excluded.last_activity_at,
    activity = 'active';
end; $$;

-- `touch_active_session` is now redundant — the upsert above does the
-- right thing for both insert and update paths. We keep it for backwards
-- compatibility (the Supabase JS client's RPC is name-addressed, and we
-- don't want to break any deployed clients) but redirect it to the same
-- body so a stale caller still gets the upsert semantics.
create or replace function public.touch_active_session()
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Authentication is required'; end if;
  insert into public.active_sessions(profile_id, logged_in_at, last_activity_at, activity)
  values (auth.uid(), now(), now(), 'active')
  on conflict (profile_id) do update set
    last_activity_at = excluded.last_activity_at,
    activity = 'active';
end; $$;

revoke all on function public.start_active_session() from public;
revoke all on function public.touch_active_session() from public;
grant execute on function public.start_active_session() to authenticated;
grant execute on function public.touch_active_session() to authenticated;
