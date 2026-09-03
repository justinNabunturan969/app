-- =============================================================================
-- 0036 — Student-picked room on borrow requests
-- =============================================================================
-- The borrow confirm sheet lets the student say which iTech room the
-- equipment is for (Rooms 200–214 and 300–314), or leave it at "No room"
-- when the request isn't tied to one. The choice is stored as plain text
-- on the borrowing; pre-existing rows stay NULL, which every client reads
-- as "no room".
--
-- Safe to re-run.

alter table public.borrowings add column if not exists room text;

-- ── Enrichment helper: expose the room in every RPC payload ────────────────
create or replace function public._borrowing_json(p_borrowing_id uuid)
returns jsonb
language sql
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'id',           b.id,
    'equipment_id', b.equipment_id,
    'student_id',   b.student_id,
    'status',       b.status,
    'purpose',      b.purpose,
    'quantity',     b.quantity,
    'room',         b.room,
    'requested_at', b.requested_at,
    'borrowed_at',  b.borrowed_at,
    'due_at',       b.due_at,
    'returned_at',  b.returned_at,
    'equipment',    jsonb_build_object('id', e.id, 'name', e.name),
    'student',      jsonb_build_object(
                      'id', p.id,
                      'student_id', p.student_id,
                      'full_name', p.full_name)
  )
    from public.borrowings b
    join public.equipment e on e.id = b.equipment_id
    left join public.profiles p on p.id = b.student_id
   where b.id = p_borrowing_id;
$$;

revoke all on function public._borrowing_json(uuid) from public;
revoke all on function public._borrowing_json(uuid) from anon;
revoke all on function public._borrowing_json(uuid) from authenticated;

-- ── request_borrowing: accept the optional room ────────────────────────────
-- The argument list changes, and PostgreSQL refuses CREATE OR REPLACE for
-- that, so drop the 0031 signature first. Body is otherwise identical to
-- 0031 (row-locked availability check + unique-violation fallback).
drop function if exists public.request_borrowing(uuid, text, integer);
create function public.request_borrowing(
  p_equipment_id uuid,
  p_purpose text default '',
  p_quantity integer default 1,
  p_room text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_borrowing public.borrowings;
  v_available_count integer;
  v_room text;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required';
  end if;
  if p_quantity is null or p_quantity < 1 then
    raise exception 'Choose at least one item';
  end if;

  v_room := nullif(btrim(coalesce(p_room, '')), '');

  select available_count into v_available_count
    from public.equipment
   where id = p_equipment_id and status = 'available'
   for update;
  if not found or v_available_count < p_quantity then
    raise exception 'Only % unit(s) remain available', coalesce(v_available_count, 0);
  end if;

  begin
    insert into public.borrowings (student_id, equipment_id, status, purpose, quantity, room)
    values (auth.uid(), p_equipment_id, 'pending', left(coalesce(p_purpose, ''), 500), p_quantity, v_room)
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

  return public._borrowing_json(v_borrowing.id);
end;
$$;

revoke all on function public.request_borrowing(uuid, text, integer, text) from public;
grant execute on function public.request_borrowing(uuid, text, integer, text) to authenticated;
