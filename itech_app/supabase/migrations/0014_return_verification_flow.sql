-- =============================================================================
-- Return verification flow + timestamp hygiene
-- =============================================================================
-- Fixes two data-integrity bugs:
--
-- 1. Inventory was credited the moment a student tapped "return", before
--    anyone verified the physical return. A dishonest student could mark
--    an item returned, keep it, and the system would advertise it as
--    available. Fix: `request_return` now moves the row to a new
--    `return_requested` status WITHOUT touching `available_count`. The
--    count only increments when an admin confirms via the new
--    `confirm_return` action (which sets status = 'returned').
--
-- 2. Rejected requests were stamped with `returned_at`, which made the
--    history list show a fake "return date" for items that were never
--    borrowed. Fix: the reject branch no longer writes `returned_at`.

-- ── Allow the new status ────────────────────────────────────────────────
alter table public.borrowings
  drop constraint if exists borrowings_status_check;
alter table public.borrowings
  add constraint borrowings_status_check
  check (status in (
    'pending', 'approved', 'active', 'overdue',
    'return_requested', 'returned', 'rejected'
  ));

-- Only one open request/loan per student+item; include the new status.
drop index if exists borrowings_one_open_request_per_student_item;
create unique index borrowings_one_open_request_per_student_item
  on public.borrowings (student_id, equipment_id)
  where status in ('pending', 'approved', 'active', 'overdue', 'return_requested');

-- ── Status-change trigger: inventory only moves on verified transitions ──
create or replace function public.handle_borrowing_status_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_equipment_name text;
  v_student_name text;
  v_student_number text;
  v_title text;
  v_body text;
  v_type text;
begin
  if old.status is not distinct from new.status then return new; end if;

  -- Notifications. 'return_requested' notifies the admins instead of the
  -- student, so it's handled separately below.
  if new.status in ('approved', 'active', 'rejected', 'returned', 'overdue') then
    case new.status
      when 'approved' then v_type := 'approved'; v_title := 'Request approved'; v_body := 'Your borrowing request has been approved. You can pick up the equipment.';
      when 'active' then v_type := 'approved'; v_title := 'Equipment ready for pickup'; v_body := 'Your equipment is now active and ready for use.';
      when 'rejected' then v_type := 'rejected'; v_title := 'Request rejected'; v_body := 'Your borrowing request was rejected. Contact admin for details.';
      when 'returned' then v_type := 'returned'; v_title := 'Return confirmed'; v_body := 'Your equipment return has been verified by the admin. Thanks!';
      when 'overdue' then v_type := 'overdue'; v_title := 'Equipment overdue'; v_body := 'Your borrowed equipment is overdue. Please return it as soon as possible.';
    end case;
    select name into v_equipment_name from public.equipment where id = new.equipment_id;
    insert into public.notifications (recipient_id, type, title, body)
      values (new.student_id, v_type, v_title || ' — ' || coalesce(v_equipment_name, 'your item'), v_body);
  end if;

  -- Student asked for a return: alert every admin to verify the physical
  -- hand-in. No notification to the student yet — they already know.
  if new.status = 'return_requested' and old.status in ('active', 'overdue') then
    select name into v_equipment_name from public.equipment where id = new.equipment_id;
    select full_name, student_id into v_student_name, v_student_number
      from public.profiles where id = new.student_id;
    insert into public.notifications (recipient_id, type, title, body)
      select id, 'reminder',
        'Return requested — ' || coalesce(v_equipment_name, 'equipment'),
        coalesce(v_student_name, 'A student') ||
          case when v_student_number is null then '' else ' (' || v_student_number || ')' end ||
          ' marked this item for return. Please verify the physical return.'
      from public.profiles where role = 'admin';
  end if;

  -- Inventory adjustments. Decrement when a loan actually starts; increment
  -- ONLY when an admin confirms the physical return. 'return_requested'
  -- deliberately does NOT change availability.
  if new.status = 'active' and old.status <> 'active' then
    update public.equipment set available_count = greatest(available_count - new.quantity, 0) where id = new.equipment_id;
  elsif new.status = 'returned' and old.status <> 'returned' then
    update public.equipment set available_count = least(available_count + new.quantity, total_count) where id = new.equipment_id;
  end if;
  return new;
end;
$$;

-- ── Transition RPC: new actions, no returned_at on reject ───────────────
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
    -- Student asks for a return. Moves to an intermediate state; the
    -- admin's `confirm_return` finishes it and credits inventory.
    if v_borrowing.student_id <> auth.uid()
       or v_borrowing.status not in ('active', 'overdue') then
      raise exception 'This return request is not allowed';
    end if;
    update public.borrowings set status = 'return_requested'
      where id = p_borrowing_id returning * into v_borrowing;

  elsif p_action = 'confirm_return' then
    -- Admin-only: verify the physical hand-in. This is the transition
    -- that actually increments equipment.available_count.
    if not public.is_admin()
       or v_borrowing.status not in ('return_requested', 'active', 'overdue') then
      raise exception 'This return confirmation is not allowed';
    end if;
    update public.borrowings
      set status = 'returned', returned_at = v_now
      where id = p_borrowing_id returning * into v_borrowing;

  elsif p_action = 'approve' then
    if not public.is_admin() or v_borrowing.status <> 'pending' then
      raise exception 'This approval is not allowed';
    end if;
    select available_count into v_available_count from public.equipment
      where id = v_borrowing.equipment_id and status = 'available' for update;
    if not found or v_available_count < v_borrowing.quantity then
      raise exception 'Only % unit(s) remain available', coalesce(v_available_count, 0);
    end if;
    update public.borrowings
      set status = 'active', approved_at = v_now, borrowed_at = v_now,
          due_at = v_now + interval '3 days', approved_by = auth.uid()
      where id = p_borrowing_id returning * into v_borrowing;

  elsif p_action = 'reject' then
    if not public.is_admin() or v_borrowing.status <> 'pending' then
      raise exception 'This rejection is not allowed';
    end if;
    -- No returned_at here: the item was never borrowed, so there is no
    -- return date to record.
    update public.borrowings set status = 'rejected', approved_by = auth.uid()
      where id = p_borrowing_id returning * into v_borrowing;

  else
    raise exception 'Unsupported borrowing action';
  end if;
  return v_borrowing;
end;
$$;

revoke all on function public.transition_borrowing(uuid, text) from public;
revoke all on function public.transition_borrowing(uuid, text) from anon;
grant execute on function public.transition_borrowing(uuid, text) to authenticated;
