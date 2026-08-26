-- =============================================================================
-- 0024 — Students can cancel their own pending request
-- =============================================================================
-- Gap: `transition_borrowing` had no student-side cancellation, and the
-- partial unique index `borrowings_one_open_request_per_student_item`
-- counts a stuck 'pending' row as an open request — so a mistyped or
-- unwanted request BLOCKED that student from re-requesting the item until
-- an admin approved or rejected it.
--
-- Fix:
--   1. New status 'cancelled' (terminal, like rejected).
--   2. New `cancel` action: the owning student may cancel their own request
--      while it is still 'pending'. Admins keep using `reject`.
--   3. 'cancelled' is deliberately NOT in the unique index's open-status
--      list, so cancelling immediately frees the slot for re-requesting.
--   4. No notification fires for a self-cancellation (the student did it
--      themselves); the audit log still records the transition, and the
--      admin's Pending tab updates via borrowings realtime.
--
-- Safe to re-run.

-- ── Allow the new status ─────────────────────────────────────────────────────
alter table public.borrowings
  drop constraint if exists borrowings_status_check;
alter table public.borrowings
  add constraint borrowings_status_check
  check (status in (
    'pending', 'approved', 'active', 'overdue',
    'return_requested', 'returned', 'rejected', 'cancelled'
  ));

-- NOTE: borrowings_one_open_request_per_student_item (0014) intentionally
-- stays unchanged — 'cancelled' must not count as an open request.

-- ── transition_borrowing: add student-side `cancel` ─────────────────────────
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

  elsif p_action = 'cancel' then
    -- NEW: the owning student withdraws a still-pending request. Frees the
    -- one-open-request slot immediately ('cancelled' is terminal). Admins
    -- keep `reject` for requests they don't want.
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
