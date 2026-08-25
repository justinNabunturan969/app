-- =============================================================================
-- Student-ID login + profile bootstrap hardening
-- =============================================================================
-- Ships three fixes for the auth surface:
--
-- 1. Student-ID sign-in no longer depends on the revoked
--    `auth_email_for_student_id()` helper or the synthetic
--    "<student-id>@pupitech.local" email convention. The new
--    `sign_in_identifier(p_identifier, p_password)` RPC resolves a student
--    number to its REAL auth email server-side. The password is verified in
--    the database (bcrypt via pgcrypto) before the email is returned, so the
--    ID -> email mapping cannot be enumerated: a caller learns nothing
--    without presenting valid credentials. Failed attempts are rate-limited
--    per identifier (5 failures / 15 min window, then 5 min lockout) and the
--    response shape is identical whether or not the ID exists.
--
-- 2. `profiles` gains the missing INSERT policy so the app's bootstrap path
--    ("trigger missed / manual auth.users import") can actually create the
--    row under RLS. A user may only insert their OWN row and never with an
--    elevated role, which closes a privilege-escalation hole that a naive
--    `with check (auth.uid() = id)` policy would have left open.
--
-- 3. Legacy demo accounts whose profile row predates student_id being
--    populated are backfilled from their synthetic email local-part so they
--    keep working through the new RPC.

-- ─────────────────────────────────────────────────────────────────────────────
-- Rate limiting storage for sign_in_identifier. No grants + RLS with no
-- policies makes this table invisible to both Data API roles; only the
-- SECURITY DEFINER function below touches it.
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.sign_in_rate_limit (
  identifier_key  text primary key,
  failed_attempts int not null default 0,
  first_failed_at timestamptz not null default now(),
  locked_until    timestamptz
);

alter table public.sign_in_rate_limit enable row level security;

revoke all on public.sign_in_rate_limit from public;
revoke all on public.sign_in_rate_limit from anon;
revoke all on public.sign_in_rate_limit from authenticated;

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
  c_max_failures constant int      := 5;
  c_window       constant interval := interval '15 minutes';
  c_lockout      constant interval := interval '5 minutes';

  -- pgcrypto's bcrypt cost must match GoTrue's default (10) so the dummy
  -- hash below burns the same time as a real verification.
  c_dummy_hash   constant text     := '$2a$10$abcdefghijklmnopqrstuv';

  v_key          text := lower(btrim(coalesce(p_identifier, '')));
  v_password     text := coalesce(p_password, '');
  v_email        text;
  v_hash         text;
  v_locked_until timestamptz;
begin
  if v_key = '' or v_password = '' then
    return null;
  end if;

  select locked_until into v_locked_until
    from public.sign_in_rate_limit
   where identifier_key = v_key;

  if v_locked_until is not null and v_locked_until > now() then
    raise exception 'Too many sign-in attempts. Try again later';
  end if;

  -- Primary resolution: profiles.student_id -> auth.users.
  select u.email, u.encrypted_password
    into v_email, v_hash
    from public.profiles p
    join auth.users u on u.id = p.id
   where lower(p.student_id) = v_key
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
    v_email := null;
  elsif crypt(v_password, v_hash) is distinct from v_hash then
    v_email := null;
  end if;

  if v_email is null then
    insert into public.sign_in_rate_limit as r (identifier_key, failed_attempts, first_failed_at)
    values (v_key, 1, now())
      on conflict (identifier_key) do update set
        failed_attempts = case
          when r.first_failed_at < now() - c_window then 1
          else r.failed_attempts + 1
        end,
        first_failed_at = case
          when r.first_failed_at < now() - c_window then now()
          else r.first_failed_at
        end;

    update public.sign_in_rate_limit
       set locked_until = now() + c_lockout
     where identifier_key = v_key
       and failed_attempts >= c_max_failures
       and first_failed_at >= now() - c_window;

    return null;
  end if;

  delete from public.sign_in_rate_limit where identifier_key = v_key;
  return lower(v_email);
end;
$$;

revoke all on function public.sign_in_identifier(text, text) from public;
grant execute on function public.sign_in_identifier(text, text) to anon;
grant execute on function public.sign_in_identifier(text, text) to authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- Missing INSERT policy on profiles (fix #2). The table-level grant was also
-- absent — migration 0011 granted only SELECT/UPDATE — so both are needed
-- before PostgREST will accept the bootstrap insert at all.
-- ─────────────────────────────────────────────────────────────────────────────
grant insert on public.profiles to authenticated;

drop policy if exists "profiles_insert_self" on public.profiles;
create policy "profiles_insert_self"
  on public.profiles for insert to authenticated
  with check (
    (select auth.uid()) = id
    and role = 'student'
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- Backfill legacy synthetic-email accounts whose student_id was never set,
-- so they resolve through the primary lookup instead of the fallback. Only
-- local-parts matching the strict student-ID format are copied; faculty
-- handles like "admin1" are left alone.
-- ─────────────────────────────────────────────────────────────────────────────
update public.profiles
   set student_id = split_part(email, '@', 1)
 where student_id is null
   and email like '%@pupitech.local'
   and split_part(email, '@', 1) ~ '^[0-9]{4}-[0-9]{5}-[A-Za-z]{2}-[0-9]$';
