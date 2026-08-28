-- =============================================================================
-- 0034: Secure admin return confirmation (condition + notes + audit trail)
-- =============================================================================
-- Migration 0032 left a security gap that the user wants closed: a student
-- taps "Return" and the borrowing flips to `return_requested`, but the
-- admin's "Verify Return" was a one-tap action with no record of the
-- physical inspection. A dishonest student could game the system by claiming
-- a damaged or incomplete return was actually fine, and the equipment
-- office had no paper trail to dispute it.
--
-- This migration adds a structured return confirmation step:
--   1. Four new columns on `borrowings`:
--        - return_condition  text CHECK ('good', 'damaged', 'needs_repair')
--        - return_notes      text  (free-form, capped at 1000 chars)
--        - confirmed_by      uuid  references profiles(id)
--        - confirmed_at      timestamptz
--   2. transition_borrowing's `confirm_return` branch now requires the
--      condition (and accepts the optional notes / audit fields), and
--      stores them on the borrowing.
--   3. When the condition is 'damaged' or 'needs_repair', the equipment
--      row is auto-flipped to `status = 'maintenance'` and its
--      `available_count` is set to 0 (it can't be re-borrowed until the
--      admin puts it back in service via the new inventory edit flow).
--   4. The 'returned' notification now includes the condition in the
--      body, so the student sees whether the admin flagged their return.
-- =============================================================================

-- 1. Schema additions on borrowings ---------------------------------------
alter table public.borrowings
  add column if not exists return_condition text
    check (return_condition is null or return_condition in ('good', 'damaged', 'needs_repair')),
  add column if not exists return_notes text
    check (return_notes is null or length(return_notes) <= 1000),
  add column if not exists confirmed_by uuid references public.profiles (id) on delete set null,
  add column if not exists confirmed_at timestamptz;

create index if not exists borrowings_confirmed_by_idx
  on public.borrowings (confirmed_by);

-- 2. Update transition_borrowing -----------------------------------------
-- Drop the old version so the parameter list can change. Brief window
-- between drop+create only matters during the migration run.
drop function if exists public.transition_borrowing(uuid, text);

