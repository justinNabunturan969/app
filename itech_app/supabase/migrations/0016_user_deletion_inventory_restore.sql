-- =============================================================================
-- Auto-return inventory when a user (or a borrowing row) is deleted
-- =============================================================================
-- Problem: `borrowings.student_id` references `profiles(id) on delete
-- cascade`, and `profiles.id` references `auth.users(id) on delete cascade`.
-- Deleting a user in Supabase Authentication therefore silently removed
-- their open loans WITHOUT crediting `equipment.available_count` back — the
-- units stayed "out" forever and the equipment showed as unavailable.
--
-- Fix, in two parts:
--
--   1. GOING FORWARD — a BEFORE DELETE trigger on `borrowings` credits the
--      units back whenever a row in an inventory-holding state ('active',
--      'overdue', 'return_requested') is removed, for ANY reason, including
--      the FK cascade that fires when an auth user is deleted. Deleting a
--      user now effectively returns everything they had on loan.
--
--   2. ONE-TIME REPAIR — a recount below reconciles every equipment row
--      with the loans that actually exist today, restoring the units lost
--      to the already-deleted users. Safe to re-run: it is derived purely
--      from current data.

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Inventory restore on delete
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.restore_inventory_on_borrowing_delete()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Only loans that physically hold inventory credit units back. 'pending'
  -- never decremented the count, and 'returned' / 'rejected' rows already
  -- gave their units back through the status-change trigger (0014).
  if old.status in ('active', 'overdue', 'return_requested') then
    update public.equipment
       set available_count = least(
             available_count + coalesce(old.quantity, 1),
             total_count
           )
     where id = old.equipment_id;
  end if;
  return old;
end;
$$;

drop trigger if exists on_borrowing_delete_restore_inventory on public.borrowings;
create trigger on_borrowing_delete_restore_inventory
  before delete on public.borrowings
  for each row execute function public.restore_inventory_on_borrowing_delete();

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. One-time recount: available_count := total_count − units currently out.
-- The deleted users' borrowing rows are already gone (cascade), so their
-- units drop out of the "out" sum and return to the available pool.
-- ─────────────────────────────────────────────────────────────────────────────
update public.equipment e
   set available_count = greatest(
         0,
         e.total_count - coalesce((
           select sum(b.quantity)
             from public.borrowings b
            where b.equipment_id = e.id
              and b.status in ('active', 'overdue', 'return_requested')
         ), 0)
       );

-- Defensive normalization: an item can only be 'borrowed' when every unit
-- is out. If the recount above shows free units, make it borrowable again.
update public.equipment
   set status = 'available'
 where status = 'borrowed'
   and available_count > 0;
