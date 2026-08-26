-- =============================================================================
-- 0026 — Drop dead schema: profiles.nfc_uid
-- =============================================================================
-- `nfc_uid` was created in 0001 for a planned NFC tap-to-login feature that
-- never shipped. Grep across lib/ confirms zero references in the app, and no
-- migration ever wrote to it. Dead columns on the most-sensitive table in the
-- schema are pure attack surface (one more field every profile SELECT ships
-- to clients).
--
-- The unique index profiles_nfc_uid_key is dropped implicitly with the
-- column. Safe to re-run.

alter table public.profiles drop column if exists nfc_uid;
