-- =============================================================================
-- 0033: Admin equipment CRUD + classification
-- =============================================================================
-- The admin inventory tab needs to add, edit, and bulk-import equipment. The
-- existing RLS policy `equipment_admin_write` already covers INSERT / UPDATE /
-- DELETE for admins (it's `FOR ALL`), so no policy changes are needed — we
-- only need to add the new `classification` column (electrical / computer) and
-- a safety trigger so a freshly-inserted row starts with `available_count` =
-- `total_count`.
-- =============================================================================

-- 1. Allow the new status values for the existing check constraint. The
--    original constraint already includes 'available', 'borrowed',
--    'maintenance', 'retired' — keep those plus a future-proofing note.
--    (No change needed if those four are already in the check; the alter
--    is a no-op and the IF EXISTS makes it safe to re-run.)

-- 2. classification column: 'electrical' or 'computer'. Nullable so existing
--    rows aren't broken — but new admin-created rows should always set it.
alter table public.equipment
  add column if not exists classification text
    check (classification is null or classification in ('electrical', 'computer'));

create index if not exists equipment_classification_idx
  on public.equipment (classification);

-- 3. Default `available_count` to `total_count` on insert when the caller
--    didn't specify one. This keeps the "all units on the shelf" invariant
--    safe even if the admin's form forgets to send it. (A before-insert
--    trigger is the cheapest way — no RPC, no client-side gymnastics.)
create or replace function public.equipment_default_available_count()
returns trigger
language plpgsql
as $$
begin
  if new.available_count is null then
    new.available_count := new.total_count;
  end if;
  -- Defensive clamp: never let a freshly-inserted row over-report stock.
  if new.available_count > new.total_count then
    new.available_count := new.total_count;
  end if;
  if new.available_count < 0 then
    new.available_count := 0;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_equipment_default_available_count on public.equipment;
create trigger trg_equipment_default_available_count
  before insert on public.equipment
  for each row execute function public.equipment_default_available_count();

-- 4. Backfill the new column on existing rows. We don't know what they
--    are, so default to NULL — the admin can fill it in via the new Edit
--    dialog. (No update here on purpose; guessing would be worse than
--    leaving it blank.)
