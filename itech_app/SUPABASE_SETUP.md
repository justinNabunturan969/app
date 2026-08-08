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

The migration is safe to run again. If a prior run stopped at the Realtime
section with an “already member of publication” error, pull the latest version
of this file and run the complete script again.

### Existing projects: apply later migrations

If you had already run `0001_initial_schema.sql` before adding live
notifications and student return requests, also run
`supabase/migrations/0002_live_notifications_and_return_requests.sql` in the
SQL Editor. It upgrades the notification trigger without deleting data.

Then run `supabase/migrations/0003_security_hardening_and_audit.sql`. This is
required before using the current app build: it protects profile roles, moves
borrowing approval/return actions into secure database functions, prevents
duplicate open requests, and adds an admin-only audit log.

Finally, run `supabase/migrations/0004_return_existing_open_borrowing.sql`.
It preserves the duplicate-request protection while safely returning the
existing open request when an older client or a repeated tap submits again.

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
2. Student email: `student1@pup.edu.ph` · choose a password · "Auto Confirm User" ✅
3. Repeat for an admin: `admin1@pup.edu.ph` · choose a password · "Auto Confirm User" ✅.
4. Then in the SQL editor:

```sql
update public.profiles set role = 'admin', full_name = 'Demo Admin'
  where email = 'admin1@pup.edu.ph';

update public.profiles set role = 'student', full_name = 'Jefferson Bading',
  student_id = '2024-12345-MN-0', program = 'DCPET'
  where email = 'student1@pup.edu.ph';
```

> **Why this matters:** the admin sign-in itself works, but every admin
> action (approve / reject / return / view all borrowings) checks the
> `is_admin()` SQL helper, which reads `profiles.role`. The default is
> `'student'`, so a freshly-created admin user is actually a student in
> the DB's eyes until you run that `update`. The end-user symptom is
> "the buttons do nothing" — the controller sees the RLS deny as an
> exception and shows a red banner.

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
| `lib/main.dart` | Initializes Supabase, builds a `RepositoryBundle.fromSupabase()`, and provides it to the app via `Provider<RepositoryBundle>.value(...)`. |
| `lib/auth/session/auth_session_storage.dart` | Thin wrapper over Supabase Auth. The login screens still call `saveStudentSession` / `saveAdminSession` — those now do `supabase.auth.signInWithPassword` under the hood. |
| `lib/data/repositories/repository_bundle.dart` | Has both `RepositoryBundle.mock()` (offline demo) and `RepositoryBundle.fromSupabase()` (live DB). `main.dart` wires the Supabase one in by default. |
| `lib/data/repositories/supabase/*.dart` | The four Supabase-backed repositories. |
| `lib/student/student_dashboard_controller.dart` | The single controller used by both shells. Constructor takes a `RepositoryBundle`; `load()` fetches every list (equipment, 4 borrowing buckets, notifications, profile) in parallel via `Future.wait`; CRUD methods (return/approve/reject/markRead/clearAll/...) write to Supabase first and only update local state on success. |
| `lib/screens/shell/student_shell.dart` / `admin_shell.dart` | Read the bundle from the provider tree, hand it to the controller, kick off `load()` on startup, and show a loading spinner / error banner while the first fetch is in flight. |
| `supabase/migrations/0001_initial_schema.sql` | The full DB schema with RLS. Run it once. |
| `supabase/seed_admin_and_demo.sql` | One-shot helper: promotes the admin profile's role, fills in student profile fields, and (optionally) inserts a pending borrowing + notification so the first launch has content to display. |

## What you get out of the box

- **Status-change side effects** — a PostgreSQL trigger on `borrowings`
  fires whenever a row's `status` flips. It (a) auto-inserts a
  `notifications` row for the student so the in-app inbox lights up the
  moment an admin approves/rejects a request, and (b) keeps
  `equipment.available_count` in sync so the home-screen cards don't
  lie about how many items are actually free. SECURITY DEFINER so the
  notification insert bypasses RLS, since it's being fired by the
  admin's update, not the student's session.

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

`lib/main.dart` already builds the Supabase-backed bundle by default. If you want to demo the app without a network round-trip (e.g. on the train, in front of panelists when WiFi is shaky), flip the two lines:

```dart
// default in main.dart — real Supabase backend
late final RepositoryBundle repositoryBundle = RepositoryBundle.fromSupabase();

// offline demo — same in-memory data the original prototype used
// late final RepositoryBundle repositoryBundle = RepositoryBundle.mock();
```

You can keep both, gated by an environment flag, so you can demo either mode
during your defense.

## Production checklist (before going live)

- Enable **email confirmations** in **Authentication → Providers → Email**.
- Set the **Site URL** and allowed redirect URLs for your deployed website and
  mobile deep link; test a confirmation link on a real phone.
- Enable **CAPTCHA protection** and sensible auth rate limits in
  **Authentication → Attack protection**.
- Require **MFA for administrator accounts** in Supabase Auth and keep the
  recovery codes in the equipment office's controlled records.
- Use a strong password policy (12+ characters) in **Authentication → Password
  security**. The app intentionally does not save passwords for “Remember me”.
- Promote an admin only in the SQL Editor or a server-side service using the
  service-role key. Never put the service-role key in this Flutter app.
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
- Review the `borrowing_audit_log` table regularly; it records all request,
  approval, rejection, and return transitions.
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
