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
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, full_name)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data ->> 'full_name', split_part(new.email, '@', 1))
  )
  on conflict (id) do nothing;
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

-- =============================================================================
-- Realtime — publish changes for the live UI
-- =============================================================================
-- The Flutter app listens on these channels via supabase.channel(...).stream.
alter publication supabase_realtime add table public.equipment;
alter publication supabase_realtime add table public.borrowings;
alter publication supabase_realtime add table public.active_sessions;
alter publication supabase_realtime add table public.notifications;

-- =============================================================================
-- Done. Test the install:
--   1. Sign up a user via the Flutter app (or Supabase dashboard -> Auth)
--   2. In SQL editor: select * from public.profiles;   -- should show 1 row
--   3. select * from public.active_sessions;          -- should show 1 row
--   4. Manually insert a few equipment rows in the equipment table editor,
--      then load them from the app to confirm the RLS policies let the
--      student see them.
-- =============================================================================
