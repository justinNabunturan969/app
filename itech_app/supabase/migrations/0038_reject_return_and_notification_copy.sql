-- =============================================================================
-- 0038: Reject a return request + fix the admin notification copy
-- =============================================================================
-- The admin now has an explicit Reject button alongside Confirm Return on the
-- Pending → Returns tab and the dashboard's Confirm Returns section (see
-- commits c16733c / c58df6a in lib/). This migration wires up the
-- corresponding server-side action and rewords the admin notification so it
-- stops implying a tap that no longer exists.
--
-- This migration does three things:
--   1. Adds a `reject_return` action to `transition_borrowing` (admin-only,
--      flips status return_requested → active, stashes the optional reason
--      in `return_notes`).
--   2. Updates `handle_borrowing_status_change` so the admin notification
--      body says "Open Pending → Returns to confirm or reject." instead of
--      the misleading "Tap to record the condition."
--   3. Adds a student-facing 'rejected' notification when an admin rejects
--      a return request, so the student sees *why* the admin sent it back
--      (e.g. "item not yet returned to the office").
--
-- Inventory accounting is already correct without further changes: the
-- existing trigger debits `equipment.available_count` whenever status
-- becomes 'active' and old.status <> 'active', which covers the
-- return_requested → active flip here.
-- =============================================================================

-- 1. Add reject_return to transition_borrowing ----------------------------
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

  elsif p_action = 'reject_return' then
    -- Admin-only: refuse a student's return request. The student never
    -- actually handed the item back, so the loan flips back to `active`
    -- and inventory is re-debited by the status-change trigger (the
    -- 'active and old.status <> active' branch already decrements
    -- `equipment.available_count`). The optional `p_notes` are stashed
    -- on the row as the rejection reason and surfaced to the student
    -- via a notification inserted by the status-change trigger below.
    if not public.is_admin()
       or v_borrowing.status <> 'return_requested' then
      raise exception 'This return rejection is not allowed';
    end if;
    update public.borrowings
      set status         = 'active',
          return_notes   = nullif(left(p_notes, 1000), ''),
          -- Don't overwrite the confirmed_* fields; this is a rejection,
          -- not a confirmation. Clear any prior partial return state.
          return_condition = null,
          confirmed_by    = null,
          confirmed_at    = null
      where id = p_borrowing_id
      returning * into v_borrowing;

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

-- 2 & 3. Update the status-change trigger: reword the admin notification
--         copy and add a student-facing rejection notification.
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
  v_reject_body    text;
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
    insert into public.notifications (recipient_id, type, title, body, related_borrowing_id)
      values (new.student_id, v_type, v_title || ' — ' || coalesce(v_equipment_name, 'your item'), v_body, new.id);
  end if;

  if new.status = 'return_requested' and old.status in ('active', 'overdue') then
    select name into v_equipment_name from public.equipment where id = new.equipment_id;
    select full_name, student_id into v_student_name, v_student_number
      from public.profiles where id = new.student_id;
    -- Reworded in 0038: the old "Tap to record the condition" implied
    -- the card was tappable, but the action lives on the Pending →
    -- Returns tab (and the dashboard's Confirm Returns section). The
    -- card is now a non-tappable heads-up that points the admin at
    -- the right surface.
    insert into public.notifications (recipient_id, type, title, body, related_borrowing_id)
      select id, 'reminder',
        'Return to confirm — ' || coalesce(v_equipment_name, 'equipment'),
        coalesce(v_student_name, 'A student') ||
          case when v_student_number is null then '' else ' (' || v_student_number || ')' end ||
          ' marked this item for return. Open Pending → Returns to confirm or reject.',
        new.id
      from public.profiles where role = 'admin';
  end if;

  -- 3. Admin rejected a return request: the loan flipped from
  --    `return_requested` back to `active`. The student didn't
  --    actually hand the item back, so let them know *why* the
  --    admin sent the request back. The optional `return_notes`
  --    (set by transition_borrowing's reject_return branch) is the
  --    reason text the admin typed in the dialog.
  if new.status = 'active' and old.status = 'return_requested' then
    select name into v_equipment_name from public.equipment where id = new.equipment_id;
    v_reject_body := 'Your return request for ' || coalesce(v_equipment_name, 'the equipment')
      || ' was sent back by the admin. Please bring the item to the equipment office to complete the return.';
    if new.return_notes is not null and length(new.return_notes) > 0 then
      v_reject_body := v_reject_body || ' Reason: ' || new.return_notes;
    end if;
    insert into public.notifications (recipient_id, type, title, body, related_borrowing_id)
      values (new.student_id, 'rejected',
        'Return request rejected — ' || coalesce(v_equipment_name, 'equipment'),
        v_reject_body,
        new.id);
  end if;

  if new.status = 'active' and old.status <> 'active' then
    -- Covers both approve (pending → active) and reject_return
    -- (return_requested → active). The reject_return case re-debits
    -- the inventory the student was credited at request_return time
    -- (migration 0032), since they never actually handed the item back.
    update public.equipment set available_count = greatest(available_count - new.quantity, 0)
      where id = new.equipment_id;
  elsif new.status = 'return_requested' and old.status in ('active', 'overdue') then
    update public.equipment set available_count = least(available_count + new.quantity, total_count)
      where id = new.equipment_id;
  end if;
  return new;
end;
$$;
