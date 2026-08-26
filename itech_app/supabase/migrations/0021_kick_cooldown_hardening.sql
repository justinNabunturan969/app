-- =============================================================================
-- 0021 — Kick-cooldown hardening
-- =============================================================================
-- Vulnerability in `end_active_session` (0013/0017): the cooldown upsert
-- unconditionally overwrote any previous row for that profile:
--
--     insert into session_end_cooldown(profile_id, ended_at, end_reason)
--     values (..., v_reason)
--     on conflict (profile_id) do update set ended_at = ..., end_reason = ...;
--
-- A kicked client knows its own profile_id, and `end_active_session(self, ...)
-- is allowed for any authenticated user. By calling
-- `end_active_session(self, 'closed')` right before the admin's kick landed —
-- or racing it — the client could replace the durable 'force_logout' cooldown
-- row with a harmless 'closed' one. `start_active_session` only refuses
-- resurrection for `end_reason = 'force_logout'`, so the 60-second
-- resurrection guard was defeated and the kicked device's heartbeat simply
-- re-inserted its `active_sessions` row.
--
-- Fix: a lesser end reason ('closed', 'signed_out') can no longer overwrite
-- an existing 'force_logout' cooldown. The reverse is still allowed (a real
-- force logout must always win), and repeated force logouts still refresh
-- the timestamp.
--
-- Safe to re-run: same signature and grants as 0017.

create or replace function public.end_active_session(
  p_profile_id uuid,
  p_reason text,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_session public.active_sessions;
  v_reason text;
  v_notice text;
begin
  if auth.uid() is null then raise exception 'Authentication is required'; end if;
  if p_profile_id <> auth.uid() and not public.is_admin() then raise exception 'Not allowed'; end if;
  v_reason := case when p_profile_id <> auth.uid() then 'force_logout' else p_reason end;
  if v_reason not in ('closed', 'signed_out', 'force_logout') then raise exception 'Invalid session end reason'; end if;

  select * into v_session from public.active_sessions where profile_id = p_profile_id for update;
  if not found then return; end if;

  insert into public.session_history(profile_id, logged_in_at, last_activity_at, end_reason)
    values (v_session.profile_id, v_session.logged_in_at, v_session.last_activity_at, v_reason);
  delete from public.active_sessions where profile_id = p_profile_id;

  -- Record the cooldown so a kicked client's next heartbeat cannot
  -- resurrect the row (see start_active_session in 0013).
  --
  -- HARDENED upsert: skip the write when the stored row is a 'force_logout'
  -- cooldown and the incoming reason is weaker. Otherwise a self-inflicted
  -- 'closed' end could erase the evidence that an admin kick happened and
  -- defeat the 60s resurrection guard.
  insert into public.session_end_cooldown(profile_id, ended_at, end_reason)
    values (p_profile_id, now(), v_reason)
    on conflict (profile_id) do update
      set ended_at   = excluded.ended_at,
          end_reason = excluded.end_reason
    where public.session_end_cooldown.end_reason <> 'force_logout'
       or excluded.end_reason = 'force_logout';

  -- Force logout: leave a one-shot reason the kicked device shows on the
  -- login screen. Blank notes fall back to the default wording.
  if v_reason = 'force_logout' then
    v_notice := coalesce(
      nullif(btrim(coalesce(p_note, '')), ''),
      'Your session was ended by an administrator.'
    );
    insert into public.force_logout_notices (profile_id, reason, ended_by)
      values (p_profile_id, v_notice, auth.uid())
      on conflict (profile_id) do update
        set reason = excluded.reason,
            ended_at = now(),
            ended_by = excluded.ended_by;
  end if;
end;
$$;

revoke all on function public.end_active_session(uuid, text, text) from public;
revoke all on function public.end_active_session(uuid, text, text) from anon;
grant execute on function public.end_active_session(uuid, text, text) to authenticated;
