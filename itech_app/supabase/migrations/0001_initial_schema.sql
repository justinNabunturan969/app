-- =============================================================================
-- PUP-ITech Equipment Borrowing — initial schema
-- =============================================================================
-- Run this in the Supabase SQL editor (Database -> SQL Editor -> New query)
-- on a fresh project. It is idempotent: you can re-run it without breaking
-- the existing data.
--
-- What this gives you:
--   1. Tables: profiles, equipment, borrowings, active_sessions, notifications
--   2. Indexes for the hot read paths (student borrowings, equipment status)
--   3. Row Level Security (RLS) — students see only their own data, admins
--      see everything in their institute. RLS is enforced at the DB, not
--      the app, so it's a great defense talking point in the thesis panel.
--   4. A trigger that auto-creates a `profiles` row when a new auth user
--      signs up via Supabase Auth.
--   5. A trigger that auto-inserts an `active_sessions` row on sign-in.
-- =============================================================================

-- Required for gen_random_uuid()
create extension if not exists "pgcrypto";

-- -----------------------------------------------------------------------------
-- profiles — one row per authenticated user
-- -----------------------------------------------------------------------------
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  role text not null default 'student' check (role in ('student', 'admin')),
  student_id text unique,                 -- school-issued number, e.g. "2024-04421-MN-0"
  full_name text,
  email text,
  program text,
  year_level text,
  section text,
  nfc_uid text unique,                    -- tapped card UID, colon-hex form
  created_at timestamptz not null default now()
);

create index if not exists profiles_role_idx on public.profiles (role);
create index if not exists profiles_student_id_idx on public.profiles (student_id);

-- -----------------------------------------------------------------------------
-- equipment — the lab inventory
-- -----------------------------------------------------------------------------
create table if not exists public.equipment (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,              -- e.g. "E-9020"
  name text not null,
  category text,
  location text,
  total_count int not null default 0,
  available_count int not null default 0,
  description text,
  image_url text,
  status text not null default 'available'
    check (status in ('available', 'borrowed', 'maintenance', 'retired')),
  created_at timestamptz not null default now()
);

create index if not exists equipment_status_idx on public.equipment (status);
create index if not exists equipment_category_idx on public.equipment (category);

-- -----------------------------------------------------------------------------
-- borrowings — the transaction table
-- -----------------------------------------------------------------------------
create table if not exists public.borrowings (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.profiles (id) on delete cascade,
  equipment_id uuid not null references public.equipment (id) on delete restrict,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'active', 'overdue', 'returned', 'rejected')),
  purpose text,
  requested_at timestamptz not null default now(),
  approved_at timestamptz,
  approved_by uuid references public.profiles (id),
  borrowed_at timestamptz,
  due_at timestamptz,
  returned_at timestamptz,
  notes text
);

create index if not exists borrowings_student_idx on public.borrowings (student_id, status);
create index if not exists borrowings_equipment_idx on public.borrowings (equipment_id, status);
create index if not exists borrowings_status_idx on public.borrowings (status);

-- -----------------------------------------------------------------------------
-- active_sessions — drives the admin "Live" occupancy tab
-- -----------------------------------------------------------------------------
create table if not exists public.active_sessions (
  profile_id uuid primary key references public.profiles (id) on delete cascade,
  logged_in_at timestamptz not null default now(),
  last_activity_at timestamptz not null default now(),
  current_equipment_id uuid references public.equipment (id),
  activity text not null default 'active'
    check (activity in ('active', 'idle', 'returning'))
);

-- -----------------------------------------------------------------------------
-- notifications — per-user feed
-- -----------------------------------------------------------------------------
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles (id) on delete cascade,
  type text not null,                     -- 'overdue', 'approved', 'returned', etc.
  title text not null,
  body text,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists notifications_recipient_idx
  on public.notifications (recipient_id, created_at desc);

-- =============================================================================
-- Triggers
-- =============================================================================

-- Auto-create a profiles row whenever a new auth user is created.
-- Reads `student_id` and `full_name` from raw_user_meta_data so the
-- in-app "Create Account" screen can pass them through at sign-up
-- time. Falls back to the email local-part for the display name when
-- the client doesn't send one.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_full_name   text;
  v_student_id  text;
begin
  v_full_name := coalesce(
    new.raw_user_meta_data ->> 'full_name',
    split_part(new.email, '@', 1)
  );
  v_student_id := nullif(
    btrim(new.raw_user_meta_data ->> 'student_id'),
    ''
  );

  insert into public.profiles (id, email, full_name, student_id)
  values (new.id, new.email, v_full_name, v_student_id)
  on conflict (id) do update set
    email      = excluded.email,
    full_name  = coalesce(excluded.full_name, public.profiles.full_name),
    student_id = coalesce(excluded.student_id, public.profiles.student_id);

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Auto-add an active_session row on sign-in.
create or replace function public.handle_new_session()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.active_sessions (profile_id)
  values (new.id)
  on conflict (profile_id) do update
    set logged_in_at = now(),
        last_activity_at = now();
  return new;
