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
| `0013_session_kick_cooldown.sql` | **Required.** Prevents a force-logged-out user's heartbeat from resurrecting their `active_sessions` row. |
| `0014_return_verification_flow.sql` | Return verification flow. |
| `0015_student_id_login_and_profile_bootstrap.sql` | **Required.** Student-ID sign-in RPC (`sign_in_identifier`) + profile bootstrap. |
| `0016_user_deletion_inventory_restore.sql` | Restores equipment inventory when a user account is deleted. |
| `0017_force_logout_notice.sql` | **Required for forced logouts.** Adds `force_logout_notices` + the one-shot `consume_force_logout_notice()` RPC. The kicked device calls it to show the admin's reason on the login screen — without it every kick shows only the generic "Your session was ended by an administrator." wording and detection falls back to realtime events alone. |
| `0018_student_id_login_resilience.sql` | Resilience fixes for student-ID sign-in. |
| `0019_sign_in_attempt_feedback.sql` | Read-only `sign_in_attempt_status()` RPC so the student login screen can show "attempts left" after a wrong password and a live countdown while the account is locked out. |
| `0020_scheduled_maintenance.sql` | **Required.** pg_cron jobs: flips past-due borrowings to `overdue` (+ notification) and sweeps stale sessions into `session_history` every minute — no longer dependent on an admin being online. |
| `0021_kick_cooldown_hardening.sql` | **Security fix.** A kicked client can no longer overwrite its `force_logout` session-end cooldown with a self-reported `'closed'`, which defeated the 60-second resurrection guard. |
| `0022_sign_in_ip_throttle.sql` | **Hardening.** Per-IP sign-in throttling (30 failures / 15 min → 15 min lockout) checked *before* bcrypt work — stops password spraying across identifiers and cheap CPU DoS. Also documents the plaintext-password-through-RPC risk. |
| `0023_rls_initplan_hardening.sql` | **Perf.** Rewrites pre-0011 RLS policies to `(select auth.uid())` / `(select public.is_admin())` so auth checks are cached per statement instead of evaluated per row. |
| `0024_cancel_pending_request.sql` | Students can withdraw their own still-`pending` request via `transition_borrowing(id, 'cancel')`. Frees the one-open-request-per-item slot immediately (new terminal `'cancelled'` status). |
| `0025_equipment_status_derivation.sql` | `equipment.status` availability classes are derived from `available_count` by a trigger (one-time drift backfill included); `maintenance`/`retired` stay manual. |
| `0026_drop_dead_nfc_uid.sql` | Drops the never-used `profiles.nfc_uid` column (planned NFC feature never shipped). |
| `0027_data_retention.sql` | Daily pg_cron pruning job: sign_in_rate_limit (30d), session_end_cooldown (1d), session_history (120d), borrowing_audit_log (365d). |
| `0028_loan_period_setting.sql` | `app_settings` table + `_loan_period()` helper — the 3-day loan period is now a configurable setting (`loan_period_days`, admin-editable). |
| `0029_enriched_borrowing_rpcs.sql` | `request_borrowing` / `transition_borrowing` return enriched jsonb (equipment + student embedded) so the app no longer re-fetches by id after every action. Backwards compatible with older clients. |
| `0030_favorites.sql` | Real favorites: `favorites(profile_id, equipment_id)` with own-rows-only RLS; the heart button persists and survives reloads. |

## Managing migrations (CLI workflow)

These files are plain SQL intended to be applied in order. To avoid
hand-running scripts in the SQL editor (which invites drift between
environments), prefer the Supabase CLI:

```bash
supabase link --project-ref <your-project-ref>
supabase db push          # applies any unapplied files under supabase/migrations/
supabase db pull          # optional: reconcile hotfixes made in the dashboard
```

`supabase db push` tracks what has been applied per environment, so the
"several migrations re-declare full function bodies" pattern stays safe.

## Security & auth policy notes

**Password policy.** The client requires 8+ characters with at least one
capital letter, at least one special character, and at least three digits
for NEW passwords (`AuthValidators.validateNewPassword`,
used on sign-up and reset); login still accepts legacy 6-character accounts.

**Admin account recovery.** Users can never self-create an admin role:
`profiles.role` defaults to `student`, the `profiles_insert_self` policy
(migration 0015) only accepts `role = 'student'`, and the
`prevent_self_role_change` trigger (migration 0003) blocks self-promotion.
Admin promotion happens exclusively via SQL run as `postgres` (SQL Editor /
migration). If the admin auth user is accidentally deleted (the profile row
cascades with it), recover as follows:

1. Dashboard → Authentication → Users → Add user — same admin email, strong
   password, Auto Confirm User enabled.
2. SQL Editor:
   ```sql
   insert into public.profiles (id, email, role)
   select u.id, u.email, 'admin'
   from auth.users u
   where lower(u.email) = 'admin@pup.edu.ph'
   on conflict (id) do update set role = 'admin';
   ```
   (`on conflict` upgrades the row to admin if the app's bootstrap already
   recreated it as a student.) Re-running `seed_admin_and_demo.sql` alone is
   NOT enough after a deletion — it only UPDATEs existing rows.
3. Verify: `select email, role from public.profiles where role = 'admin';`

Keep TWO admin accounts so a single deletion never locks admin workflows,
and keep both emails in the allow-list in `seed_admin_and_demo.sql`.
Also enable **Leaked password protection** server-side:
*Dashboard → Authentication → Policies → Leaked password protection.*

## Security notes

