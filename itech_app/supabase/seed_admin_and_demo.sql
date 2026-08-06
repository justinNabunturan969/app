-- =============================================================================
-- PUP-ITech — one-shot seed helpers
-- =============================================================================
-- Run this AFTER `0001_initial_schema.sql` and AFTER you've created the auth
-- users in Supabase Auth (Authentication -> Users -> Add user). It does three
-- things:
--   1. Promotes the admin auth user to the `admin` role so RLS lets them
--      approve / reject / see all borrowings.
--   2. Promotes student1 (and any other sample students) explicitly to the
--      `student` role, in case you ever change the default.
--   3. (Optional) Inserts a small demo borrowing + notification so the
--      admin's Pending tab and the student's Notifications tab have
--      something visible the first time you open the app.
-- =============================================================================

-- 1. Admin role — matches the seed user's email no matter whether you
--    used `admin@pupitech.local`, `admin1@pupitech.local`,
--    `admin1@pup.edu.ph`, etc. We promote *any* profile whose local part
--    starts with "admin" and treat the rest as students.
update public.profiles
   set role = 'admin'
 where split_part(email, '@', 1) ilike 'admin%';

-- 2. Students (the default is already 'student', but this makes it explicit
--    and lets you promote/demote later from one place).
update public.profiles
   set role = 'student'
 where split_part(email, '@', 1) not ilike 'admin%';

-- 3. (Optional) Demo data — comment this whole block out if you don't want
--    any seeded rows. It uses the first available equipment row for the
--    first available student so you don't need to look up UUIDs.
do $$
declare
  v_student uuid;
  v_equipment uuid;
  v_borrowing uuid;
begin
  -- Bail early if there's nothing to point at. The student lookup
  -- matches any profile whose local part starts with "student", so the
  -- same script works for `student1@pupitech.local`, `student1@pup.edu.ph`,
  -- and any other email convention.
  select id into v_student from public.profiles
    where split_part(email, '@', 1) ilike 'student%'
    order by created_at
    limit 1;
  if v_student is null then
    raise notice 'No student profile found — skipping demo seed.';
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
