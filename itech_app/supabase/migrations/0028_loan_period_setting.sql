-- =============================================================================
-- 0028 — Configurable loan period (was hardcoded 3 days)
-- =============================================================================
-- The `approve` branch of transition_borrowing stamped every approval with
-- `due_at = now() + interval '3 days'`. Changing the policy meant editing a
-- migration file. Fix: a tiny settings table plus a `_loan_period()` helper.
--
-- RLS: admins can read/update via the Data API; students have no grant.
-- The SECURITY DEFINER helper reads it server-side regardless.

create table if not exists public.app_settings (
  key        text primary key,
  value      text not null,
  updated_at timestamptz not null default now(),
  updated_by uuid references public.profiles (id) on delete set null
);

alter table public.app_settings enable row level security;

revoke all on public.app_settings from public;
revoke all on public.app_settings from anon;

grant select, update on public.app_settings to authenticated;

drop policy if exists "app_settings_admin_read" on public.app_settings;
create policy "app_settings_admin_read"
  on public.app_settings for select to authenticated
  using ((select public.is_admin()));

drop policy if exists "app_settings_admin_write" on public.app_settings;
create policy "app_settings_admin_write"
  on public.app_settings for update to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

insert into public.app_settings (key, value)
values ('loan_period_days', '3')
on conflict (key) do nothing;

-- Loan period as an interval, with a safe fallback when the setting is
-- missing or holds garbage (admins edit it through the dashboard).
create or replace function public._loan_period()
returns interval
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_raw text;
  v_days int;
begin
  select value into v_raw from public.app_settings where key = 'loan_period_days';
  begin
    v_days := coalesce(v_raw, '')::int;
  exception when others then
    v_days := null;
  end;
  if v_days is null or v_days < 1 or v_days > 60 then
    v_days := 3;  -- sensible default; also caps nonsense values
  end if;
  return make_interval(days => v_days);
end;
$$;

revoke all on function public._loan_period() from public;
revoke all on function public._loan_period() from anon;
revoke all on function public._loan_period() from authenticated;
grant execute on function public._loan_period() to authenticated;
