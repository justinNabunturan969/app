-- =============================================================================
-- Security hardening and audit trail
-- Run after 0001 and 0002. Safe for an existing project: it adds rules and
-- functions but does not delete borrowing, equipment, or user data.
-- =============================================================================

-- Keep physical inventory internally consistent.
alter table public.equipment
  drop constraint if exists equipment_counts_valid;
alter table public.equipment
  add constraint equipment_counts_valid
  check (total_count >= 0 and available_count >= 0 and available_count <= total_count);

-- A student cannot open duplicate requests/loans for the same equipment.
create unique index if not exists borrowings_one_open_request_per_student_item
  on public.borrowings (student_id, equipment_id)
  where status in ('pending', 'approved', 'active', 'overdue');

-- Record the security-relevant lifecycle of an item. Only admins may read it.
create table if not exists public.borrowing_audit_log (
  id uuid primary key default gen_random_uuid(),
  borrowing_id uuid not null references public.borrowings(id) on delete cascade,
  actor_id uuid references public.profiles(id) on delete set null,
  old_status text,
  new_status text not null,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists borrowing_audit_log_borrowing_idx
  on public.borrowing_audit_log (borrowing_id, created_at desc);
alter table public.borrowing_audit_log enable row level security;
drop policy if exists borrowing_audit_admin_read on public.borrowing_audit_log;
create policy borrowing_audit_admin_read on public.borrowing_audit_log
  for select using (public.is_admin());

create or replace function public.audit_borrowing_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.borrowing_audit_log (borrowing_id, actor_id, new_status, details)
    values (new.id, auth.uid(), new.status, jsonb_build_object('event', 'created'));
  elsif old.status is distinct from new.status then
    insert into public.borrowing_audit_log (borrowing_id, actor_id, old_status, new_status)
    values (new.id, auth.uid(), old.status, new.status);
  end if;
  return new;
end;
$$;
drop trigger if exists on_borrowing_audit on public.borrowings;
create trigger on_borrowing_audit
  after insert or update on public.borrowings
  for each row execute function public.audit_borrowing_change();

-- Never allow a signed-in user to promote their own profile. Admin promotion
-- must be performed in the SQL editor or with a server-side service-role tool.
create or replace function public.prevent_self_role_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() = old.id and new.role is distinct from old.role then
    raise exception 'Profile role cannot be changed by the account owner';
  end if;
  return new;
end;
$$;
drop trigger if exists on_profile_role_change on public.profiles;
create trigger on_profile_role_change
  before update on public.profiles
  for each row execute function public.prevent_self_role_change();

-- Direct client updates to borrowings are removed. The three small RPCs below
-- validate the caller, current state, and availability atomically.
drop policy if exists "borrowings_student_insert" on public.borrowings;
drop policy if exists "borrowings_admin_update" on public.borrowings;

create or replace function public.request_borrowing(
  p_equipment_id uuid,
  p_purpose text default ''
)
returns public.borrowings
language plpgsql
security definer
set search_path = public
as $$
declare
  v_borrowing public.borrowings;
begin
  if auth.uid() is null then raise exception 'Authentication is required'; end if;

  if not exists (
    select 1 from public.equipment
    where id = p_equipment_id and status = 'available' and available_count > 0
  ) then
    raise exception 'This equipment is unavailable';
  end if;

  insert into public.borrowings (student_id, equipment_id, status, purpose)
  values (auth.uid(), p_equipment_id, 'pending', left(coalesce(p_purpose, ''), 500))
  returning * into v_borrowing;
  return v_borrowing;
end;
$$;

create or replace function public.transition_borrowing(
  p_borrowing_id uuid,
  p_action text
)
returns public.borrowings
language plpgsql
security definer
set search_path = public
as $$
declare
  v_borrowing public.borrowings;
  v_now timestamptz := now();
  v_available_count integer;
begin
  select * into v_borrowing from public.borrowings where id = p_borrowing_id for update;
  if not found then raise exception 'Borrowing record not found'; end if;

  if p_action = 'request_return' then
    if v_borrowing.student_id <> auth.uid() or v_borrowing.status not in ('active', 'overdue') then
      raise exception 'This return request is not allowed';
    end if;
    update public.borrowings
      set status = 'returned', returned_at = v_now
      where id = p_borrowing_id
      returning * into v_borrowing;
  elsif p_action = 'approve' then
    if not public.is_admin() or v_borrowing.status <> 'pending' then
      raise exception 'This approval is not allowed';
    end if;
    select available_count into v_available_count
      from public.equipment
      where id = v_borrowing.equipment_id and status = 'available'
      for update;
    if not found or v_available_count <= 0 then
      raise exception 'This equipment is no longer available';
    end if;
    update public.borrowings
      set status = 'active', approved_at = v_now, borrowed_at = v_now,
          due_at = v_now + interval '3 days', approved_by = auth.uid()
      where id = p_borrowing_id
      returning * into v_borrowing;
  elsif p_action = 'reject' then
    if not public.is_admin() or v_borrowing.status <> 'pending' then
      raise exception 'This rejection is not allowed';
    end if;
    update public.borrowings
      set status = 'rejected', returned_at = v_now, approved_by = auth.uid()
      where id = p_borrowing_id
      returning * into v_borrowing;
  else
    raise exception 'Unsupported borrowing action';
  end if;
  return v_borrowing;
end;
$$;

revoke all on function public.request_borrowing(uuid, text) from public;
revoke all on function public.transition_borrowing(uuid, text) from public;
grant execute on function public.request_borrowing(uuid, text) to authenticated;
grant execute on function public.transition_borrowing(uuid, text) to authenticated;

-- Notifications are system-generated. Removing self-insert prevents a user
-- from forging a notification; the client no longer restores deleted items.
drop policy if exists "notifications_insert_self" on public.notifications;
