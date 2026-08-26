-- =============================================================================
-- 0022 — Per-IP sign-in throttling + documented password-handling risk
-- =============================================================================
-- Two hardening items against `sign_in_identifier` (0018):
--
-- 1. PASSWORD SPRAYING / CPU DoS: rate limiting was per-identifier only, so
--    an anonymous caller got UNLIMITED identifiers × 5 tries each, and every
--    try burns a cost-10 bcrypt round server side — cheap Postgres CPU DoS.
--    Fix: a second counter keyed by the caller IP (from PostgREST's
--    `request.headers` setting). The IP lock is checked BEFORE any bcrypt
--    work, so a throttled source costs one indexed SELECT per attempt instead
--    of ~100ms of bcrypt.
--
--    Thresholds: 30 failed attempts within 15 minutes locks that IP out for
--    15 minutes — high enough that NAT'd classrooms/lab machines sharing one
--    egress IP are not locked out by normal use (per-identifier limit of 5
--    still applies per student).
--
--    Known limitation: X-Forwarded-For is only trustworthy because Supabase's
--    API gateway overwrites it; a self-hosted deployment must ensure its own
--    proxy does the same, or attackers can rotate the header.
--
-- 2. PLAINTEXT PASSWORD THROUGH POSTGREST (documented risk): resolving a bare
--    student number to an auth email requires proving the password inside the
--    database, so the password necessarily traverses the PostgREST RPC path
--    in addition to GoTrue. It is TLS-protected in transit and never stored,
--    but it CAN appear in `pg_stat_activity` snapshots and PostgREST/statement
--    logging. Mitigations already in place: short-lived connections, RLS, and
--    no statement logging of RPC bodies by default. If your deployment turns
--    on verbose statement logging (`log_statement = 'all'`), exclude this RPC
--    or route sign-in through an Edge Function instead. Fully removing the
--    exposure means keeping verification solely in GoTrue, which cannot
--    resolve student-ID -> email without enabling user enumeration.
--
-- Safe to re-run: identical signature and grants for the public RPC.

-- ── Internal helpers ─────────────────────────────────────────────────────────
-- Shared counter logic so identifier and IP limits behave identically.

create or replace function public._sign_in_rate_key_locked(p_key text)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.sign_in_rate_limit
     where identifier_key = lower(btrim(coalesce(p_key, '')))
       and locked_until is not null
       and locked_until > now()
  );
$$;

