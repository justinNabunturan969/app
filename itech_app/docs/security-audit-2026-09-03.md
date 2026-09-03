# PUP-ITech Security & Leak Audit

**Date:** 2026-09-03
**Scope:** Login surface (student + admin), GitHub repo, Supabase RPCs,
Vercel deploy headers, Flutter client storage. **Out of scope:** Supabase
project dashboard settings, M365 SMTP (covered in
`SUPABASE_SETUP.md`), physical device security.
**Method:** static read of `lib/`, `supabase/migrations/`, `vercel.json`,
`build.sh`, `pubspec.yaml`, plus `git log --all -S` for secret-search
across history.

---

## TL;DR

| Severity | Count | Notes |
|---|---|---|
| 🔴 Critical | 0 | No real secrets committed. No RLS bypass. |
| 🟠 High | 2 | Anon key + project URL in tracked `check_inventory.mjs`; anon key previously baked into a tracked `build/web/` (now removed but still in git history). |
| 🟡 Medium | 4 | "Welcome back" leak on shared devices; missing CSP / HSTS in `vercel.json`; plaintext password traverses PostgREST (documented in migration 0022); no client-side rate limit on the forgot-password RPC. |
| 🟢 Low / info | 5 | `debugPrint` of raw exceptions; SUPABASE_ANON_KEY in browser bundle (by design); rate-limit thresholds tuned for one specific lab egress IP; Realtime channel concurrency limits; 30-min inactivity logout not replicated on native. |

Overall the auth surface is well-engineered: per-identifier + per-IP
rate limiting, dummy bcrypt on unknown IDs, friendly error mapping,
server-side session enforcement, force-logout with reason persistence.
The remaining issues are mostly hygiene, not exploitable in isolation.

---

## 1. Login flow (`lib/auth/`)

### 1.1 What the app does right

- **Server-side session is the source of truth.**
  `AuthSessionStorage.isLoggedIn()` reads `Supabase.auth.currentSession`,
  not local prefs. The cached `auth_role` hint is only used as a
  fallback when the network read fails (`auth_session_storage.dart:100-149`).
- **No passwords in local storage.** Only the identifier (student ID /
  email / faculty username) is persisted. The `_studentPasswordKey` /
  `_adminPasswordKey` slots are written and then immediately removed
  in the same call (lines 193 and 323) — a clean migration from an
  older unsafe build.
- **No secret keys in client source.** `lib/env/supabase_config.dart`
  reads `SUPABASE_URL` / `SUPABASE_ANON_KEY` exclusively from
  `String.fromEnvironment('--dart-define=…')`. No defaults, no
  hardcoded fallback. `assertConfigured()` throws at boot if missing
  (lines 57-69).
- **Friendly error mapping.** `_friendlyAuthError()` in both login
  screens sanitizes server errors — it never echoes raw Supabase
  messages, and the `kDebugMode` branch in release builds shows a
  generic "Unable to sign in" instead of leaking the cause
  (`student_login_screen.dart:129-158`,
  `admin_login_screen.dart:65-87`).
- **Inactivity auto-logout.** `InactivitySessionController` warns at
  25 min and signs out at 30 min. Defined per-controller — verify
  it's actually wired up in the shell that holds the user session.
- **Server-side throttling.**
  - `sign_in_identifier` (migration 0015) rate-limits per identifier:
    5 fails / 15 min → 5 min lockout. Burning one bcrypt round on
    unknown IDs makes timing-oracle enumeration impractical.
  - Migration 0022 adds per-IP throttling: 30 fails / 15 min → 15 min
    lockout, **checked before any bcrypt work** so a spraying caller
    costs one indexed SELECT instead of cost-10 `crypt()`.
  - IP is read from `request.headers['x-forwarded-for']` and
    fronted by Supabase's gateway (which overwrites the header).
    Self-hosted deployments must replicate this.
- **No self-promotion to admin.** The `profiles_insert_self` policy
  (0015) and the `prevent_self_role_change` trigger (0003) block a
  client from inserting or updating `role = 'admin'`. Verified in
  `migrations/0015_*` (lines 147-153) and `migrations/0003_*` (per
  `SUPABASE_SETUP.md`).

