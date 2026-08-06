-- =============================================================================
-- Existing-project upgrade: admin return-request notifications
-- =============================================================================
-- Run this after 0001_initial_schema.sql when that migration was already
-- applied to your Supabase project. It only replaces the existing trigger
-- function; it does not replace tables or delete data.

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
  if OLD.status is not distinct from NEW.status then return new; end if;

  if NEW.status in ('approved', 'active', 'rejected', 'returned', 'overdue') then
    case NEW.status
      when 'approved' then v_type := 'approved'; v_title := 'Request approved'; v_body := 'Your borrowing request has been approved. You can pick up the equipment.';
      when 'active' then v_type := 'approved'; v_title := 'Equipment ready for pickup'; v_body := 'Your equipment is now active and ready for use.';
      when 'rejected' then v_type := 'rejected'; v_title := 'Request rejected'; v_body := 'Your borrowing request was rejected. Contact admin for details.';
      when 'returned' then v_type := 'returned'; v_title := 'Return confirmed'; v_body := 'Your equipment return has been recorded. Thanks!';
      when 'overdue' then v_type := 'overdue'; v_title := 'Equipment overdue'; v_body := 'Your borrowed equipment is overdue. Please return it as soon as possible.';
    end case;

    select name into v_equipment_name from public.equipment where id = NEW.equipment_id;
    insert into public.notifications (recipient_id, type, title, body)
    values (NEW.student_id, v_type, v_title || ' — ' || coalesce(v_equipment_name, 'your item'), v_body);

    if NEW.status = 'returned' and auth.uid() = NEW.student_id then
      select full_name, student_id into v_student_name, v_student_number
        from public.profiles where id = NEW.student_id;
      insert into public.notifications (recipient_id, type, title, body)
      select id, 'reminder',
        'Return requested — ' || coalesce(v_equipment_name, 'equipment'),
        coalesce(v_student_name, 'A student') ||
          case when v_student_number is null then '' else ' (' || v_student_number || ')' end ||
          ' marked this item for return. Please verify the physical return.'
      from public.profiles where role = 'admin';
    end if;
  end if;

  if NEW.status = 'active' and OLD.status <> 'active' then
    update public.equipment set available_count = greatest(available_count - 1, 0) where id = NEW.equipment_id;
  elsif NEW.status = 'returned' and OLD.status <> 'returned' then
    update public.equipment set available_count = least(available_count + 1, total_count) where id = NEW.equipment_id;
  end if;
  return new;
end;
$$;