create or replace function public._record_sign_in_failure(
  p_key          text,
  p_max_failures integer,
  p_window       interval,
  p_lockout      interval
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.sign_in_rate_limit as r (identifier_key, failed_attempts, first_failed_at)
  values (lower(btrim(p_key)), 1, now())
    on conflict (identifier_key) do update set
      failed_attempts = case
        when r.first_failed_at < now() - p_window then 1
        else r.failed_attempts + 1
      end,
      first_failed_at = case
        when r.first_failed_at < now() - p_window then now()
        else r.first_failed_at
      end;

  update public.sign_in_rate_limit
     set locked_until = now() + p_lockout
   where identifier_key = lower(btrim(p_key))
     and failed_attempts >= p_max_failures
     and first_failed_at >= now() - p_window;
end;
$$;

revoke all on function public._sign_in_rate_key_locked(text) from public;
revoke all on function public._sign_in_rate_key_locked(text) from anon;
revoke all on function public._sign_in_rate_key_locked(text) from authenticated;
revoke all on function public._record_sign_in_failure(text, integer, interval, interval) from public;
revoke all on function public._record_sign_in_failure(text, integer, interval, interval) from anon;
revoke all on function public._record_sign_in_failure(text, integer, interval, interval) from authenticated;

-- ── sign_in_identifier: same behaviour as 0018 + per-IP throttle ────────────
create or replace function public.sign_in_identifier(
  p_identifier text,
  p_password text
)
returns text
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  c_max_failures    constant int      := 5;
  c_window          constant interval := interval '15 minutes';
  c_lockout         constant interval := interval '5 minutes';

  -- Per-source limits: generous enough for a shared lab egress IP, low
  -- enough to stop password spraying across many identifiers.
  c_ip_max_failures constant int      := 30;
  c_ip_lockout      constant interval := interval '15 minutes';

  -- pgcrypto's bcrypt cost must match GoTrue's default (10) so the dummy
  -- hash below burns the same time as a real verification.
  c_dummy_hash      constant text     := '$2a$10$abcdefghijklmnopqrstuv';

  v_key          text := lower(btrim(coalesce(p_identifier, '')));
  v_password     text := coalesce(p_password, '');
  v_email        text;
  v_hash         text;
  v_ip           text := '';
  v_headers      text;
  v_locked_until timestamptz;
  v_match        boolean := false;
begin
  if v_key = '' or v_password = '' then
    return null;
  end if;

  -- Resolve caller IP from PostgREST's request.headers setting. Absent in
  -- non-HTTP contexts (cron, psql) — per-IP limiting is skipped then.
  v_headers := nullif(current_setting('request.headers', true), '');
  if v_headers is not null then
    begin
      v_ip := btrim(split_part(coalesce(v_headers::json ->> 'x-forwarded-for', ''), ',', 1));
    exception when others then
      v_ip := '';
    end;
  end if;

  -- Gate 1: this identifier is already locked out.
  select locked_until into v_locked_until
    from public.sign_in_rate_limit
   where identifier_key = v_key;
  if v_locked_until is not null and v_locked_until > now() then
    raise exception 'Too many sign-in attempts. Try again later';
  end if;

  -- Gate 2: this SOURCE is locked out — checked BEFORE any bcrypt work so a
  -- spraying client costs one indexed SELECT instead of cost-10 crypt().
  if v_ip <> '' and public._sign_in_rate_key_locked('ip:' || v_ip) then
    raise exception 'Too many sign-in attempts. Try again later';
  end if;

  -- Primary resolution: profiles.student_id -> auth.users. btrim both
  -- sides so a stray space in the stored ID can't break the match.
  select u.email, u.encrypted_password
    into v_email, v_hash
    from public.profiles p
    join auth.users u on u.id = p.id
   where lower(btrim(p.student_id)) = v_key
   limit 1;

  -- Legacy demo accounts: their auth email literally encodes the student
  -- number ("<id>@pupitech.local") even when the profile row predates the
  -- student_id column being populated.
  if v_email is null and position('@' in v_key) = 0 then
    select u.email, u.encrypted_password
      into v_email, v_hash
      from auth.users u
     where u.email = v_key || '@pupitech.local'
     limit 1;
  end if;

  -- Verify the password. When the identifier does not exist, burn one bcrypt
  -- round anyway so timing cannot be used to probe which IDs are real.
  if v_email is null or v_hash is null then
    perform crypt(v_password, c_dummy_hash);
  else
    begin
      v_match := crypt(v_password, v_hash) is not distinct from v_hash;
    exception when others then
      -- Unparseable stored hash (unknown format): treat as a failed
      -- password rather than erroring the whole request.
      v_match := false;
    end;
  end if;

  if not v_match then
    -- Count the failure against BOTH the identifier and the source IP.
    perform public._record_sign_in_failure(v_key, c_max_failures, c_window, c_lockout);
    if v_ip <> '' then
      perform public._record_sign_in_failure(
        'ip:' || v_ip, c_ip_max_failures, c_window, c_ip_lockout);
    end if;
    return null;
  end if;

  -- Success clears only THIS identifier's counter. The IP counter is
  -- deliberately kept: one valid login must not reset a spray campaign's
  -- progress against the other identifiers behind the same address.
  delete from public.sign_in_rate_limit where identifier_key = v_key;
  return lower(v_email);
end;
$$;

-- Grants unchanged from 0018.
revoke all on function public.sign_in_identifier(text, text) from public;
grant execute on function public.sign_in_identifier(text, text) to anon;
grant execute on function public.sign_in_identifier(text, text) to authenticated;
