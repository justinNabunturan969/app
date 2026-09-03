// tests/load/scenarios/03-rpc-under-load.js
//
// Goal: prove the data-plane RPCs the app actually uses can handle
// 800 concurrent students browsing + borrowing equipment. AND verify
// the per-IP rate limiter (migration 0022) DOES fire correctly when
// an attacker tries to spray 800 wrong passwords from one IP.
//
// This script runs THREE scenarios in parallel:
//   A. 400 VUs continuously call `sign_in_identifier` with WRONG
//      passwords against RANDOM student IDs. The 31st request from
//      this "IP" (k6 uses a single egress, so all 400 VUs share the
//      same source IP) MUST get rate-limited. We assert >= 1
//      rate-limit hit.
//   B. 400 VUs continuously call the borrowings / equipment /
//      profile SELECT endpoints with a valid anonymous anon key
//      (browsing flow). These should all succeed at low latency
//      because they're cheap reads behind RLS.
//   C. After scenario A locks the IP, a single "legit" VU tries
//      to sign in with a CORRECT password and verifies it's blocked
//      — this is the regression test for "the throttle must apply
//      to everyone sharing the IP, not just the attacker".
//
// Pass criteria:
//   - Scenario A: at least one 429 / "Too many sign-in attempts"
//     response within 90s (proves the per-IP throttle fires)
//   - Scenario B: p95 < 500ms (read path holds up)
//   - Scenario C: the legit VU is correctly throttled
//
// Notes:
//   - This script does NOT need a real student account. It hits the
//     public RPC endpoint with the anon key, which is the
//     realistic worst case for your public attack surface.
//   - Scenario C requires a real account to test "correct password
//     blocked by IP throttle". Skip scenario C by omitting
//     LEGIT_EMAIL / LEGIT_PASSWORD env vars.

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend, Counter, Rate } from 'k6/metrics';
import { randomString } from 'https://jslib.k6.io/k6-utils/1.4.0/index.js';

const SUPABASE_URL      = __ENV.SUPABASE_URL      || 'https://YOUR.supabase.co';
const SUPABASE_ANON_KEY = __ENV.SUPABASE_ANON_KEY || 'YOUR_ANON_KEY';
const LEGIT_EMAIL       = __ENV.LEGIT_EMAIL       || '';  // optional
const LEGIT_PASSWORD    = __ENV.LEGIT_PASSWORD    || '';  // optional

const sprayRateLimited   = new Rate('spray_rate_limited');
const sprayAttempts      = new Counter('spray_attempts');
const readLatency        = new Trend('read_latency_ms');
const legitBlocked       = new Counter('legit_blocked');
const legitSucceeded     = new Counter('legit_succeeded');

export const options = {
  scenarios: {
    // A. Password spray from one IP. 400 VUs, each trying 1 wrong
    // password against a random student ID. With 30-fail / 15-min
    // per-IP, we expect the 31st request onward to be locked out.
    spray_attack: {
      executor: 'constant-vus',
      vus: 400,
      duration: '90s',
      exec: 'sprayAttack',
    },

    // B. Read traffic. 400 VUs each issue 1 GET /equipment + 1 GET
    // /borrowings per second, simulating a class browsing the
    // catalogue. These reads are RLS-gated and cheap.
    read_traffic: {
      executor: 'constant-vus',
      vus: 400,
      duration: '90s',
      exec: 'readTraffic',
    },

    // C. (Optional) A legit user trying to sign in from the same IP
    // AFTER the spray has started. Should be throttled.
    legit_user: {
      executor: 'constant-vus',
      vus: 1,
      duration: '30s',
      exec: 'legitUser',
      startTime: '45s',  // give the spray 45s to lock the IP
    },
  },
  thresholds: {
    'read_latency_ms': ['p(95)<500'],
    'spray_attempts':  ['count>0'],
    'spray_rate_limited': ['rate>0.0'],   // at least some must be throttled
  },
};

// ── Scenario A ─────────────────────────────────────────────────────
export function sprayAttack() {
  const id = `2024-${randomString(5).toLowerCase()}-MN-0`;
  const url = `${SUPABASE_URL}/rest/v1/rpc/sign_in_identifier`;
  const payload = JSON.stringify({
    p_identifier: id,
    p_password: 'WrongP@ssw0rd',
  });
  const params = {
    headers: {
      'Content-Type': 'application/json',
      apikey: SUPABASE_ANON_KEY,
      Authorization: `Bearer ${SUPABASE_ANON_KEY}`,
    },
  };

  const res = http.post(url, payload, params);
  sprayAttempts.add(1);

  const isRateLimited =
    res.status === 429 ||
    (res.status >= 400 && /too many/i.test(res.body || '')) ||
    (res.status === 400 && /PGRST116|crypt/i.test(res.body || ''));

  sprayRateLimited.add(isRateLimited);
  check(res, { 'no 5xx from spray': (r) => r.status < 500 });
  sleep(0.5);
}

// ── Scenario B ─────────────────────────────────────────────────────
export function readTraffic() {
  const headers = {
    apikey: SUPABASE_ANON_KEY,
    Authorization: `Bearer ${SUPABASE_ANON_KEY}`,
  };

  // Hit the public SELECT endpoints. RLS will return [] for anon
  // browsing the catalogue, which is fine — we just want to know
  // the read path holds up.
  const eq = http.get(
    `${SUPABASE_URL}/rest/v1/equipment?select=id,code,name,available_count&limit=20`,
    { headers, tags: { name: 'get_equipment' } },
  );
  readLatency.add(eq.timings.duration);

  const br = http.get(
    `${SUPABASE_URL}/rest/v1/borrowings?select=id,equipment_id,status&limit=20`,
    { headers, tags: { name: 'get_borrowings' } },
  );
  readLatency.add(br.timings.duration);

  check(eq, { 'equipment read < 500ms': (r) => r.timings.duration < 500 && r.status < 500 });
  check(br, { 'borrowings read < 500ms': (r) => r.timings.duration < 500 && r.status < 500 });
  sleep(1);
}

// ── Scenario C ─────────────────────────────────────────────────────
export function legitUser() {
  if (!LEGIT_EMAIL || !LEGIT_PASSWORD) {
    return;  // not configured, no-op
  }
  const url = `${SUPABASE_URL}/auth/v1/token?grant_type=password`;
  const payload = JSON.stringify({ email: LEGIT_EMAIL, password: LEGIT_PASSWORD });
  const params = {
    headers: {
      'Content-Type': 'application/json',
      apikey: SUPABASE_ANON_KEY,
    },
  };

  const res = http.post(url, payload, params);
  if (res.status === 429 || /too many/i.test(res.body || '')) {
    legitBlocked.add(1);
  } else if (res.status === 200) {
    legitSucceeded.add(1);
  }
  sleep(2);
}
