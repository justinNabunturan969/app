-- =============================================================================
-- 0029 — Borrowing RPCs return the enriched row (no client re-fetch)
-- =============================================================================
-- request_borrowing / transition_borrowing returned a bare `borrowings` row,
-- so the Flutter repository had to re-query by id after EVERY action just to
-- pick up the equipment and student display names — an extra round-trip per
-- tap.
--
-- Fix: both RPCs now return a jsonb object with `equipment` and `student`
-- sub-objects embedded, mirroring exactly what PostgREST's relationship join
-- (`_selectWithJoins` in supabase_borrowings_repository.dart) produces. The
-- client builds its model straight from the response.
--
-- Backwards compatible: old app versions only read row['id'], which is still
-- present. The return TYPE changes from public.borrowings to jsonb, but
-- PostgREST serialises both as JSON objects.
--
-- transition_borrowing also picks up two earlier fixes in this rewrite:
--   * the student `cancel` action (0024), and
--   * due_at now comes from the configurable loan period (0028) instead of
--     a hardcoded interval '3 days'.
--
-- Safe to re-run.

-- ── Shared enrichment: one place builds the response shape ──────────────────
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

-- The return type changes from public.borrowings to jsonb, and PostgreSQL
-- refuses CREATE OR REPLACE when the return type differs (SQLSTATE 42P13).
-- Drop the old versions first — their grants go with them and are re-applied
-- after the new bodies below. Brief window between drop and create only
-- matters during this migration run.
drop function if exists public.request_borrowing(uuid, text, integer);
drop function if exists public.transition_borrowing(uuid, text);

create or replace function public.request_borrowing(
  p_equipment_id uuid,
  p_purpose text default '',
  p_quantity integer default 1
)
returns jsonb
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
    -- One open request per student+item: surface the existing row instead
    -- of failing the tap (same UX as before).
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

create or replace function public.transition_borrowing(
  p_borrowing_id uuid,
  p_action text
)
returns jsonb
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
    if v_borrowing.student_id <> auth.uid()
       or v_borrowing.status not in ('active', 'overdue') then
      raise exception 'This return request is not allowed';
    end if;
    update public.borrowings set status = 'return_requested'
      where id = p_borrowing_id returning * into v_borrowing;

  elsif p_action = 'confirm_return' then
    if not public.is_admin()
       or v_borrowing.status not in ('return_requested', 'active', 'overdue') then
      raise exception 'This return confirmation is not allowed';
    end if;
    update public.borrowings
      set status = 'returned', returned_at = v_now
      where id = p_borrowing_id returning * into v_borrowing;

  elsif p_action = 'cancel' then
    -- Student withdraws a still-pending request (migration 0024).
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
          -- Loan period comes from app_settings (migration 0028), no longer
          -- hardcoded to 3 days here.
          due_at = v_now + public._loan_period(),
          approved_by = auth.uid()
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

  return public._borrowing_json(v_borrowing.id);
end;
$$;

-- Grants unchanged.
revoke all on function public.request_borrowing(uuid, text, integer) from public;
grant execute on function public.request_borrowing(uuid, text, integer) to authenticated;
revoke all on function public.transition_borrowing(uuid, text) from public;
revoke all on function public.transition_borrowing(uuid, text) from anon;
grant execute on function public.transition_borrowing(uuid, text) to authenticated;
