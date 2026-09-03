# PUP-ITech Load Tests

> **Prerequisite:** read `docs/security-audit-2026-09-03.md` first.
> The load tests measure the same surface the audit covers, and the
> audit's recommendations tell you which thresholds to look at.

This folder contains [k6](https://k6.io) scripts that answer one
question the thesis needs to answer:

> *"Can the PUP-ITech system handle 800 concurrent students at a
> typical class-start spike?"*

Three scenarios cover the three places 800 users actually stress the
system:

| # | Scenario | What it stresses | Where to look in the audit |
|---|---|---|---|
| 01 | `login-burst` | 800 concurrent POSTs to `/auth/v1/token` | §3.1, §3.3 |
| 02 | `realtime-live-tab` | 800 concurrent Realtime WebSockets + 1 admin subscriber + 1 login driver | §3.5 |
| 03 | `rpc-under-load` | 400 VUs spraying `sign_in_identifier` + 400 VUs reading equipment/borrowings, plus an optional "legit user blocked by shared-IP throttle" assertion | §3.1, §3.2 |

---

## Setup (one time)

```powershell
# 1. Install k6
winget install k6 --source winget

# 2. Fill in credentials
cd tests\load
copy .env.example .env
notepad .env       # paste your SUPABASE_URL and SUPABASE_ANON_KEY
```

The `.env` file is gitignored. The `SUPABASE_ANON_KEY` is the same
public key that ships in your web bundle — it's safe to put in a
local file but never commit it.

**Scenario 02** also needs a *dedicated* test student account. Use
something like `loadtest+driver@pup.edu.ph` and a strong password —
**do not** use a real student's account. The test signs them in
~15 times per scenario to generate `active_sessions` events.

---

## Running the tests

```powershell
# One scenario at a time (recommended first run):
.\tests\load\run-load-tests.ps1 -Scenario 1

# Realtime test (needs STUDENT_EMAIL/PASSWORD in .env):
.\tests\load\run-load-tests.ps1 -Scenario 2

# RPC + rate-limit test (needs LEGIT_EMAIL/PASSWORD for the optional assertion):
.\tests\load\run-load-tests.ps1 -Scenario 3

# All three, with the per-IP rate-limit cooldown respected:
.\tests\load\run-load-tests.ps1 -Scenario all
```

The runner writes a JSON summary per scenario to
`tests/load/results/<timestamp>/<scenario>-summary.json`. These JSON
files are what you import into the thesis appendix.

---

## What "passing" means

| Scenario | Threshold | What it proves |
|---|---|---|
| 01 | p95 latency < 1500 ms, < 1% throttled | The 800-class-start spike fits the configured Supabase tier without users hitting the per-IP lockout. |
| 02 | 95% of WebSockets connect within 10 s, 0 admin event drops | Realtime channel concurrency matches the Supabase plan tier. If this fails on Pro, you need the Realtime Pro add-on. |
| 03a (spray) | At least one 429 within 90 s | The per-IP rate limiter (migration 0022) actually fires under attack. |
| 03b (reads) | p95 < 500 ms on `/equipment` and `/borrowings` | The RLS-gated read path holds up. If this fails, you need more PgBouncer pool size or a read replica. |
| 03c (legit blocked) | The legit user is throttled | The throttle correctly applies to the whole egress IP, not just the attacker — *not a bug, a feature* — and the test documents the trade-off. |

If a threshold fails, **don't raise the threshold**. Either:

1. Upgrade the Supabase plan tier.
2. Or apply the mitigation referenced in the audit (e.g. edge
   function routing for plaintext password, Realtime pagination for
   the Live tab, etc.).

---

## Why k6 and not JMeter / Locust / Artillery?

- **k6 is single-binary and Go-native.** 800 VUs from one
  `run-load-tests.ps1` invocation, no warm-up time, no Java heap
  tuning. Plays well with PowerShell on Windows.
- **Thresholds-as-code** in the same JS file as the test. No
  separate "Pass/Fail Criteria" spreadsheet that drifts from the
  script.
- **Realtime WebSocket support** is first-class — `k6/ws` and the
  `phx_join` payload format are exactly what scenario 02 needs.
- **JSON summary export** is one flag. Drop into the thesis
  appendix verbatim.

---

## Cost & safety notes

- **Each scenario uses real Supabase infrastructure.** A 90-second
  password spray from 400 VUs will cost real bcrypt CPU time on your
  Postgres instance. Run these against a **staging project**, not
  production. The free tier will rate-limit the VUs before they can
  measure anything useful.
- The `sign_in_identifier` calls in scenario 03a will **lock the
  source IP for 15 minutes** (per migration 0022). If you re-run
  scenario 03 immediately, all calls will return 429 from the start.
  Wait 15 minutes, or use a different egress IP (VPN).
- The login driver in scenario 02 signs the test student in ~15
  times. Supabase's per-user rate limit is much higher than this
  (GoTrue default: 30 sign-ins per 5 min per email), so it won't
  throttle, but the active_sessions table will accumulate rows.
  Migration 0009 (loosen_session_expire) sweeps them after 5 min of
  inactivity, so the table returns to a clean state within minutes
  of the test ending.

---

## Files

```
tests/load/
├── .env.example              ← template; copy to .env
├── .gitignore                ← .env and results/ are local-only
├── README.md                 ← this file
├── run-load-tests.ps1        ← PowerShell runner
└── scenarios/
    ├── 01-login-burst.js     ← 800 concurrent sign-ins
    ├── 02-realtime-live-tab.js ← 800 concurrent WebSockets + admin sub
    └── 03-rpc-under-load.js  ← spray + reads + legit-blocked assertion
```
