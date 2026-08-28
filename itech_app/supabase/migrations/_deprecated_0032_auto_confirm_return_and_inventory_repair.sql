-- =============================================================================
-- 0032: Auto-confirm returns + inventory repair
-- =============================================================================
-- The app now skips the admin verification step: when a student taps
-- "return", the client calls `confirm_return` directly so the return is
-- final immediately and inventory is credited atomically.
--
-- Migration 0014 restricted `confirm_return` to admins only, so student
-- calls failed with "This return confirmation is not allowed" — the row
-- stayed `active`/`overdue`/`return_requested` and
-- equipment.available_count was never restored.
--
-- This migration:
--   1. Allows the OWNING STUDENT to `confirm_return` their own loan
--      (auto-confirm). Admins keep the same ability.
--   2. Repairs rows stuck in `return_requested` (returns that failed
--      mid-flow) by finalizing them — the status-change trigger credits
--      inventory for each.
--   3. Recomputes available_count for every equipment row from the
--      source of truth: total_count minus open loans
--      (active / overdue / return_requested), clamped to [0, total].
-- =============================================================================

-- ── 1. Auto-confirm: the owning student may confirm their own return ────
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
    -- Legacy path kept for older clients: behaves as before.
    if v_borrowing.student_id <> auth.uid()
       or v_borrowing.status not in ('active', 'overdue') then
      raise exception 'This return request is not allowed';
    end if;
    update public.borrowings set status = 'return_requested'
      where id = p_borrowing_id returning * into v_borrowing;

  elsif p_action = 'confirm_return' then
    -- Auto-confirm: the owning student OR any admin may confirm.
    -- This is the transition that increments equipment.available_count.
    if (not public.is_admin() and v_borrowing.student_id <> auth.uid())
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

-- ── 2. Repair rows stuck in `return_requested` ──────────────────────────
-- Finalize them; the handle_borrowing_status_change trigger credits
-- available_count for each transition to 'returned'.
update public.borrowings
   set status = 'returned', returned_at = coalesce(returned_at, now())
 where status = 'return_requested';

-- ── 3. Recompute available_count from the source of truth ───────────────
-- Open loans (active / overdue / return_requested) are the units that are
-- out. Everything else (pending / returned / rejected / cancelled) is on
-- the shelf. Clamp to [0, total_count] for safety.
update public.equipment e
   set available_count = greatest(
         least(
           e.total_count - coalesce(o.open_units, 0),
           e.total_count
         ),
         0
       )
  from (
    select equipment_id, sum(quantity) as open_units
      from public.borrowings
     where status in ('active', 'overdue', 'return_requested')
     group by equipment_id
  ) o
 where o.equipment_id = e.id
   and e.available_count is distinct from
       greatest(least(e.total_count - coalesce(o.open_units, 0), e.total_count), 0);
