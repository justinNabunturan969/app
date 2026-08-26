-- =============================================================================
-- PUP-ITech — one-shot seed helpers
-- =============================================================================
-- Run this AFTER `0001_initial_schema.sql` and AFTER you've created the auth
-- users in Supabase Auth (Authentication -> Users -> Add user). It does three
-- things:
--   1. Promotes the admin auth user(s) to the `admin` role so RLS lets them
--      approve / reject / see all borrowings.
--   2. Promotes the seeded students explicitly to the `student` role, in case
--      you ever change the default.
--   3. (Optional) Inserts a small demo borrowing + notification so the
--      admin's Pending tab and the student's Notifications tab have
--      something visible the first time you open the app.
--
-- SECURITY: role assignment matches EXPLICIT emails only. The previous
-- version promoted any profile whose local part matched `ilike 'admin%'`;
-- re-running that on a live project with self-signup enabled would hand the
-- admin role to any student who registered e.g. `admin.x@pup.edu.ph`.
--
-- ── EDIT THE TWO LISTS BELOW to match the accounts you actually created. ────
-- =============================================================================

do $$
declare
  v_admin_emails   text[] := array[
    'admin@pupitech.local',
    'admin@pup.edu.ph',
    'admin1@pup.edu.ph'
  ];
  v_student_emails text[] := array[
    'student1@pupitech.local',
    'student2@pupitech.local',
    'student1@pup.edu.ph'
  ];
  v_promoted int;
begin
  -- 1. Admin role — explicit allow-list only. lower() so storage casing
  --    in auth.users can't dodge the match.
  update public.profiles p
     set role = 'admin'
   where lower(p.email) = any (v_admin_emails);
  get diagnostics v_promoted = row_count;
  raise notice 'Promoted % profile(s) to admin.', v_promoted;

  -- 2. Students (the default is already 'student', but this makes it
  --    explicit and lets you promote/demote later from one place). Only the
  --    listed accounts are touched — real users are never downgraded.
  update public.profiles p
     set role = 'student'
   where lower(p.email) = any (v_student_emails);
end;
$$;

-- 3. (Optional) Demo data — comment this whole block out if you don't want
--    any seeded rows. It uses the first available equipment row for a
--    SEEDED student from the same explicit list above, never an arbitrary
--    real user.
do $$
declare
  v_student uuid;
  v_equipment uuid;
  v_borrowing uuid;
begin
  select id into v_student from public.profiles
    where lower(email) = any (array[
      'student1@pupitech.local',
      'student2@pupitech.local',
      'student1@pup.edu.ph'
    ])
    order by created_at
    limit 1;
  if v_student is null then
    raise notice 'No seeded student profile found — skipping demo seed.';
    return;
  end if;

  select id into v_equipment from public.equipment
    where available_count > 0
    order by name limit 1;
  if v_equipment is null then
    raise notice 'No equipment with available_count > 0 — skipping demo seed.';
    return;
  end if;

  -- Only seed a pending borrowing if the student doesn't already have one
  -- for that equipment (avoids spamming after a re-run).
  if not exists (
    select 1 from public.borrowings
     where student_id = v_student
       and equipment_id = v_equipment
       and status = 'pending'
  ) then
    insert into public.borrowings (student_id, equipment_id, status, purpose)
    values (v_student, v_equipment, 'pending',
            'Demo request from seed script')
    returning id into v_borrowing;

    insert into public.notifications (recipient_id, type, title, body)
    values (v_student, 'reminder',
            'Request submitted',
            'Your request is pending admin approval.');
  end if;
end
$$;

-- Verify the setup
select 'profiles' as table_name, role, email from public.profiles order by role, email;
select 'pending borrowings' as table_name, count(*) from public.borrowings where status = 'pending';
