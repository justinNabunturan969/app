-- =============================================================================
-- 0027 — Data retention: scheduled pruning of append-only tables
-- =============================================================================
-- Four tables grew without bound:
--
--   * sign_in_rate_limit   rows for identifiers that NEVER succeed
--                          (probed student numbers) persisted forever;
--                          the row is only deleted on a successful login.
--   * session_end_cooldown pruned only opportunistically inside
--                          start_active_session (0013), i.e. only while
--                          users are signing in.
--   * session_history      one immutable row per ended session.
--   * borrowing_audit_log  one row per status transition.
--
-- Fix: a daily pg_cron job deletes anything past its retention window.
-- Windows chosen generously — this data is small per-row; the point is a
-- bounded table, not aggressive deletion:
--
--   sign_in_rate_limit    30 days after the last failure window started
--                         (active lockouts are always < 15 min old)
--   session_end_cooldown  1 day  (the resurrection guard only needs 60s)
--   session_history       120 days
--   borrowing_audit_log   365 days (audit trail — keep the longest)
--
-- Safe to re-run: unschedule + reschedule under a fixed job name.

create or replace function public._prune_old_data()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_rate int; v_cooldown int; v_history int; v_audit int;
begin
  delete from public.sign_in_rate_limit
   where first_failed_at < now() - interval '30 days'
     and (locked_until is null or locked_until < now());
  get diagnostics v_rate = row_count;

  delete from public.session_end_cooldown
   where ended_at < now() - interval '1 day';
  get diagnostics v_cooldown = row_count;

  delete from public.session_history
   where ended_at < now() - interval '120 days';
  get diagnostics v_history = row_count;

  delete from public.borrowing_audit_log
   where created_at < now() - interval '365 days';
  get diagnostics v_audit = row_count;

  return jsonb_build_object(
    'sign_in_rate_limit', v_rate,
    'session_end_cooldown', v_cooldown,
    'session_history', v_history,
    'borrowing_audit_log', v_audit
  );
end;
$$;

revoke all on function public._prune_old_data() from public;
revoke all on function public._prune_old_data() from anon;
revoke all on function public._prune_old_data() from authenticated;

do $$
begin
  if to_regnamespace('cron') is null then
    raise warning 'pg_cron is not available — retention pruning will NOT run automatically.';
    return;
  end if;

  perform cron.unschedule(jobid) from cron.job where jobname = 'itech_retention_pruning';

  -- Daily at 03:20 GMT — off-peak for the Philippine deployment.
  perform cron.schedule(
    'itech_retention_pruning',
    '20 3 * * *',
    $job$ select public._prune_old_data(); $job$
  );
end;
$$;
