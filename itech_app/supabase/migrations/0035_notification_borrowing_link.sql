-- =============================================================================
-- 0035: Link notifications to the borrowing they relate to
-- =============================================================================
-- The user wants a "Return to confirm" entry on the admin's notifications
-- tab that, when tapped, takes the admin straight to the right return
-- confirmation form. To do that without a brittle body-text match we
-- attach the borrowing id to the notification row at insert time.
--
-- This migration:
--   1. Adds `related_borrowing_id` to `notifications` (FK to borrowings,
--      ON DELETE CASCADE so cleanup is automatic).
--   2. Updates `handle_borrowing_status_change` to stamp the field on
--      the two notifications that mention a specific loan:
--        - 'return_requested' fan-out to admins (the new "Return to
--          confirm" entry)
--        - 'returned' notification to the student (so the student can
--          tap it for details later if we want to surface that)
--      Other notifications (approved / rejected / overdue / etc.) leave
--      the field NULL — they're not action-bound.
-- =============================================================================

-- 1. Schema addition on notifications ---------------------------------------
alter table public.notifications
  add column if not exists related_borrowing_id uuid
    references public.borrowings (id) on delete cascade;

create index if not exists notifications_related_borrowing_idx
  on public.notifications (related_borrowing_id);

-- 2. Update the trigger to stamp the field ---------------------------------
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
    -- Stamp the new column so the admin can deep-link from the
    -- notifications tab straight to the return confirmation form.
    insert into public.notifications (recipient_id, type, title, body, related_borrowing_id)
      select id, 'reminder',
        'Return to confirm — ' || coalesce(v_equipment_name, 'equipment'),
        coalesce(v_student_name, 'A student') ||
          case when v_student_number is null then '' else ' (' || v_student_number || ')' end ||
          ' marked this item for return. Tap to record the condition.',
        new.id
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
