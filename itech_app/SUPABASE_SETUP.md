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

If you had already run `0001_initial_schema.sql` before later features were
added, run the remaining migrations in order in the SQL Editor:

| Migration | What it adds |
|---|---|
| `0002_live_notifications_and_return_requests.sql` | Upgrades the notification trigger (admin return-request alerts). |
| `0003_security_hardening_and_audit.sql` | **Required.** Protects profile roles, moves borrowing actions into secure RPCs, prevents duplicate open requests, adds the admin audit log. |
| `0004_return_existing_open_borrowing.sql` | Makes repeated request taps safe (returns the existing open request instead of erroring). |
| `0005_borrowing_quantities.sql` | **Required.** Adds `quantity` support and replaces `request_borrowing` / `transition_borrowing`. |
| `0006_live_session_lifecycle.sql` | Session lease lifecycle + `session_history` audit table. |
| `0007_active_session_upsert.sql` | Keeps `logged_in_at` stable across heartbeats; allows session resurrection. |
| `0008_active_sessions_realtime.sql` | Puts `active_sessions` on the realtime publication for the admin Live tab. |
| `0009_loosen_session_expire.sql` | Widens the stale-session sweep from 2 to 5 minutes. |
| `0010_student_session_history_rls.sql` | No-op tombstone (student self-read intentionally not granted). |
| `0011_production_security_and_api_grants.sql` | **Required.** Explicit Data API grants, profile identity protection, revokes the student-ID→email lookup helper. |
| `0012_drop_dead_functions_and_finish_grants.sql` | Drops unused functions (`touch_active_session`, `auth_email_for_student_id`) and finishes RPC grant hardening. |
| `0013_session_kick_cooldown.sql` | Prevents a force-logged-out user's heartbeat from resurrecting their `active_sessions` row. |

A fresh project only needs `0001_initial_schema.sql` followed by
`0003`, `0005`, `0011`, `0012`, and `0013`; running every file in order is
also safe — they are idempotent.

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

## 4. Disable email confirmation

The in-app sign-up flow expects to sign the student straight in after
registration (that is the product behavior). Supabase ships with
"Confirm email" **enabled** by default, which blocks new accounts from
logging in until they click a link in their inbox:

1. Dashboard → **Authentication** → **Sign In / Providers** → **Email**
   (older dashboards: **Authentication → Providers → Email**).
2. Turn **OFF** the **"Confirm email"** toggle → **Save**.

New sign-ups now get a session immediately. Accounts that were created
while the toggle was still on are stuck in the "unconfirmed" state —
un-stick them with:

```sql
-- Mark every pending account as confirmed so they can sign in.
update auth.users
   set email_confirmed_at = coalesce(email_confirmed_at, now()),
       updated_at = now()
 where email_confirmed_at is null;
```

> For the production-hardening checklist later, see step 8 — turning
> confirmations back on is listed there together with the redirect-URL
> work it requires.

## 5. Create your first user

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

## 6. Seed some equipment (optional, for the demo)

```sql
insert into public.equipment (code, name, category, location, total_count, available_count, description) values
  ('E-9020', 'Fluke 87V Digital Multimeter', 'Test Equipment', 'Room 301 - Electronics Lab', 3, 3, 'True RMS industrial multimeter.'),
  ('E-10001', 'Stanley 12-Piece Screwdriver Set', 'Hand Tools', 'Room 205 - Tool Room', 5, 5, 'Slotted, Phillips, and Torx.'),
  ('E-8008', 'Heat Gun (2 Modes)', 'Soldering', 'Room 205 - Tool Room', 2, 2, 'For heat-shrink tubing and SMD rework.'),
  ('E-5222', 'DC Power Supply 0-30V / 0-5A', 'Bench Supplies', 'Room 210 - Bench Supplies', 4, 4, 'Variable regulated bench supply.'),
  ('E-3141', 'Arduino Uno R3 Kit', 'Microcontrollers', 'Room 312 - Embedded Lab', 10, 10, 'ATmega328P, USB-B cable included.');
```

## 7. Run the app with your credentials

From the project root:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi...
```

For VS Code: open `.vscode/launch.json` (or create it) and add the
`--dart-define` flags under `args` for the `flutter` configuration.

For Android Studio: **Run → Edit Configurations → Flutter → Additional args**.

Credentials are **never committed to source**. The git-ignored
`supabase.json` in the project root is loaded automatically by `run.ps1`
and `.vscode/launch.json` via `--dart-define-from-file`. Create it once:

```json
{
  "SUPABASE_URL": "https://YOUR_PROJECT.supabase.co",
  "SUPABASE_ANON_KEY": "eyJhbGciOi..."
}
```

For web deploys (Vercel), set `SUPABASE_URL` and `SUPABASE_ANON_KEY` as
environment variables in the Vercel project settings — `build.sh` forwards
them to the compiler.

If the flags are missing, the app shows a clear in-app "configuration
required" screen instead of silently talking to the wrong project.

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
- In **Authentication → URL Configuration**, add these redirect URLs before
  using password recovery:
  - `https://YOUR-DEPLOYMENT/reset-password` (or
    `https://YOUR-DEPLOYMENT/**` for Vercel preview deployments)
  - `pupitech://auth/reset-password` for Android/iOS builds.
  The app sends the user to its `/reset-password` screen after they click the
  email link, where they can choose a new password.
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
| New sign-up can't log in — "email not confirmed" | **Confirm email** is still ON. Turn it off (**Authentication → Sign In / Providers → Email**, see step 4) and un-stick existing accounts with the `update auth.users set email_confirmed_at ...` snippet from that section. |
| `permission denied for table profiles` | RLS is blocking the read. Make sure you ran the migration script — it creates the policies. |
| Equipment list is empty | You haven't seeded the `equipment` table yet. See step 5. |
| `Project has been paused` | Free-tier projects pause after 7 days of inactivity. Open the dashboard once a week to keep it alive. |
| `WebSocket failed to connect` | On a real device, make sure you use the **`https://`** URL, not `http://`. For local dev on the emulator, `127.0.0.1` doesn't work — use your machine's LAN IP or the `https://` project URL. |
