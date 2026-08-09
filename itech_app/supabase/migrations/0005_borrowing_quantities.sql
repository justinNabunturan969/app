-- Allow a student to request multiple units of one equipment stock record.
alter table public.borrowings
  add column if not exists quantity integer not null default 1;

alter table public.borrowings
  drop constraint if exists borrowings_quantity_positive;
alter table public.borrowings
  add constraint borrowings_quantity_positive check (quantity > 0);

-- Replace the previous two-argument RPC, then validate the requested count
-- inside the transaction. Only the database decides whether inventory can
-- satisfy the request; the client-side selector is just a convenience.
drop function if exists public.request_borrowing(uuid, text);
create function public.request_borrowing(
  p_equipment_id uuid,
  p_purpose text default '',
  p_quantity integer default 1
)
returns public.borrowings
language plpgsql
security definer
set search_path = public
as $$
declare
  v_borrowing public.borrowings;
  v_available_count integer;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required';
  end if;
  if p_quantity is null or p_quantity < 1 then
    raise exception 'Choose at least one item';
  end if;

  select available_count into v_available_count
    from public.equipment
   where id = p_equipment_id and status = 'available';
  if not found or v_available_count < p_quantity then
    raise exception 'Only % unit(s) are available', coalesce(v_available_count, 0);
  end if;

  begin
    insert into public.borrowings (student_id, equipment_id, status, purpose, quantity)
    values (auth.uid(), p_equipment_id, 'pending', left(coalesce(p_purpose, ''), 500), p_quantity)
    returning * into v_borrowing;
  exception when unique_violation then
    select * into v_borrowing
      from public.borrowings
     where student_id = auth.uid()
       and equipment_id = p_equipment_id
       and status in ('pending', 'approved', 'active', 'overdue')
     order by requested_at desc
     limit 1;
    if not found then raise; end if;
  end;
  return v_borrowing;
end;
$$;

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
    if v_borrowing.student_id <> auth.uid() or v_borrowing.status not in ('active', 'overdue') then
      raise exception 'This return request is not allowed';
    end if;
    update public.borrowings set status = 'returned', returned_at = v_now
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
    update public.borrowings set status = 'rejected', returned_at = v_now, approved_by = auth.uid()
      where id = p_borrowing_id returning * into v_borrowing;
  else
    raise exception 'Unsupported borrowing action';
  end if;
  return v_borrowing;
end;
$$;

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

  if new.status in ('approved', 'active', 'rejected', 'returned', 'overdue') then
    case new.status
      when 'approved' then v_type := 'approved'; v_title := 'Request approved'; v_body := 'Your borrowing request has been approved. You can pick up the equipment.';
      when 'active' then v_type := 'approved'; v_title := 'Equipment ready for pickup'; v_body := 'Your equipment is now active and ready for use.';
      when 'rejected' then v_type := 'rejected'; v_title := 'Request rejected'; v_body := 'Your borrowing request was rejected. Contact admin for details.';
      when 'returned' then v_type := 'returned'; v_title := 'Return confirmed'; v_body := 'Your borrowing return has been recorded. Thanks!';
      when 'overdue' then v_type := 'overdue'; v_title := 'Equipment overdue'; v_body := 'Your borrowed equipment is overdue. Please return it as soon as possible.';
    end case;
    select name into v_equipment_name from public.equipment where id = new.equipment_id;
    insert into public.notifications (recipient_id, type, title, body)
      values (new.student_id, v_type, v_title || ' — ' || coalesce(v_equipment_name, 'your item'), v_body);
    if new.status = 'returned' and auth.uid() = new.student_id then
      select full_name, student_id into v_student_name, v_student_number from public.profiles where id = new.student_id;
      insert into public.notifications (recipient_id, type, title, body)
        select id, 'reminder', 'Return requested — ' || coalesce(v_equipment_name, 'equipment'),
          coalesce(v_student_name, 'A student') || case when v_student_number is null then '' else ' (' || v_student_number || ')' end || ' marked this item for return. Please verify the physical return.'
        from public.profiles where role = 'admin';
    end if;
  end if;

  if new.status = 'active' and old.status <> 'active' then
    update public.equipment set available_count = greatest(available_count - new.quantity, 0) where id = new.equipment_id;
  elsif new.status = 'returned' and old.status <> 'returned' then
    update public.equipment set available_count = least(available_count + new.quantity, total_count) where id = new.equipment_id;
  end if;
  return new;
end;
$$;

revoke all on function public.request_borrowing(uuid, text, integer) from public;
grant execute on function public.request_borrowing(uuid, text, integer) to authenticated;