create or replace function public.transition_borrowing(
  p_borrowing_id   uuid,
  p_action         text,
  p_condition      text default null,
  p_notes          text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_borrowing public.borrowings;
  v_now       timestamptz := now();
  v_available_count integer;
  v_condition text;
  v_caller    uuid := auth.uid();
begin
  select * into v_borrowing from public.borrowings where id = p_borrowing_id for update;
  if not found then raise exception 'Borrowing record not found'; end if;

  if p_action = 'request_return' then
    -- Student asks for a return. Moves the row to the intermediate
    -- `return_requested` state. The status-change trigger credits
    -- `equipment.available_count` at this transition, so the item is
    -- borrowable again immediately and the same student can re-request
    -- it without waiting for the admin.
    if v_borrowing.student_id <> v_caller
       or v_borrowing.status not in ('active', 'overdue') then
      raise exception 'This return request is not allowed';
    end if;
    update public.borrowings set status = 'return_requested'
      where id = p_borrowing_id returning * into v_borrowing;

  elsif p_action = 'confirm_return' then
    -- Admin-only: verify the physical hand-in. Inventory was already
    -- credited when the student submitted `request_return`, so this is
    -- a pure status transition — we must NOT touch available_count
    -- again, otherwise we'd double-credit. The new p_condition is
    -- required: the admin must record the physical state of the item.
    if not public.is_admin()
       or v_borrowing.status not in ('return_requested', 'active', 'overdue') then
      raise exception 'This return confirmation is not allowed';
    end if;
    if p_condition is null or p_condition not in ('good', 'damaged', 'needs_repair') then
      raise exception 'Return condition is required (good, damaged, or needs_repair)';
    end if;
    v_condition := p_condition;
    update public.borrowings
      set status         = 'returned',
          returned_at    = v_now,
          return_condition = v_condition,
          return_notes     = nullif(left(p_notes, 1000), ''),
          confirmed_by     = v_caller,
          confirmed_at     = v_now
      where id = p_borrowing_id
      returning * into v_borrowing;

    -- If the item came back damaged, take it out of service so it
    -- can't be re-borrowed until the admin flips it back via the
    -- inventory edit flow. The before-update trigger on borrowings
    -- doesn't touch equipment, so we do it here directly.
    if v_condition in ('damaged', 'needs_repair') then
      update public.equipment
         set status          = 'maintenance',
             available_count = 0
       where id = v_borrowing.equipment_id;
    end if;

  elsif p_action = 'cancel' then
    -- Student withdraws a still-pending request (migration 0024).
    if v_borrowing.student_id <> v_caller
       or v_borrowing.status <> 'pending' then
      raise exception 'This cancellation is not allowed';
    end if;
    update public.borrowings set status = 'cancelled'
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
          due_at = v_now + public._loan_period(), approved_by = v_caller
      where id = p_borrowing_id returning * into v_borrowing;

  elsif p_action = 'reject' then
    if not public.is_admin() or v_borrowing.status <> 'pending' then
      raise exception 'This rejection is not allowed';
    end if;
    update public.borrowings set status = 'rejected', approved_by = v_caller
      where id = p_borrowing_id returning * into v_borrowing;

  else
    raise exception 'Unsupported borrowing action';
  end if;

  return public._borrowing_json(v_borrowing.id);
end;
$$;

revoke all on function public.transition_borrowing(uuid, text, text, text) from public;
revoke all on function public.transition_borrowing(uuid, text, text, text) from anon;
grant execute on function public.transition_borrowing(uuid, text, text, text) to authenticated;

-- 3. Update the student-facing 'returned' notification so it includes
--    the condition. The trigger passes the row's new state to the
--    handler; we now read the new condition column and append it.
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
  v_condition_suffix text;
begin
  if old.status is not distinct from new.status then return new; end if;

  if new.status in ('approved', 'active', 'rejected', 'returned', 'overdue') then
    case new.status
      when 'approved' then v_type := 'approved'; v_title := 'Request approved'; v_body := 'Your borrowing request has been approved. You can pick up the equipment.';
      when 'active'   then v_type := 'approved'; v_title := 'Equipment ready for pickup'; v_body := 'Your equipment is now active and ready for use.';
      when 'rejected' then v_type := 'rejected'; v_title := 'Request rejected'; v_body := 'Your borrowing request was rejected. Contact admin for details.';
      when 'returned' then
        v_type := 'returned';
        v_title := 'Return confirmed';
        -- Append the condition so the student knows whether the admin
        -- flagged the item (damaged / needs repair) before it was put
        -- back on the shelf.
        v_condition_suffix := case new.return_condition
          when 'good'         then ' Recorded as in good condition.'
          when 'damaged'      then ' Flagged as damaged — see equipment office for details.'
          when 'needs_repair' then ' Flagged for repair — see equipment office for details.'
          else ''
        end;
        v_body := 'Your equipment return has been verified by the admin. Thanks!' || v_condition_suffix;
      when 'overdue'  then v_type := 'overdue'; v_title := 'Equipment overdue'; v_body := 'Your borrowed equipment is overdue. Please return it as soon as possible.';
    end case;
    select name into v_equipment_name from public.equipment where id = new.equipment_id;
    insert into public.notifications (recipient_id, type, title, body)
      values (new.student_id, v_type, v_title || ' — ' || coalesce(v_equipment_name, 'your item'), v_body);
  end if;

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

  if new.status = 'active' and old.status <> 'active' then
    update public.equipment set available_count = greatest(available_count - new.quantity, 0)
      where id = new.equipment_id;
  elsif new.status = 'return_requested' and old.status in ('active', 'overdue') then
    update public.equipment set available_count = least(available_count + new.quantity, total_count)
      where id = new.equipment_id;
  end if;
  return new;
end;
$$;
