-- =============================================================================
-- Diagnostics: why is student-ID sign-in not recognizing an account?
-- =============================================================================
-- Run each block in the Supabase SQL Editor and read the comments.

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Is the resolver installed at all? (migration 0015/0018)
-- Must return at least one row. Zero rows = the RPC is missing, which is the
-- most common cause of "student ID not recognized" — run migration 0018.
-- ─────────────────────────────────────────────────────────────────────────────
select proname, pg_get_function_identity_arguments(oid) as args
  from pg_proc
 where proname = 'sign_in_identifier'
   and pronamespace = 'public'::regnamespace;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. What does the resolver see for each account?
-- Check that `student_id` is NOT null and matches EXACTLY what you type on
-- the login screen (the match is case-insensitive + whitespace-trimmed).
-- `hash_prefix` should start with $2a$ / $2b$ / $2y$ (bcrypt).
-- ─────────────────────────────────────────────────────────────────────────────
select p.student_id,
       u.email,
       u.email_confirmed_at is not null as confirmed,
       left(u.encrypted_password, 7) as hash_prefix,
       p.created_at
  from public.profiles p
  join auth.users u on u.id = p.id
 order by p.created_at desc;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Fix a test account whose student_id is missing or wrong.
-- Replace the email + ID with your real values, then re-run block 2.
-- ─────────────────────────────────────────────────────────────────────────────
-- update public.profiles
--    set student_id = '2024-12345-MN-0'
--  where email = 'student1@pup.edu.ph';

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. End-to-end test of the resolver itself.
-- Returns the auth email on success, NULL on bad ID/password, and raises
-- "Too many sign-in attempts" while locked out.
-- ─────────────────────────────────────────────────────────────────────────────
-- select public.sign_in_identifier('2024-12345-MN-0', 'the-account-password');
