-- =============================================================================
-- 0020 — Scheduled server-side maintenance (pg_cron)
-- =============================================================================
-- Two pieces of housekeeping used to depend on an admin happening to be
-- online, and one never ran at all:
--
--   1. OVERDUE LOANS: nothing ever transitioned `borrowings.status` to
--      'overdue' when `due_at` passed. The trigger's overdue-notification
--      branch (0001), the client's Overdue bucket, and getOverdue() were
--      dead code — overdue loans stayed 'active' forever.
--
--   2. STALE SESSIONS: `expire_stale_sessions()` was only invoked from
--      `getActiveSessions()` (supabase_user_repository.dart) — i.e. only
--      while an admin watched the Live tab. No admin online meant stale
--      sessions lingered and `session_history` 'expired' entries were
--      never written.
--
-- Fix: two pg_cron jobs running every minute. The overdue sweep performs a
-- plain `status = 'overdue'` UPDATE, which fires the existing
-- `handle_borrowing_status_change` trigger and delivers the notification
-- through the exact code path the app already understands.
--
-- Requires the `pg_cron` extension (pre-approved on Supabase). Safe to
-- re-run: jobs are unscheduled and re-created under fixed names.

create extension if not exists pg_cron with schema extensions;

-- -----------------------------------------------------------------------------
-- Core sweeps.
--
-- These deliberately have NO `is_admin()` gate: pg_cron executes as the
-- `postgres` role with no request.jwt claim context, so `auth.uid()` is NULL
-- there and the admin check in `expire_stale_sessions()` would always fail.
-- They are SECURITY DEFINER internals — execution is revoked from every
-- Data API role below; only the cron daemon and the gated wrapper call them.
-- -----------------------------------------------------------------------------

create or replace function public._sweep_expired_sessions()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer;
begin
  -- Heartbeat cadence is 30s; anything quiet for 2 minutes is gone.
  -- Every end path writes an immutable history row first (0006).
  with expired as (
    delete from public.active_sessions
     where last_activity_at < now() - interval '2 minutes'
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

create or replace function public._flag_overdue_borrowings()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer;
begin
  -- Flip active loans whose due date has passed. The per-row AFTER UPDATE
  -- trigger (0001) sees active -> overdue and inserts the "Equipment
  -- overdue" notification for each borrower; equipment counts are untouched,
  -- exactly like a manual admin transition.
  with flagged as (
    update public.borrowings
       set status = 'overdue'
     where status = 'active'
       and due_at is not null
       and due_at < now()
    returning 1
  )
  select count(*) into v_count from flagged;
  return v_count;
end;
$$;

revoke all on function public._sweep_expired_sessions() from public;
revoke all on function public._sweep_expired_sessions() from anon;
revoke all on function public._sweep_expired_sessions() from authenticated;
revoke all on function public._flag_overdue_borrowings() from public;
revoke all on function public._flag_overdue_borrowings() from anon;
revoke all on function public._flag_overdue_borrowings() from authenticated;

-- Fast path for the recurring overdue scan (partial: only candidates).
create index if not exists borrowings_active_due_idx
  on public.borrowings (due_at)
  where status = 'active';

-- -----------------------------------------------------------------------------
-- Keep the public API intact: `expire_stale_sessions()` stays admin-only
-- (the Live-tab caller keeps working) but now delegates to the shared core
-- so both paths behave identically.
-- -----------------------------------------------------------------------------
create or replace function public.expire_stale_sessions()
returns integer
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then raise exception 'Admin access is required'; end if;
  return public._sweep_expired_sessions();
end;
$$;

-- Grants unchanged from 0006/0012 (authenticated only).
revoke all on function public.expire_stale_sessions() from public;
grant execute on function public.expire_stale_sessions() to authenticated;

-- -----------------------------------------------------------------------------
-- Scheduling. Fixed job names make this idempotent: re-running replaces the
-- previous definition instead of stacking duplicates.
-- -----------------------------------------------------------------------------
do $$
begin
  if to_regnamespace('cron') is null then
    raise warning 'pg_cron is not available on this database — '
      'overdue flagging and stale-session sweeping will NOT run automatically. '
      'Enable the pg_cron extension and re-run this migration.';
    return;
  end if;

  perform cron.unschedule(jobid) from cron.job where jobname = 'itech_session_sweep';
  perform cron.unschedule(jobid) from cron.job where jobname = 'itech_overdue_flagging';

  -- Sessions go stale after 2 minutes; a 60-second sweep keeps the Live tab
  -- and history accurate without waiting for an admin to look.
  perform cron.schedule(
    'itech_session_sweep',
    '* * * * *',
    $job$ select public._sweep_expired_sessions(); $job$
  );

  -- Overdue precision of one minute matches how often due_at can realistically
  -- matter; the partial index keeps the scan trivially cheap.
  perform cron.schedule(
    'itech_overdue_flagging',
    '* * * * *',
    $job$ select public._flag_overdue_borrowings(); $job$
  );
end;
$$;
