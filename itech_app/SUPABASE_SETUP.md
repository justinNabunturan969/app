# PUP-ITech — Supabase Setup Guide

This project is wired up to talk to **Supabase** for auth, database, and
real-time updates. Mock data is still available as a fallback while you set
the project up. This file walks you through the whole thing.

---

## 1. Create a Supabase project (one-time, ~2 minutes)

1. Go to **https://supabase.com/dashboard** and sign in (GitHub is fastest).
2. Click **New project** → pick a name (e.g. `pup-itech`) and a strong
   database password. **Save the password somewhere** — you won't see it again.
3. Wait ~2 minutes for the project to provision. Status goes green when ready.

## 2. Run the schema migration (one-time)

1. In the Supabase dashboard, open **SQL Editor** (left sidebar).
2. Click **New query**.
3. Open `supabase/migrations/0001_initial_schema.sql` from this repo, copy
   the whole thing, paste it into the editor, and hit **Run**.
4. You should see "Success. No rows returned" — that's expected; the script
   creates tables, indexes, triggers, and RLS policies, none of which return
   rows.

To verify it worked, run this in the SQL editor:

```sql
select table_name from information_schema.tables
  where table_schema = 'public' order by table_name;
```

You should see `active_sessions`, `borrowings`, `equipment`, `notifications`,
and `profiles`.

## 3. Get your URL + anon key

In the Supabase dashboard:

1. Click **Project Settings** (gear icon, bottom-left) → **API**.
2. Copy:
   - **Project URL** — looks like `https://abcdefgh.supabase.co`
   - **anon public** key — the long `eyJhbGciOi...` string

## 4. Create your first user

You need at least one account to log in with. Easiest way is through the
dashboard, but you can also do it from the SQL editor:

```sql
-- After signing up via the app the first time, set the role:
update public.profiles set role = 'admin'
  where email = 'admin@pupitech.local';
```

Or, to pre-create a test user with a known password:

1. Dashboard → **Authentication** → **Users** → **Add user** → **Create new user**.
2. Email: `student1@pupitech.local` · Password: `password123` · "Auto Confirm User" ✅
3. Repeat for an admin: `admin@pupitech.local` / `password123`.
4. Then in the SQL editor:

```sql
update public.profiles set role = 'admin', full_name = 'Demo Admin'
  where email = 'admin@pupitech.local';

update public.profiles set role = 'student', full_name = 'Juan dela Cruz',
  student_id = '2024-04421-MN-0', program = 'BS CpE'
  where email = 'student1@pupitech.local';
```

## 5. Seed some equipment (optional, for the demo)

```sql
insert into public.equipment (code, name, category, location, total_count, available_count, description) values
  ('E-9020', 'Fluke 87V Digital Multimeter', 'Test Equipment', 'Room 301 - Electronics Lab', 3, 3, 'True RMS industrial multimeter.'),
  ('E-10001', 'Stanley 12-Piece Screwdriver Set', 'Hand Tools', 'Room 205 - Tool Room', 5, 5, 'Slotted, Phillips, and Torx.'),
  ('E-8008', 'Heat Gun (2 Modes)', 'Soldering', 'Room 205 - Tool Room', 2, 2, 'For heat-shrink tubing and SMD rework.'),
  ('E-5222', 'DC Power Supply 0-30V / 0-5A', 'Bench Supplies', 'Room 210 - Bench Supplies', 4, 4, 'Variable regulated bench supply.'),
  ('E-3141', 'Arduino Uno R3 Kit', 'Microcontrollers', 'Room 312 - Embedded Lab', 10, 10, 'ATmega328P, USB-B cable included.');
```

## 6. Run the app with your credentials

From the project root:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi...
```

For VS Code: open `.vscode/launch.json` (or create it) and add the
`--dart-define` flags under `args` for the `flutter` configuration.

For Android Studio: **Run → Edit Configurations → Flutter → Additional args**.

If you forget the flags, the app will throw a clear `StateError` at startup
telling you exactly which flag is missing.

---

## How the code is laid out

| File | What it does |
|---|---|
| `lib/env/supabase_config.dart` | Reads `--dart-define` and asserts they're set. |
| `lib/main.dart` | Initializes Supabase before `runApp`. |
| `lib/auth/session/auth_session_storage.dart` | Thin wrapper over Supabase Auth. The login screens still call `saveStudentSession` / `saveAdminSession` — those now do `supabase.auth.signInWithPassword` under the hood. |
| `lib/data/repositories/repository_bundle.dart` | Has both `RepositoryBundle.mock()` (existing) and `RepositoryBundle.fromSupabase()` (new). Swap in your `main.dart` to switch. |
| `lib/data/repositories/supabase/*.dart` | The four Supabase-backed repositories. |
| `supabase/migrations/0001_initial_schema.sql` | The full DB schema with RLS. Run it once. |

## What you get out of the box

- **Auth** — sign in / out via Supabase. Sessions persist across launches.
- **Postgres** — your data lives in real tables, with foreign keys and indexes.
- **Row-Level Security** — students can only see their own borrowings, admins
  can see everything. Enforced at the DB layer (great defense talking point).
- **Realtime** — changes to `equipment`, `borrowings`, `active_sessions`,
  and `notifications` are published over WebSockets. The `select` projection
  is in the migration; the Flutter app can subscribe with:
  ```dart
  supabase
    .channel('public:equipment')
    .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'equipment',
      callback: (payload) => /* ... */,
    )
    .subscribe();
  ```

## Switching between mock data and Supabase

In `lib/main.dart`, change:

```dart
// before — in-memory mock data, no backend
final bundle = RepositoryBundle.mock();

// after — real Supabase backend
final bundle = RepositoryBundle.fromSupabase();
```

You can keep both, gated by an environment flag, so you can demo either mode
during your defense.

## Production checklist (before going live, not needed for thesis)

- Enable **email confirmations** in Auth settings.
- Configure **password recovery** email template.
- Add a **favorites** table so the heart icon persists server-side.
- Add an `equipment_likes (profile_id, equipment_id)` table with RLS:
  ```sql
  create table public.equipment_likes (
    profile_id uuid references public.profiles (id) on delete cascade,
    equipment_id uuid references public.equipment (id) on delete cascade,
    primary key (profile_id, equipment_id)
  );
  ```
- Add a **daily overdue cron** via Supabase Edge Functions or pg_cron:
  ```sql
  update public.borrowings set status = 'overdue'
    where status = 'active' and due_at < now();
  ```
- Lock down RLS further: require admins to come from a specific domain.
- Turn on **automatic backups** (paid plan only).

---

## Quick troubleshooting

| Symptom | Fix |
|---|---|
| `StateError: Supabase is not configured` at startup | You forgot the `--dart-define` flags. Add them to your run command. |
| Login fails with `Invalid login credentials` | The user doesn't exist in `auth.users` yet. Create them in **Authentication → Users** in the dashboard. |
| `permission denied for table profiles` | RLS is blocking the read. Make sure you ran the migration script — it creates the policies. |
| Equipment list is empty | You haven't seeded the `equipment` table yet. See step 5. |
| `Project has been paused` | Free-tier projects pause after 7 days of inactivity. Open the dashboard once a week to keep it alive. |
| `WebSocket failed to connect` | On a real device, make sure you use the **`https://`** URL, not `http://`. For local dev on the emulator, `127.0.0.1` doesn't work — use your machine's LAN IP or the `https://` project URL. |
