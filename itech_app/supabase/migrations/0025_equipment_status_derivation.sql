-- =============================================================================
-- 0025 — Derive equipment.status from counts instead of manual maintenance
-- =============================================================================
-- `equipment.status` ('available'/'borrowed') duplicated information that was
-- already derivable from `available_count`, and both were maintained by hand
-- in different places — migration 0016 had to patch the resulting drift once
-- already. Any future writer that forgets one of the two reintroduces drift.
--
-- Fix: for items with stock (total_count > 0), availability-class statuses are
-- now DERIVED on every write:
--
--     available_count > 0  ->  'available'
--     available_count = 0  ->  'borrowed'
--
-- 'maintenance' and 'retired' are deliberate human decisions and are never
-- overwritten. Items with total_count = 0 keep whatever status an admin set
-- (there is no meaningful derivation for an empty row).
--
-- A one-time backfill below repairs any drift that accumulated before this
-- trigger exists. Safe to re-run.

-- ── One-time drift repair (before installing the trigger) ───────────────────
update public.equipment
   set status = case when available_count > 0 then 'available' else 'borrowed' end
 where total_count > 0
   and status in ('available', 'borrowed')
   and status is distinct from
       (case when available_count > 0 then 'available' else 'borrowed' end);

-- ── Derivation trigger ──────────────────────────────────────────────────────
create or replace function public.derive_equipment_status()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.total_count > 0 and new.status in ('available', 'borrowed') then
    new.status := case when new.available_count > 0 then 'available' else 'borrowed' end;
  end if;
  return new;
end;
$$;

drop trigger if exists on_equipment_derive_status on public.equipment;
create trigger on_equipment_derive_status
  before insert or update on public.equipment
  for each row execute function public.derive_equipment_status();