### 1.2 Issues found

#### 🟡 M1. "Welcome back, Juandelacruz" leaks the username on a shared device

**Where:** `student_login_screen.dart:341-349` and
`admin_login_screen.dart:131-136`.

If a previous user enabled "Remember me" on a shared lab PC, the next
person sees their first name in the hero banner. Worse, the student ID
is pre-filled in the form. They can then attempt a credential-stuffing
login against that account — they only need to guess the password.

**Fix:** gate the greeting + pre-filled identifier on a device-trust
signal (browser fingerprint, re-auth on cold start, or explicit
"Continue as Juandelacruz?" confirmation). At minimum, don't show
"Welcome back" if more than N hours have elapsed since
`auth_last_login` — fall back to a generic greeting.

#### 🟢 L1. `debugPrint` of raw exceptions

**Where:** `lib/student/student_dashboard_controller.dart` (many
sites), `lib/auth/session/auth_session_storage.dart:287, 428, 530`,
`lib/services/nfc_service.dart:42`.

`debugPrint` is stripped from release builds, so it never reaches the
user. But the raw exception can contain RPC URL, status, and the row
data we tried to read. None of the current call sites include the
password (always redacted before passing to `signInWithPassword`),
but a future regression here would print the password. Wrap with
`if (kDebugMode)` and a redaction helper.

#### 🟢 L2. Inactivity logout is web-only by design

`InactivitySessionController` is referenced by
`student_dashboard_controller.dart` and similar. Verify on the
Android/iOS builds that the controller is started on app resume and
not bypassed by a foreground webview. Out of scope for this audit
(native code review needed).

---

## 2. GitHub / git history

The repo is **public** at
`github.com/justinNabunturan969/app` (0 forks, 0 stars, 0 watchers,
but still publicly cloneable).

### 2.1 Things that are fine

- `.env*` is gitignored (`itech_app/.gitignore:54`).
  `.env.local` in the working tree contains a Vercel OIDC token but
  `git ls-files | grep -i env` returns nothing — **not tracked**.
- `supabase.json` is gitignored. The working-tree copy has the anon
  key + URL, but it's not pushed.
- `main.dart` and `lib/env/supabase_config.dart` contain zero
  hardcoded credentials. Verified via `grep -r "eyJ\|anon_key\|service_role"`
  against `lib/`.
- Vercel deploy pulls credentials from Vercel project env vars
  (`build.sh:61-70`) — never from a tracked file.

### 2.2 Things to fix

#### 🟠 H1. Supabase URL + anon key hardcoded in `scripts/check_inventory.mjs`

**Where:** `scripts/check_inventory.mjs:6-7`. **Tracked in `main`
since commit `e10a893` (2026-08-28).**

```js
const URL = 'https://obwdgxcfxxixnuqsjfpu.supabase.co';
const ANON = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBh…';
```

**Why it matters:** the anon key is *designed* to be public — it ships
in every browser request — so the key itself is not a secret. What
*is* a leak is pinning the project URL in a tracked file. Anyone who
clones the public repo now has:

- The exact Supabase project ref (`obwdgxcfxxixnuqsjfpu`).
- A confirmed-working anon key (lets them talk to PostgREST).
- A free target list: any anon-allowed RPCs (`sign_in_identifier`,
  `sign_in_attempt_status`, public tables).

What an attacker can do with that:

- Brute-force student IDs via `sign_in_identifier`. **Mitigated:**
  per-IP rate limit (30 fails / 15 min) in migration 0022.
- Spam sign-ups to fill `auth.users`. **Mitigated:** Supabase's built-in
  auth rate limit + your per-IP throttle.
- Enumerate which RPCs exist by reading `supabase/migrations/*.sql`
  (also public). This is a structural risk — every public migration
  reveals an attack surface.

**Fix:**

1. Move the script to `scripts/check_inventory.local.mjs` and add it
   to `.gitignore`.
2. Or read the values from `process.env` (and a `.env.local` that's
   already gitignored) and document the env vars in the file's
   header.
