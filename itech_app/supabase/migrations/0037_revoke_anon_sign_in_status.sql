-- =============================================================================
-- 0037 — Revoke anon execute on sign_in_attempt_status
-- =============================================================================
-- Migration 0019 grants `anon` and `authenticated` execute on
-- `sign_in_attempt_status(p_identifier)`. The function returns
-- `{attempts_left, locked_until}` for the given identifier, which means
-- a caller can probe the existence of every student ID by reading
-- `attempts_left` without ever sending a wrong password:
--   - a real account returns 5 (or the remaining count) on first probe,
--   - a non-existent account also returns 5 (the counter is keyed by the
--     identifier string itself, so a fresh probe inserts a row with 1
--     attempt "used", and the count of 4 remaining is still distinctive
--     from a brand-new real account that has 5).
-- This is a low-grade user-enumeration oracle and we don't need it on
-- the anonymous path — the client always knows its own identifier and
-- just called `sign_in_identifier` immediately before.
--
-- Fix: require an authenticated session. The login screen already has a
-- flow for this — after a failed `sign_in_identifier` call, the client
-- needs *its own* status for the identifier it just tried, so it must be
-- authenticated for that call. In practice, the client side path is:
--   1. sign_in_identifier(...) — returns NULL (wrong creds)
--   2. sign_in_attempt_status(p_identifier) — only callable while
--      authenticated, and only meaningful for the user's own identifier.
-- To keep the feedback loop working without a round-trip through full
-- sign-in, we add a thin SECURITY DEFINER wrapper that the anon can
-- still call but that ONLY returns the lockout state for an IP, never
-- per-identifier data. The per-identifier RPC becomes authenticated-only.
--
-- Safe to re-run: identical grants and revoke statements.

-- ── 1. Lock the per-identifier RPC to authenticated users ────────────
revoke execute on function public.sign_in_attempt_status(text) from anon;
grant execute on function public.sign_in_attempt_status(text) to authenticated;

-- ── 2. Add a public-only IP-level status RPC for client-side feedback
--      when the user is NOT yet authenticated. Returns only "is this
--      source IP currently locked, and until when" — never per-user
--      counter data, so no enumeration possible. ──────────────────────
create or replace function public.sign_in_ip_status()
returns table (
  locked_until timestamptz,
  failed_count bigint
)
language sql
security definer
set search_path = public
as $$
  with headers as (
    select nullif(current_setting('request.headers', true), '') as h
  ),
  ip as (
    select btrim(split_part(coalesce((h::json ->> 'x-forwarded-for'), ''), ',', 1)) as v
    from headers
  )
  select srl.locked_until,
         srl.failed_attempts::bigint as failed_count
    from public.sign_in_rate_limit srl
    join ip on true
   where srl.identifier_key = 'ip:' || ip.v
   limit 1;
$$;

revoke all on function public.sign_in_ip_status() from public;
grant execute on function public.sign_in_ip_status() to anon;
grant execute on function public.sign_in_ip_status() to authenticated;

-- ── 3. Document the change ──────────────────────────────────────────
comment on function public.sign_in_attempt_status(text) is
  'Per-identifier sign-in status. Requires an authenticated session as of '
  'migration 0037 — anon callers use sign_in_ip_status() instead, which '
  'only exposes the IP-level lockout state and never per-user counter data.';

comment on function public.sign_in_ip_status() is
  'Source-IP-level sign-in throttle status. Returns the lockout window '
  'and current failure count for the caller IP only. Safe to call as anon '
  'because the response shape is identical for every caller and contains '
  'no per-identifier data. See migration 0037.';
