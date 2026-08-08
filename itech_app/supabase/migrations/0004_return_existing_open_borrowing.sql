-- =============================================================================
-- Make repeated taps / stale clients safe when requesting equipment.
--
-- The partial unique index added in 0003 remains the source of truth: a
-- student can only have one open request for an item. Instead of exposing its
-- raw PostgreSQL unique-constraint exception, return that existing request.
-- =============================================================================

create or replace function public.request_borrowing(
  p_equipment_id uuid,
  p_purpose text default ''
)
returns public.borrowings
language plpgsql
security definer
set search_path = public
as $$
declare
  v_borrowing public.borrowings;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required';
  end if;

  if not exists (
    select 1 from public.equipment
    where id = p_equipment_id and status = 'available' and available_count > 0
  ) then
    raise exception 'This equipment is unavailable';
  end if;

  begin
    insert into public.borrowings (student_id, equipment_id, status, purpose)
    values (auth.uid(), p_equipment_id, 'pending', left(coalesce(p_purpose, ''), 500))
    returning * into v_borrowing;
  exception when unique_violation then
    -- A second tap (or an older cached client) raced the first request. The
    -- unique index has already protected the data, so return the open row.
    select * into v_borrowing
      from public.borrowings
     where student_id = auth.uid()
       and equipment_id = p_equipment_id
       and status in ('pending', 'approved', 'active', 'overdue')
     order by requested_at desc
     limit 1;

    if not found then
      raise;
    end if;
  end;

  return v_borrowing;
end;
$$;

revoke all on function public.request_borrowing(uuid, text) from public;
grant execute on function public.request_borrowing(uuid, text) to authenticated;