**Student-ID sign-in password handling (migration 0018/0022).** Resolving a
bare student number to an auth email requires proving the password inside the
database, so the plaintext password traverses a PostgREST RPC
(`sign_in_identifier`) in addition to GoTrue. It is TLS-protected in transit
and never persisted, but it can surface in `pg_stat_activity` snapshots and in
statement logs if verbose logging (`log_statement = 'all'`) is enabled — keep
that setting off or exclude this RPC. Fully removing the exposure means moving
verification solely into GoTrue (Edge Function + captcha), at the cost of
re-enabling student-ID enumeration.


A fresh project needs `0001_initial_schema.sql` followed by
`0003`, `0005`, `0011`, `0012`, `0013`, `0015`, and `0017` at minimum;
running every file in order is also safe — they are idempotent.

### Forced-logout behavior (admin → user device)

When an admin force-logs a user out from Login History / Live:

1. The user's device detects the kick (realtime presence event or the
   30-second heartbeat checking the persisted notice), consumes the
   admin's reason while its token still works, persists it locally,
   signs itself out, and **reloads the app**.
2. The reload plays the same launch animation as a first start
   (wrench rises, glides left, types the app name).
3. The fresh boot then lands on the student login screen showing the
   exact reason the admin entered.

If the message shown is always the generic fallback wording, migration
`0017_force_logout_notice.sql` has not been applied to that database.

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

## Password recovery email (custom SMTP)

The forgot-password flow is fully implemented in the app: the login screens
call `resetPasswordForEmail(...)` (`student_login_screen.dart`,
`admin_login_screen.dart`), the email link lands on `/reset-password`, and
`reset_password_screen.dart` sets the new password on the recovery session.
If a student taps "Send reset link" and nothing arrives, **the code is not
the problem — Supabase's email delivery is.**

### Why the built-in mailer fails

- With no custom SMTP configured, Supabase sends auth mail through its
  shared built-in mailer, which is throttled to only a few emails per hour
  on the free plan.
- It sends from a generic Supabase address. Institutional Microsoft 365 /
  Outlook tenants (every `@pup.edu.ph` mailbox) commonly quarantine or
  silently drop mail from unknown bulk senders, so the message counts as
  "sent" in Supabase but never reaches the inbox.

### Redirect URLs (already configured — keep in sync)

The app passes `redirectTo` = `<deployed origin>/reset-password` on web
(`SupabaseConfig.passwordResetRedirectUrl`) and `pupitech://auth/reset-password`
on native. These must stay listed under **Authentication → URL Configuration
→ Redirect URLs**. Currently whitelisted:

- `https://bisaya-vert.vercel.app/reset-password`
- `https://bisaya-vert.vercel.app/`
- the `https://bisaya-*-…vercel.app/**` preview-deployment patterns

If the production domain ever changes, add the new `/reset-password` URL here
or reset requests will be rejected.

### Turn on custom SMTP

**Project Settings** (gear, bottom-left) → **Auth** → **SMTP Settings** →
enable **Custom SMTP**, then fill in sender email, sender name, host, port,
username, and password. Two options:

- **Option A — a transactional provider (works today, no PUP IT needed).**
  Use Resend, SendGrid, Postmark, or AWS SES. Create an account, verify your
  sending domain, and copy its SMTP credentials in. These deliver reliably
  to `@pup.edu.ph` inboxes and are not subject to Supabase's shared-mailer
  throttle.
- **Option B — PUP Microsoft 365 / Exchange Online (on-brand, needs PUP IT).**
  Relay through PUP's own mail so recovery email comes from a real
  `no-reply@pup.edu.ph` mailbox: host `smtp.office365.com`, port `587`
  (STARTTLS). The mailbox must have **SMTP AUTH (authenticated SMTP) enabled**
  in the Microsoft 365 admin center — Microsoft leaves it off by default — and
  you should use an app password / modern-auth SMTP credential, never a
  person's interactive password. The ask for PUP IT is therefore: *"enable
  SMTP AUTH on a dedicated no-reply mailbox and issue SMTP credentials for
  it."* This is the same admin dependency as Microsoft SSO.

### Verify it works

- Re-send a reset link and check the inbox **and** the junk folder the first
  time.
- **Authentication → Audit Logs** shows each recovery attempt and its
  outcome; **Authentication → Rate Limits** shows whether repeated testing
  has throttled you.
- **Authentication → Emails** holds the "Reset password" template if you
  want to brand the message.

---

## Quick troubleshooting

| Symptom | Fix |
|---|---|
| `StateError: Supabase is not configured` at startup | You forgot the `--dart-define` flags. Add them to your run command. |
| Login fails with `Invalid login credentials` | The user doesn't exist in `auth.users` yet. Create them in **Authentication → Users** in the dashboard. |
| New sign-up can't log in — "email not confirmed" | **Confirm email** is still ON. Turn it off (**Authentication → Sign In / Providers → Email**, see step 4) and un-stick existing accounts with the `update auth.users set email_confirmed_at ...` snippet from that section. |
| Reset link "sent" but never arrives in a `@pup.edu.ph` inbox | Custom SMTP is not configured, so Supabase's throttled generic mailer is being blocked/quarantined by Microsoft 365. Enable **Custom SMTP** (Project Settings → Auth → SMTP Settings) — see the "Password recovery email (custom SMTP)" section. Also check junk folder, **Authentication → Rate Limits**, and that the address typed matches the account's email exactly. |
| `permission denied for table profiles` | RLS is blocking the read. Make sure you ran the migration script — it creates the policies. |
| Equipment list is empty | You haven't seeded the `equipment` table yet. See step 5. |
| `Project has been paused` | Free-tier projects pause after 7 days of inactivity. Open the dashboard once a week to keep it alive. |
| `WebSocket failed to connect` | On a real device, make sure you use the **`https://`** URL, not `http://`. For local dev on the emulator, `127.0.0.1` doesn't work — use your machine's LAN IP or the `https://` project URL. |
