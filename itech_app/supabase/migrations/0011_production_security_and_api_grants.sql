-- =============================================================================
-- Production hardening: explicit Data API access and profile protection
-- =============================================================================
-- Supabase no longer automatically exposes new public-schema tables to the
-- Data API. Grant only the operations used by this authenticated Flutter app;
-- RLS below still decides which rows are visible or mutable.

grant select, update on public.profiles to authenticated;
grant select on public.equipment to authenticated;
grant select on public.borrowings to authenticated;
grant select on public.active_sessions to authenticated;
grant select, update, delete on public.notifications to authenticated;
grant select on public.borrowing_audit_log to authenticated;
grant select on public.session_history to authenticated;

-- An UPDATE policy needs both USING and WITH CHECK. Without the latter an
-- account owner could change the row's ownership key while updating a profile.
drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
  on public.profiles for update to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

-- Profiles mirror identity fields from auth.users. A user may complete an
-- older blank student_id once, but may not replace it or rewrite the mirrored
-- email. This prevents account/profile impersonation through a direct API call.
create or replace function public.protect_profile_identity()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() = old.id then
    if new.email is distinct from old.email then
      raise exception 'Profile email is managed by authentication';
    end if;
    if old.student_id is not null
       and new.student_id is distinct from old.student_id then
      raise exception 'Student ID cannot be changed';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists on_profile_identity_change on public.profiles;
create trigger on_profile_identity_change
  before update on public.profiles
  for each row execute function public.protect_profile_identity();

-- This old SECURITY DEFINER helper allowed an unauthenticated caller to map a
-- student number to an email address. The app now signs PUP-webmail accounts
-- in by email, so the helper is no longer part of the public API.
revoke all on function public.auth_email_for_student_id(text) from public;
revoke all on function public.auth_email_for_student_id(text) from anon;
revoke all on function public.auth_email_for_student_id(text) from authenticated;
