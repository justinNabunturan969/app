-- =============================================================================
-- 0030 — Favorites (equipment likes), persisted
-- =============================================================================
-- The heart button was a silent client-side no-op: likes lived in controller
-- state and vanished on every reload. This ships the real thing.
--
--   favorites (profile_id, equipment_id) — one row per like.
--
-- RLS: a user sees and touches ONLY their own rows, which also makes the
-- PostgREST embed safe: `select *, favorites ( profile_id )` from equipment
-- returns each item's like-count-for-me (empty or one row) without leaking
-- anyone else's taste.
--
-- Safe to re-run.

create table if not exists public.favorites (
  profile_id  uuid not null references public.profiles (id)   on delete cascade,
  equipment_id uuid not null references public.equipment (id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (profile_id, equipment_id)
);

alter table public.favorites enable row level security;

revoke all on public.favorites from public;
revoke all on public.favorites from anon;

grant select, insert, delete on public.favorites to authenticated;

drop policy if exists "favorites_select_own" on public.favorites;
create policy "favorites_select_own"
  on public.favorites for select to authenticated
  using ((select auth.uid()) = profile_id);

drop policy if exists "favorites_insert_own" on public.favorites;
create policy "favorites_insert_own"
  on public.favorites for insert to authenticated
  with check ((select auth.uid()) = profile_id);

drop policy if exists "favorites_delete_own" on public.favorites;
create policy "favorites_delete_own"
  on public.favorites for delete to authenticated
  using ((select auth.uid()) = profile_id);
