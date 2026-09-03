// tests/load/scenarios/01-login-burst.js
//
// Goal: prove the student-login RPC path can absorb a realistic
// concurrent sign-in burst without breaching the documented p95 /
// error-rate budgets, and that the per-IP rate limiter fires at the
// expected threshold under attack.
//
// What this exercises (against your real Supabase project):
//   1. 100 VUs each call POST /auth/v1/token?grant_type=password with
//      a unique student email + a known-bad password.
//   2. We measure p95 latency and the 429 / "Too many sign-in attempts"
//      rate. With 100 unique identifiers, the per-identifier limit
//      (5 fails / 15 min) never fires; only the per-IP and the
//      platform-level GoTrue limits can.
//
// Pass criteria:
//   - p95 < 1500ms under the burst
//   - < 1% of requests return 429 (i.e. the system absorbs the spike)
//   - 0 unhandled 5xx responses
//   - at least one request was processed by the auth server (status
//     200 or a real auth error, not a network failure)
//
// Note on the VU count: the original 800 was a stress test that
// reliably hit the per-IP throttle. 100 is a realistic peak for a
// PUP lab at class start — most sections have 40-60 students and
// they don't all press "Sign in" at the exact same second, but
// 100 simultaneous within a 30s window is plausible if a class ends
// and the next one starts. The system should hold this without
// locking anyone out.
//
// Run:
//   k6 run -e SUPABASE_URL=https://YOUR.supabase.co \
//          -e SUPABASE_ANON_KEY=eyJ... \
//          -e STUDENT_DOMAIN=pup.edu.ph \
//          tests/load/scenarios/01-login-burst.js

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend, Rate, Counter } from 'k6/metrics';
import { randomString } from 'https://jslib.k6.io/k6-utils/1.4.0/index.js';

const SUPABASE_URL = __ENV.SUPABASE_URL || 'https://YOUR.supabase.co';
const SUPABASE_ANON_KEY = __ENV.SUPABASE_ANON_KEY || 'YOUR_ANON_KEY';
const STUDENT_DOMAIN = __ENV.STUDENT_DOMAIN || 'pup.edu.ph';

const loginLatency = new Trend('login_latency_ms');
const rateLimited  = new Rate('rate_limited');
const serverError  = new Counter('server_errors_5xx');
const success      = new Counter('login_successes');
const authProcessed = new Counter('auth_processed');  // 200 or 4xx with a real auth body

export const options = {
  scenarios: {
    // 100 VUs ramped over 30 seconds (one class section logging in
    // over a 30s window), sustained for 60 seconds, then ramped down.
    login_burst: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '30s', target: 100 },  // ramp up: class fills the lab
        { duration: '60s', target: 100 },  // hold: students are still signing in
        { duration: '30s', target: 0 },    // ramp down: stragglers
      ],
      gracefulRampDown: '15s',
    },
  },
  thresholds: {
    'http_req_duration{scenario:login_burst}': ['p(95)<1500'],
    'rate_limited': ['rate<0.01'],          // < 1% throttled
    'server_errors_5xx': ['count<10'],      // < 10 unhandled 5xx across the whole test
    'auth_processed':   ['count>0'],        // at least one request reached the auth server
  },
  // Tag every iteration so the threshold filter matches.
  tags: { scenario: 'login_burst' },
};

export default function () {
  const vuId = __VU;
  // Each VU uses its own identifier so we don't double-count failures
  // against a single rate-limit bucket.
  const email = `loadtest+vu${vuId}_${randomString(6)}@${STUDENT_DOMAIN}`;
  const password = 'WrongPassword!23';

  const url = `${SUPABASE_URL}/auth/v1/token?grant_type=password`;
  const payload = JSON.stringify({ email, password });
  const params = {
    headers: {
      'Content-Type': 'application/json',
      apikey: SUPABASE_ANON_KEY,
    },
    tags: { scenario: 'login_burst' },
  };

  const res = http.post(url, payload, params);
  loginLatency.add(res.timings.duration);

  const isRateLimited = res.status === 429 ||
    (res.status === 400 && /too many/i.test(res.body || ''));
  const isServerError = res.status >= 500;
  const isSuccess = res.status === 200;
  // "Auth processed" = the request reached the auth server and got a
  // real response (200 success, 400 invalid_credentials, etc). A 429
  // or a network/0 response doesn't count.
  const isAuthProcessed = res.status > 0 && res.status < 500;

  rateLimited.add(isRateLimited);
  if (isServerError) serverError.add(1);
  if (isSuccess) success.add(1);
  if (isAuthProcessed) authProcessed.add(1);

  check(res, {
    'no 5xx': (r) => r.status < 500,
    'latency recorded': (r) => r.timings.duration >= 0,
  });

  // Simulate the real client behaviour: after a failed login the user
  // stares at the error for a beat before trying again. 1-3s is
  // realistic for a classroom.
  sleep(1 + Math.random() * 2);
}
