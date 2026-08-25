-- =============================================================================
-- Cleanup: drop dead database objects left behind by earlier migrations
-- =============================================================================
-- Safe for any deployment: both functions are unused by the current app
-- build and neither holds data.

-- `touch_active_session()` became redundant in 0007 when
-- `start_active_session()` turned into an upsert covering both the insert
-- and heartbeat paths. No client calls it anymore.
drop function if exists public.touch_active_session();

-- `auth_email_for_student_id(text)` mapped a student number to an auth
-- email. It was an enumeration risk and migration 0011 already revoked all
-- execute grants; the function itself is now removed entirely.
drop function if exists public.auth_email_for_student_id(text);

-- While here, finish the grant hardening that 0005/0006 started:
-- `transition_borrowing` was never explicitly revoked from `public` /
-- granted to `authenticated`, unlike its sibling RPCs. It is internally
-- guarded, but the explicit grants match the posture of migration 0011.
revoke all on function public.transition_borrowing(uuid, text) from public;
revoke all on function public.transition_borrowing(uuid, text) from anon;
grant execute on function public.transition_borrowing(uuid, text) to authenticated;
