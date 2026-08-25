-- =============================================================================
-- Student-ID sign-in resilience fixes
-- =============================================================================
-- Two failure modes reported against `sign_in_identifier` (0015):
--
--   1. Stored `profiles.student_id` values with leading/trailing whitespace
--      never matched the trimmed input. The comparison now trims both sides.
--
--   2. If the stored `auth.users.encrypted_password` is ever in a format
--      pgcrypto's crypt() cannot parse (e.g. a future GoTrue hashing
--      change), the whole RPC failed with a 500 "invalid salt" instead of
--      a clean credential failure. The verification is now wrapped so any
--      unexpected hash format degrades to "wrong password", and the client
--      shows its normal message.
--
-- Safe to re-run; identical signature and grants.

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
  v_match        boolean := false;
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