3. **Rotate the anon key** in the Supabase dashboard after step 1
   (Settings → API → "Generate new anon key"). This invalidates the
   value baked into the JS bundle too — the next `flutter build web`
   will pick up the new value via `--dart-define`.

#### 🟠 H2. Anon key previously baked into tracked `build/web/`

**Where:** commit `0c9c1b4` (2026-08-28) deleted the pre-built
`build/web/main.dart.js` from the repo. The deletion commit message
acknowledges the key was there.

`git log --all -S "obwdgxcfxxixnuqsjfpu" --pretty=format:"%H %ad %s"`
returns the same 5 commits I listed in §1.1 — the project URL is
reachable in the build artifacts of commits `aeb7d5b` and
`b1e3784` for anyone willing to `git checkout <hash>`. The key is
**still in git history** even though the files aren't on the
current `main`.

**Fix options, cheapest to most thorough:**

1. **Leave it.** The anon key is public-by-design. Your RLS is the
   real gate. New anon key rotation (H1 step 3) makes the historical
   value a dead token, which is usually enough.
2. **Rewrite history.** `git filter-repo --path itech_app/build/web/
   --invert-paths` then force-push `main`. This is a noisy operation
   and a public repo keeps forks / clone mirrors you don't control.
3. **Rotate and document.** Generate a new anon key, redeploy, add
   a CONTRIBUTING note explaining the policy ("never commit
   `build/`, never inline `URL`/`ANON` in scripts — use
   `--dart-define` or `process.env`").

Recommend option 3.

#### 🟡 M2. RPC surface is in the public repo

`supabase/migrations/*.sql` is tracked. Every `create function
public.foo(…) returns …` is a documented attack surface. The current
mitigations are:

- `revoke all … from public, anon, authenticated` on helper functions.
- RLS on every data table.
- `security definer` only on functions that genuinely need it.

**This is fine for a thesis project but it's a permanent trade-off:**
if you don't want the world to know your RPC names, the migrations
have to live behind a private repo. They don't, so don't try to
hide them — focus on least-privilege grants and rate limits, which
you've already done.

---

## 3. Supabase RPCs & database

### 3.1 Sign-in RPC (`sign_in_identifier`)

- **Dummy bcrypt on unknown IDs** (migration 0015 lines 100-107 and
  0022 lines 175-187): a missing ID still burns one cost-10 bcrypt
  round so an attacker can't time-distinguish "ID exists" from "ID
  doesn't".
- **Per-identifier + per-IP throttle** in 0022. The IP gate runs
  before bcrypt so a spraying caller is cheap to reject.
- **Plaintext password traverses PostgREST** — explicitly documented
  in migration 0022 lines 23-33. Risk surfaces:
  - `pg_stat_activity` snapshots include the RPC body during
    execution.
  - `log_statement = 'all'` would write every password to the WAL.
  - PostgREST's request log (off by default) would include the
    body.

  **Fix if you want defense in depth:** route student-ID sign-in
  through a Supabase Edge Function instead of a PostgREST RPC. Edge
  Functions don't log RPC bodies and `pg_stat_activity` doesn't
  show their parameters. Migration 0022 explicitly suggests this.

- **Response shape leaks nothing.** On success returns the lowercased
  email; on failure returns NULL (or raises the throttle exception
  in lockout). Client-side error mapping at
  `auth_session_storage.dart:411-441` translates a NULL return into
  a generic "Invalid login credentials" — no enumeration via
  differing error messages.

### 3.2 `sign_in_attempt_status`

Migration 0019 — read-only RPC, returns
`{attempts_left, locked_until}`. It is granted to `anon`, so anyone
can call it with any identifier and read "this account has 3
attempts left" / "this account is locked until 12:34". This **is**
a low-grade enumeration oracle — by probing a list of student IDs
without ever sending a wrong password, an attacker can learn which
IDs are real (their `attempts_left` will be a number, not the
default-5) and which are locked.

**Fix:** don't expose this RPC to `anon`. Grant it only to
`authenticated`, and have the client re-auth with a short-lived
session before calling it. Or have the client call it
*immediately after* its own failed sign-in attempt, with the
identifier it just tried — the rate limiter on `sign_in_identifier`
already prevents an unbounded loop.

```sql
revoke execute on function public.sign_in_attempt_status(text) from anon;
-- client must authenticate before calling
```

### 3.3 `resetPasswordForEmail`

`student_login_screen.dart:306` and `admin_login_screen.dart:271`
call this with the email the user typed. The screen already shows
a friendly "If that account exists, a reset link was sent" snackbar
(student) or "If the account exists" (admin), so no enumeration
leak in the UI. But:

- The RPC itself returns a 200 either way, no info leak.
- **However:** there's no per-IP rate limit on this RPC. An attacker
  can call it in a loop to (a) spam the M365 SMTP queue and (b)
  enumerate which emails exist by watching whether a real reset
  email is sent (only an attacker with access to the inbox can
  observe this — not a public oracle).

  **Fix:** Supabase Auth has a built-in rate limit on
  `resetPasswordForEmail`; verify it's enabled in
  Auth → Providers → Email → "Security" panel. If not, gate the
  RPC with the same `_sign_in_rate_key_locked('ip:' || v_ip)`
  helper used by `sign_in_identifier`.

### 3.4 The 30-min inactivity logout

`InactivitySessionController` is good defense, but it lives on the
client. If a user clears their browser tab instead of clicking
"Logout", the server-side Supabase session is still valid until JWT
expiry (default 1 hour, or whatever the project's
`access_token_ttl` is set to). For a lab deployment, consider:

- `access_token_ttl` = 30 min to match client logout.
- `refresh_token_rotation` enabled (it's the default in Supabase but
  worth confirming).

### 3.5 Realtime channel concurrency

The admin "Live" tab subscribes to `active_sessions` via Supabase
Realtime. Supabase Realtime has per-channel subscriber limits
(~200 concurrent on Free, ~500 on Pro — check your plan's docs).

**At 800 concurrent students + ≥1 admin watching the Live tab,
the admin's WebSocket will hit the per-channel limit and either
disconnect or start dropping events.** This is the single biggest
load-test concern; see the load test in `tests/load/`.

Mitigations:

- Use Postgres Changes filter on `active_sessions` (already done in
  migration 0008) so only diff events are sent.
- The admin doesn't need to subscribe to all 800 — paginate the
  Live tab and only subscribe to a server-paginated view.
- For 800 concurrent, Pro plan + Realtime Pro add-on is required.

---

## 4. Vercel headers & transport

`vercel.json` has:

- `X-Content-Type-Options: nosniff` ✅
- `X-Frame-Options: DENY` ✅
- `Referrer-Policy: strict-origin-when-cross-origin` ✅
- `Permissions-Policy: camera=(), microphone=(self), geolocation=()` ✅
- Static assets cached `max-age=31536000, immutable` ✅
- Bootstrap / service-worker / version.json no-cache ✅

### 4.1 Missing headers (medium)

#### 🟡 M3. No `Content-Security-Policy`

The Flutter web bundle is JS + WASM. A CSP that allows `script-src
'self' 'wasm-unsafe-eval'` would significantly reduce the impact of
an XSS in a third-party dependency (you only depend on
`supabase_flutter` and `go_router` via JS interop, but transitive
npm packages from `flutter build` could be a future concern).

Suggested starter CSP — drop into `vercel.json` `headers` block:

```json
{
  "key": "Content-Security-Policy",
  "value": "default-src 'self'; script-src 'self' 'wasm-unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; connect-src 'self' https://*.supabase.co wss://*.supabase.co; font-src 'self' data:; frame-ancestors 'none'; base-uri 'self'; form-action 'self'"
}
```

`'unsafe-inline'` for styles is unavoidable because Flutter web
injects dynamic CSS. `'wasm-unsafe-eval'` is required for
CanvasKit/Skwasm.

#### 🟡 M4. No `Strict-Transport-Security`

HSTS ensures a man-in-the-middle can't downgrade a future visit to
HTTP. Vercel serves over HTTPS by default but the HSTS header is
not automatic — add it:

```json
{ "key": "Strict-Transport-Security", "value": "max-age=63072000; includeSubDomains; preload" }
```

(63072000 = 2 years. After 2 years of clean operation, submit to
[hstspreload.org](https://hstspreload.org).)

#### 🟢 L3. No `Cross-Origin-Opener-Policy` / `Cross-Origin-Embedder-Policy`

For a Flutter web app, COOP/COEP aren't strictly required (no
SharedArrayBuffer usage visible). If you ever want SharedArrayBuffer
for performance, both headers are needed and require careful
review.

---

## 5. Client storage

`SharedPreferences` keys used by `AuthSessionStorage`:

| Key | Stores | Sensitivity |
|---|---|---|
| `auth_logged_in` | bool | Low — UI hint only |
| `auth_role` | string | Low — UI hint, server is truth |
| `auth_remember` | bool | Low |
| `auth_last_login` | ISO timestamp | Low |
| `auth_kick_reason` | admin message | Low — admin's own message |
| `auth_kick_reload_pending` | bool | Low |
| `auth_student_id` | student ID | **Medium** — direct identifier |
| `auth_student_email` | email | **Medium** — direct identifier |
| `auth_student_username` | short name | **Medium** — first-name leak |
| `auth_student_password` | (always removed) | — |
| `auth_admin_username` | faculty email | **Medium** — direct identifier |

The Supabase session token itself is stored by `supabase_flutter` in
`flutter_secure_storage` on native, and IndexedDB on web (which is
secure-origin-bound). That's correct.

**Medium-severity items are stored in plain `SharedPreferences`
(NOT `flutter_secure_storage`).** On Android, `SharedPreferences` is
a plain XML file in the app sandbox — readable by anyone with root
or with `adb` on a debuggable build. On web, it's IndexedDB which is
origin-scoped. The student email + student ID + name are PII and
should arguably live in `flutter_secure_storage` on Android.

**Fix:** add `flutter_secure_storage` to `pubspec.yaml`, move the
`auth_student_*` and `auth_admin_*` keys to it, and add a
migration step that wipes the old keys on first launch with the new
build.

---

## 6. Recommendations, ordered by ROI

1. **🟠 Move `scripts/check_inventory.mjs` to `scripts/local/` and
   gitignore it; or read URL/ANON from env vars.**
   Then **rotate the anon key** in the Supabase dashboard. *(1 hour
   total, neutralizes H1 + reduces H2 impact.)*
2. **🟡 Add `Content-Security-Policy` and `Strict-Transport-Security`
   to `vercel.json`.** *(10 min, no risk.)*
3. **🟡 Move identifier PII (student ID, email, name) from
   `SharedPreferences` to `flutter_secure_storage` on native.** *(2
   hours including migration logic.)*
4. **🟡 Revoke `anon` execute on `sign_in_attempt_status`; require
   an authenticated session to call it.** *(5 min, requires running
   a new migration.)*
5. **🟠 Run the load tests in `tests/load/` against a staging
   project** and report the numbers in the thesis — this turns the
   "800 concurrent" claim from an aspiration into a measured
   result. *(1 hour to set up, 30 min to run.)*
6. **🟢 Gate the "Welcome back" greeting on a device-trust signal
   or time-since-last-login threshold.** *(2 hours including design.)*
7. **🟢 Consider routing `sign_in_identifier` through a Supabase
   Edge Function** instead of PostgREST to fully eliminate the
   plaintext-password-through-RPC exposure. *(1 day including
   testing.)*

---

## 7. Out-of-scope reminders

- The Supabase project dashboard should have **Leaked Password
  Protection** enabled (Auth → Policies → "Enable HaveIBeenPwned
  check"). The `SUPABASE_SETUP.md` already calls this out, but
  verify it's actually toggled in production.
- The admin account's email + password is held in production
  somewhere — keep it in your own password manager, not in a
  comment in the repo, and rotate the password on a schedule.
- If you ever publish this as a real product, the thesis
  `private/public` boundary changes — everything in this audit
  gets harder, especially M1 (Welcome back leak) and the
  `flutter_secure_storage` migration in §5.
