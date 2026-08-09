-- =============================================================================
-- PUP-ITech — one-shot verify
-- =============================================================================
-- Paste this into the Supabase SQL editor and run it. Each `select` returns
-- a one-line summary. If any line shows a count of 0 or NULL, that's the
-- piece you need to fix before the app can talk to the DB.
-- =============================================================================

-- (1) Auth users exist?
select 'auth.users' as check, count(*) as rows from auth.users;

-- (2) Every auth user has a profile row?
--     The handle_new_user trigger should auto-create this, but if you
--     disabled triggers or imported data manually, the count can be off.
select
  'profiles vs auth.users' as check,
  (select count(*) from auth.users)        as auth_count,
  (select count(*) from public.profiles)   as profile_count,
  case
    when (select count(*) from auth.users) = (select count(*) from public.profiles)
    then 'OK'
    else 'MISMATCH — some auth users are missing profile rows'
  end as status;

-- (3) Profile roles look right?
--     You should see at least one row with role = 'admin' (the panel admin
--     and/or admin1 user) and at least one with role = 'student'.
select role, count(*) as users
  from public.profiles
 group by role
 order by role;

-- (4) Equipment seeded?
select 'equipment' as check, count(*) as rows from public.equipment;

-- (5) Pending borrowings?
select 'borrowings by status' as check, status, count(*)
  from public.borrowings
 group by status
 order by status;

-- (6) RLS enabled on every table?
--     RLS being enabled is what makes the policies actually apply.
select tablename, rowsecurity as rls_enabled
  from pg_tables
 where schemaname = 'public'
   and tablename in ('profiles', 'equipment', 'borrowings', 'active_sessions', 'notifications')
 order by tablename;

-- (7) Policies and secure borrowing functions we depend on are in place.
select
  'borrowing_audit_admin_read' as policy, count(*) from pg_policies
   where schemaname = 'public' and tablename = 'borrowing_audit_log' and policyname = 'borrowing_audit_admin_read'
union all select 'notifications_update_own', count(*) from pg_policies
   where schemaname = 'public' and tablename = 'notifications' and policyname = 'notifications_update_own'
union all select 'notifications_delete_own', count(*) from pg_policies
   where schemaname = 'public' and tablename = 'notifications' and policyname = 'notifications_delete_own';

-- (8) The status-change trigger is installed? Without it, admin approve /
--     reject / return would still work but the student's notifications
--     tab would never get new entries from real activity.
select
  'on_borrowing_status_change' as trigger_name,
  count(*) as installed
  from pg_trigger
 where tgname = 'on_borrowing_status_change';

-- (9) The production hardening migration has removed the old public
-- student-ID-to-email lookup and applied the explicit Data API grants needed
-- by newer Supabase projects.
select
  'auth_email_for_student_id public execute grants' as check,
  count(*) as grants_to_remove
  from information_schema.routine_privileges
 where routine_schema = 'public'
   and routine_name = 'auth_email_for_student_id'
   and grantee in ('PUBLIC', 'anon', 'authenticated')
   and privilege_type = 'EXECUTE';

select
  table_name,
  privilege_type,
  grantee
from information_schema.role_table_grants
where table_schema = 'public'
  and grantee = 'authenticated'
  and table_name in (
    'profiles', 'equipment', 'borrowings', 'active_sessions',
    'notifications', 'borrowing_audit_log', 'session_history'
  )
order by table_name, privilege_type;

-- (10) Security hardening functions/triggers installed?
select proname as security_function
  from pg_proc
 where proname in ('request_borrowing', 'transition_borrowing', 'prevent_self_role_change')
 order by proname;
