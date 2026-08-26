-- =============================================================================
-- 0023 — RLS performance: initplan-cached auth checks
-- =============================================================================
-- Pre-0011 policies evaluate `auth.uid()` / `public.is_admin()` per ROW.
-- Supabase best practice wraps them in a scalar subquery — `(select
-- auth.uid())` / `(select public.is_admin())` — so PostgreSQL computes the
-- value ONCE per statement (an InitPlan) instead of once per row. On large
-- scans this removes the per-row overhead entirely.
--
-- Behaviour is identical; only evaluation strategy changes. Policies already
-- following the pattern (0011 profiles_update_own, 0015 profiles_insert_self,
-- 0017 force_logout_notice_select_own) are left untouched.
--
-- Safe to re-run: every policy below is dropped then recreated identically.

-- ── profiles ────────────────────────────────────────────────────────────────
drop policy if exists "profiles_select_own_or_admin" on public.profiles;
create policy "profiles_select_own_or_admin"
  on public.profiles for select
  using ((select auth.uid()) = id or (select public.is_admin()));

-- ── equipment ───────────────────────────────────────────────────────────────
drop policy if exists "equipment_admin_write" on public.equipment;
create policy "equipment_admin_write"
  on public.equipment for all
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

-- ── borrowings ──────────────────────────────────────────────────────────────
-- Writes go through SECURITY DEFINER RPCs (request/transition_borrowing),
-- which bypass RLS; this read policy is the hot path worth optimizing.
drop policy if exists "borrowings_select_own_or_admin" on public.borrowings;
create policy "borrowings_select_own_or_admin"
  on public.borrowings for select
  using (student_id = (select auth.uid()) or (select public.is_admin()));

-- ── active_sessions ─────────────────────────────────────────────────────────
drop policy if exists "active_sessions_admin_read" on public.active_sessions;
create policy "active_sessions_admin_read"
  on public.active_sessions for select
  using ((select public.is_admin()) or profile_id = (select auth.uid()));

-- ── notifications ───────────────────────────────────────────────────────────
drop policy if exists "notifications_select_own" on public.notifications;
create policy "notifications_select_own"
  on public.notifications for select
  using (recipient_id = (select auth.uid()));

drop policy if exists "notifications_update_own" on public.notifications;
create policy "notifications_update_own"
  on public.notifications for update
  using (recipient_id = (select auth.uid()))
  with check (recipient_id = (select auth.uid()));

drop policy if exists "notifications_delete_own" on public.notifications;
create policy "notifications_delete_own"
  on public.notifications for delete
  using (recipient_id = (select auth.uid()));

-- ── audit / history tables ──────────────────────────────────────────────────
drop policy if exists "borrowing_audit_admin_read" on public.borrowing_audit_log;
create policy "borrowing_audit_admin_read"
  on public.borrowing_audit_log for select
  using ((select public.is_admin()));

drop policy if exists "session_history_admin_read" on public.session_history;
create policy "session_history_admin_read"
  on public.session_history for select to authenticated
  using ((select public.is_admin()));
