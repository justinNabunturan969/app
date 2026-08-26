-- =============================================================================
-- 0019 — Sign-in attempt feedback for the student login screen
-- =============================================================================
-- The rate limiter in 0018 silently counts failures in
-- `public.sign_in_rate_limit`, so the client can only show a generic "wrong
-- credentials" message. This adds a read-only RPC the login screen calls
-- AFTER a failed attempt to surface:
--
--   * how many attempts remain before the 5-minute lockout, and
--   * when locked: `locked_until` + `seconds_remaining` for a live countdown.
--
-- Read-only by design — it never mutates the counter, so it cannot be used to
-- reset or advance the lockout. Safe to re-run.

create or replace function public.sign_in_attempt_status(p_identifier text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  -- Must mirror the constants inside sign_in_identifier (0018).
  c_max_failures constant int      := 5;
  c_window       constant interval := interval '15 minutes';

  v_key text := lower(btrim(coalesce(p_identifier, '')));
  v_row public.sign_in_rate_limit%rowtype;
begin
  if v_key = '' then
    return jsonb_build_object(
      'failed_attempts', 0,
      'attempts_left',   c_max_failures,
      'locked',          false
    );
  end if;

  select * into v_row
    from public.sign_in_rate_limit
   where identifier_key = v_key;

  -- No record, or the failure window already expired: the counter is stale
  -- (the next real attempt would reset it), so report a clean slate.
  if not found or v_row.first_failed_at < now() - c_window then
    return jsonb_build_object(
      'failed_attempts', 0,
      'attempts_left',   c_max_failures,
      'locked',          false
    );
  end if;

  if v_row.locked_until is not null and v_row.locked_until > now() then
    return jsonb_build_object(
      'failed_attempts',   v_row.failed_attempts,
      'attempts_left',     0,
      'locked',            true,
      'locked_until',      v_row.locked_until,
      'seconds_remaining', ceil(extract(epoch from (v_row.locked_until - now())))::int
    );
  end if;

  return jsonb_build_object(
    'failed_attempts', v_row.failed_attempts,
    'attempts_left',   greatest(c_max_failures - v_row.failed_attempts, 0),
    'locked',          false
  );
end;
$$;

revoke all on function public.sign_in_attempt_status(text) from public;
grant execute on function public.sign_in_attempt_status(text) to anon;
grant execute on function public.sign_in_attempt_status(text) to authenticated;
