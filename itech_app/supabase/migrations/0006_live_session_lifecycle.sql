-- Live occupancy is a short-lived session lease, never a list of accounts.
-- Every end path records an immutable server-side history entry first.
drop trigger if exists on_auth_user_session on auth.users;

create table if not exists public.session_history (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  logged_in_at timestamptz not null,
  last_activity_at timestamptz not null,
  ended_at timestamptz not null default now(),
  end_reason text not null check (end_reason in ('closed', 'signed_out', 'force_logout', 'expired'))
);
create index if not exists session_history_profile_ended_idx
  on public.session_history(profile_id, ended_at desc);
alter table public.session_history enable row level security;
drop policy if exists session_history_admin_read on public.session_history;
create policy session_history_admin_read on public.session_history for select to authenticated using (public.is_admin());

create or replace function public.start_active_session()
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Authentication is required'; end if;
  insert into public.active_sessions(profile_id, logged_in_at, last_activity_at, activity)
  values (auth.uid(), now(), now(), 'active')
  on conflict (profile_id) do update set logged_in_at = excluded.logged_in_at,
    last_activity_at = excluded.last_activity_at, activity = 'active';
end; $$;

create or replace function public.touch_active_session()
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Authentication is required'; end if;
  update public.active_sessions set last_activity_at = now(), activity = 'active'
    where profile_id = auth.uid();
end; $$;

create or replace function public.end_active_session(p_profile_id uuid, p_reason text)
returns void language plpgsql security definer set search_path = public as $$
declare v_session public.active_sessions; v_reason text;
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
end; $$;

create or replace function public.expire_stale_sessions()
returns integer language plpgsql security definer set search_path = public as $$
declare v_count integer;
begin
  if not public.is_admin() then raise exception 'Admin access is required'; end if;
  with expired as (
    delete from public.active_sessions
     where last_activity_at < now() - interval '2 minutes'
     returning profile_id, logged_in_at, last_activity_at
  ), logged as (
    insert into public.session_history(profile_id, logged_in_at, last_activity_at, end_reason)
    select profile_id, logged_in_at, last_activity_at, 'expired' from expired
    returning 1
  ) select count(*) into v_count from logged;
  return v_count;
end; $$;

revoke all on function public.start_active_session() from public;
revoke all on function public.touch_active_session() from public;
revoke all on function public.end_active_session(uuid, text) from public;
revoke all on function public.expire_stale_sessions() from public;
grant execute on function public.start_active_session() to authenticated;
grant execute on function public.touch_active_session() to authenticated;
grant execute on function public.end_active_session(uuid, text) to authenticated;
grant execute on function public.expire_stale_sessions() to authenticated;