end;
$$;

drop trigger if exists on_auth_user_session on auth.users;
create trigger on_auth_user_session
  after insert on auth.users
  for each row execute function public.handle_new_session();

-- -------------------------------------------------------------------
-- Auto-fire a notification AND keep `equipment.available_count` in
-- sync whenever a borrowing's status changes. Two birds, one trigger:
--   1. Status -> notification: the student sees a "request approved"
--      / "rejected" / "return confirmed" / "overdue" entry on their
--      notifications tab without the app having to do it.
--   2. Status -> equipment count: when the admin approves a request
--      we decrement available_count; when the student returns it we
--      increment it. Without this, the home-screen cards would keep
--      showing "5 available" even when 3 are physically checked out.
--
-- `security definer` so the notification insert can bypass the
-- `notifications_insert_self` RLS policy (the policy was written for
-- the student driving the insert from the app; the trigger is being
-- fired by the admin's update, so it needs the higher privilege).
-- -------------------------------------------------------------------
create or replace function public.handle_borrowing_status_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_equipment_name text;
  v_student_name   text;
  v_student_number text;
  v_title          text;
  v_body           text;
  v_type           text;
begin
  -- No-op if the status didn't actually change (admin updated e.g. notes
  -- or due_at without touching status). Saves us a notification storm.
  if OLD.status is not distinct from NEW.status then
    return new;
  end if;

  -- Map status -> (notification type, title, body). The 'pending' status
  -- is intentionally excluded — the student just made the request, they
  -- don't need a notification telling themselves about it.
  if NEW.status in ('approved', 'active', 'rejected', 'returned', 'overdue') then
    case NEW.status
      when 'approved' then
        v_type  := 'approved';
        v_title := 'Request approved';
        v_body  := 'Your borrowing request has been approved. You can pick up the equipment.';
      when 'active' then
        v_type  := 'approved';
        v_title := 'Equipment ready for pickup';
        v_body  := 'Your equipment is now active and ready for use.';
      when 'rejected' then
        v_type  := 'rejected';
        v_title := 'Request rejected';
        v_body  := 'Your borrowing request was rejected. Contact admin for details.';
      when 'returned' then
        v_type  := 'returned';
        v_title := 'Return confirmed';
        v_body  := 'Your equipment return has been recorded. Thanks!';
      when 'overdue' then
        v_type  := 'overdue';
        v_title := 'Equipment overdue';
        v_body  := 'Your borrowed equipment is overdue. Please return it as soon as possible.';
    end case;

    -- Resolve the equipment name once so the title reads nicely. If the
    -- equipment row was deleted between request and approval, the title
    -- falls back to "your item" — still informative, no NULLs.
    select name into v_equipment_name
      from public.equipment
     where id = NEW.equipment_id;

    insert into public.notifications (recipient_id, type, title, body)
    values (
      NEW.student_id,
      v_type,
      v_title || ' — ' || coalesce(v_equipment_name, 'your item'),
      v_body
    );

    -- A return performed by the borrower is also a return request for the
    -- equipment desk. Notify every admin, but do not create that alert when
    -- an admin records the physical return through the scan screen.
    if NEW.status = 'returned' and auth.uid() = NEW.student_id then
      select full_name, student_id
        into v_student_name, v_student_number
        from public.profiles
       where id = NEW.student_id;

      insert into public.notifications (recipient_id, type, title, body)
      select
        id,
        'reminder',
        'Return requested — ' || coalesce(v_equipment_name, 'equipment'),
        coalesce(v_student_name, 'A student') ||
          case when v_student_number is null then '' else ' (' || v_student_number || ')' end ||
          ' marked this item for return. Please verify the physical return.'
      from public.profiles
      where role = 'admin';
    end if;
  end if;

  -- Adjust equipment.available_count based on the status transition.
  -- GREATEST(..., 0) is a defensive floor so a double-approve can't
  -- drive the count negative; LEAST(..., total_count) caps the upper
  -- end so we never advertise more than physically exists.
  if NEW.status = 'active' and OLD.status <> 'active' then
    update public.equipment
       set available_count = greatest(available_count - 1, 0)
     where id = NEW.equipment_id;
  elsif NEW.status = 'returned' and OLD.status <> 'returned' then
    update public.equipment
       set available_count = least(available_count + 1, total_count)
     where id = NEW.equipment_id;
  end if;

  return new;
end;
$$;

drop trigger if exists on_borrowing_status_change on public.borrowings;
create trigger on_borrowing_status_change
  after update on public.borrowings
  for each row execute function public.handle_borrowing_status_change();

-- =============================================================================
-- Row Level Security
-- =============================================================================
-- Default deny. Every policy below is the smallest privilege that keeps the
-- app working — students see their own data, admins see everything.

