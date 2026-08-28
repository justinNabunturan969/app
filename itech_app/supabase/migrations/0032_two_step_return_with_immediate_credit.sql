-- =============================================================================
-- 0032: Two-step return flow with immediate inventory credit
-- =============================================================================
-- This replaces the original 0032 (auto-confirm return), which was renamed
-- to _deprecated_0032_auto_confirm_return_and_inventory_repair.sql so the
-- Supabase migration runner ignores it. It restores the borrow→approve
-- symmetry the user wants:
--
--   Student taps "Return"  ->  status becomes `return_requested`
--   Admin taps "Verify"    ->  status becomes `returned`  (history)
--
-- AND it credits `equipment.available_count` at the student's request step
-- (not at the admin's confirm step) so:
--   - the item shows up as available right away
--   - the same student can re-borrow it without waiting for the admin
--   - the admin's verify is the formal closure, not a gate on inventory
--
-- The partial unique index `borrowings_one_open_request_per_student_item`
-- also drops `return_requested` from its filter so the student can submit
-- a fresh `pending` request for the same item while the previous loan is
-- still awaiting admin verification.
--
-- Trade-off: a dishonest student could mark an item returned and
-- immediately re-request it without handing the original in. For a school
-- equipment office with trusted users this is acceptable — the partial
-- unique index still blocks two `active`/`pending` rows for the same item.
-- =============================================================================

-- ── 1. transition_borrowing: admin-only confirm_return ────────────────────
create or replace function public.transition_borrowing(
  p_borrowing_id uuid,
  p_action text
)
returns jsonb
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
    -- Student asks for a return. Moves the row to the intermediate
    -- `return_requested` state. The status-change trigger credits
    -- `equipment.available_count` at this transition, so the item is
    -- borrowable again immediately and the same student can re-request
    -- it without waiting for the admin.
    if v_borrowing.student_id <> auth.uid()
       or v_borrowing.status not in ('active', 'overdue') then
      raise exception 'This return request is not allowed';
    end if;
    update public.borrowings set status = 'return_requested'
      where id = p_borrowing_id returning * into v_borrowing;

  elsif p_action = 'confirm_return' then
    -- Admin-only: verify the physical hand-in. Inventory was already
    -- credited when the student submitted `request_return`, so this is a
    -- pure status transition — we must NOT touch available_count again,
    -- otherwise we'd double-credit.
    if not public.is_admin()
       or v_borrowing.status not in ('return_requested', 'active', 'overdue') then
      raise exception 'This return confirmation is not allowed';
    end if;
    update public.borrowings
      set status = 'returned', returned_at = v_now
      where id = p_borrowing_id returning * into v_borrowing;

  elsif p_action = 'cancel' then
    -- Student withdraws a still-pending request (migration 0024).
    if v_borrowing.student_id <> auth.uid()
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
          due_at = v_now + public._loan_period(), approved_by = auth.uid()
      where id = p_borrowing_id returning * into v_borrowing;

  elsif p_action = 'reject' then
    if not public.is_admin() or v_borrowing.status <> 'pending' then
      raise exception 'This rejection is not allowed';
    end if;
    update public.borrowings set status = 'rejected', approved_by = auth.uid()
      where id = p_borrowing_id returning * into v_borrowing;

  else
    raise exception 'Unsupported borrowing action';
  end if;

  return public._borrowing_json(v_borrowing.id);
end;
$$;

revoke all on function public.transition_borrowing(uuid, text) from public;
revoke all on function public.transition_borrowing(uuid, text) from anon;
grant execute on function public.transition_borrowing(uuid, text) to authenticated;

-- ── 2. Status-change trigger: credit on request_return, not on confirm ───
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

  -- Student notifications (everything except `return_requested`, which is
  -- handled in the admin fan-out below).
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

  -- Inventory adjustments.
  --   - Decrement when a loan actually starts (status -> active).
  --   - Credit as soon as the student requests the return
  --     (active/overdue -> return_requested) so the item is borrowable
  --     again immediately and the same student can re-request it.
  --   - The admin's confirm_return (return_requested -> returned) does
  --     NOT touch available_count; we already credited it.
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

-- ── 3. Drop `return_requested` from the partial unique index ─────────────
-- Without this, the student can't submit a fresh `pending` request for
-- the same item while the previous loan is still in `return_requested`
-- limbo — the request_borrowing RPC's unique-violation fallback would
-- just hand them the existing row back instead of creating a new one.
drop index if exists borrowings_one_open_request_per_student_item;
create unique index borrowings_one_open_request_per_student_item
  on public.borrowings (student_id, equipment_id)
  where status in ('pending', 'approved', 'active', 'overdue');
