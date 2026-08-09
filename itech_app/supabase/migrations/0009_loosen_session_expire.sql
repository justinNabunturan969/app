-- Loosen the live-occupancy stale window from 2 minutes to 5 minutes.
--
-- The 2-minute window was too aggressive for mobile-web clients, where
-- the browser throttles JavaScript timers (and bfcache may freeze the
-- tab entirely) the moment the user locks the phone, switches apps, or
-- loses window focus. A student who briefly backgrounded the app was
-- losing their `active_sessions` row before they came back, which
-- made the admin's Live tab flip to "0 online" for the entire window
-- — even though the user was still on the device and would re-emit a
-- heartbeat within seconds of returning.
--
-- The 30-second client heartbeat still runs in `SessionLifecycleGuard`,
-- so an actively-using student is well inside the 5-minute window.
-- A student who actually leaves and never returns is now cleaned up
-- after 5 minutes of silence, which is a fine upper bound for a
-- lab-attendance feed.

create or replace function public.expire_stale_sessions()
returns integer language plpgsql security definer set search_path = public as $$
declare v_count integer;
begin
  if not public.is_admin() then raise exception 'Admin access is required'; end if;
  with expired as (
    delete from public.active_sessions
     where last_activity_at < now() - interval '5 minutes'
     returning profile_id, logged_in_at, last_activity_at
  ), logged as (
    insert into public.session_history(profile_id, logged_in_at, last_activity_at, end_reason)
    select profile_id, logged_in_at, last_activity_at, 'expired' from expired
    returning 1
  ) select count(*) into v_count from logged;
  return v_count;
end; $$;