alter table public.profiles enable row level security;
alter table public.equipment enable row level security;
alter table public.borrowings enable row level security;
alter table public.active_sessions enable row level security;
alter table public.notifications enable row level security;

-- Helper: is the current user an admin?
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
$$;

-- Helper: look up the auth email that corresponds to a given student_id.
-- Runs as the function owner (security definer) so it can read the
-- profiles table even when the caller isn't signed in yet — exactly
-- what the student login flow needs to translate "I typed my student
-- ID" into "I need to sign in with this PUP webmail". Returns NULL
-- when no profile matches so the caller can show a clean "no such
-- account" error without leaking which student IDs exist.
create or replace function public.auth_email_for_student_id(lookup_id text)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select email
    from public.profiles
   where student_id = lookup_id
   order by created_at
   limit 1;
$$;

-- profiles
drop policy if exists "profiles_select_own_or_admin" on public.profiles;
create policy "profiles_select_own_or_admin"
  on public.profiles for select
  using (auth.uid() = id or public.is_admin());

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
  on public.profiles for update
  using (auth.uid() = id);

-- equipment — everyone can read; only admins can write
drop policy if exists "equipment_select_all" on public.equipment;
create policy "equipment_select_all"
  on public.equipment for select
  using (true);

drop policy if exists "equipment_admin_write" on public.equipment;
create policy "equipment_admin_write"
  on public.equipment for all
  using (public.is_admin())
  with check (public.is_admin());

-- borrowings — student sees own, admin sees all
drop policy if exists "borrowings_select_own_or_admin" on public.borrowings;
create policy "borrowings_select_own_or_admin"
  on public.borrowings for select
  using (student_id = auth.uid() or public.is_admin());

drop policy if exists "borrowings_student_insert" on public.borrowings;
create policy "borrowings_student_insert"
  on public.borrowings for insert
  with check (student_id = auth.uid());

drop policy if exists "borrowings_admin_update" on public.borrowings;
create policy "borrowings_admin_update"
  on public.borrowings for update
  using (public.is_admin() or student_id = auth.uid());

-- active_sessions — admin only reads, server / auth triggers writes
drop policy if exists "active_sessions_admin_read" on public.active_sessions;
create policy "active_sessions_admin_read"
  on public.active_sessions for select
  using (public.is_admin() or profile_id = auth.uid());

-- notifications — own only
drop policy if exists "notifications_select_own" on public.notifications;
create policy "notifications_select_own"
  on public.notifications for select
  using (recipient_id = auth.uid());

drop policy if exists "notifications_update_own" on public.notifications;
create policy "notifications_update_own"
  on public.notifications for update
  using (recipient_id = auth.uid());

-- Students can insert notifications addressed to themselves (used by the
-- in-app "Restore" / undo flow when you accidentally delete one). Without
-- this, the RLS default-deny silently blocks the restore write.
drop policy if exists "notifications_insert_self" on public.notifications;
create policy "notifications_insert_self"
  on public.notifications for insert
  with check (recipient_id = auth.uid());

-- A user can delete their own notifications. Admins keep the implicit
-- postgres-superuser path for moderation; no app surface needs an admin
-- delete-notifications button today.
drop policy if exists "notifications_delete_own" on public.notifications;
create policy "notifications_delete_own"
  on public.notifications for delete
  using (recipient_id = auth.uid());

-- =============================================================================
-- Realtime — publish changes for the live UI
-- =============================================================================
-- The Flutter app listens on these channels via supabase.channel(...).stream.
-- PostgreSQL does not support `ADD TABLE IF NOT EXISTS` for publications, so
-- guard each table explicitly. This keeps the migration safe to re-run after
-- a partial setup or a previous successful run.
do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'equipment',
    'borrowings',
    'active_sessions',
    'notifications'
  ] loop
    if not exists (
      select 1
      from pg_publication_rel publication_relation
      join pg_publication publication
        on publication.oid = publication_relation.prpubid
      join pg_class relation
        on relation.oid = publication_relation.prrelid
      join pg_namespace schema
        on schema.oid = relation.relnamespace
      where publication.pubname = 'supabase_realtime'
        and schema.nspname = 'public'
        and relation.relname = table_name
    ) then
      execute format(
        'alter publication supabase_realtime add table public.%I',
        table_name
      );
    end if;
  end loop;
end
$$;

-- =============================================================================
-- Done. Test the install:
--   1. Sign up a user via the Flutter app (or Supabase dashboard -> Auth)
--   2. In SQL editor: select * from public.profiles;   -- should show 1 row
--   3. select * from public.active_sessions;          -- should show 1 row
--   4. Manually insert a few equipment rows in the equipment table editor,
--      then load them from the app to confirm the RLS policies let the
--      student see them.
-- =============================================================================
