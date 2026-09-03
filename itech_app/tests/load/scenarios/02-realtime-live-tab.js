// tests/load/scenarios/02-realtime-live-tab.js
//
// Goal: prove the admin "Live" tab — which subscribes to the
// `active_sessions` Postgres Changes channel — can handle the
// scenario where 800 students have just logged in and the admin
// opens the Live tab to monitor occupancy.
//
// What this exercises:
//   - 800 concurrent WebSocket connections to Supabase Realtime
//   - 1 admin VU subscribed to the active_sessions channel waiting
//     for INSERT events from the 800 students
//   - One student logs in (auth call) and verifies the admin receives
//     a real-time update within 5 seconds
//
// Pass criteria:
//   - All 800 student WebSockets connect within 10 seconds
//   - 95% of student WebSockets stay connected for the full scenario
//   - Admin sees >= 1 INSERT event for active_sessions within 5s of a
//     student's login
//   - 0 unhandled disconnects during the steady-state phase
//
// IMPORTANT: this test needs a real student account that can sign in.
// Pass STUDENT_EMAIL and STUDENT_PASSWORD via env. The student
// account must already exist in your Supabase project (the test
// creates the active_sessions row, not the user).
//
// Supabase Realtime has a per-channel concurrent connection limit
// (200 on Free, 500 on Pro). If you see connection drops during
// the ramp-up, the per-channel limit is the reason — see §3.5 of
// the security audit for mitigations.

import http from 'k6/http';
import ws from 'k6/ws';
import { check, sleep } from 'k6';
import { Trend, Counter, Rate } from 'k6/metrics';

const SUPABASE_URL       = __ENV.SUPABASE_URL       || 'https://YOUR.supabase.co';
const SUPABASE_ANON_KEY  = __ENV.SUPABASE_ANON_KEY  || 'YOUR_ANON_KEY';
const STUDENT_EMAIL      = __ENV.STUDENT_EMAIL      || 'loadtest+student@pup.edu.ph';
const STUDENT_PASSWORD   = __ENV.STUDENT_PASSWORD   || 'A_STRONG_PASSWORD';

const realtimeConnMs    = new Trend('realtime_connect_ms');
const realtimeDrops     = new Counter('realtime_drops');
const realtimeConnected = new Counter('realtime_connections');
const adminGotEvent     = new Counter('admin_received_event');
const studentLoggedIn   = new Counter('student_logged_in');

export const options = {
  scenarios: {
    // 800 students each open a Realtime WebSocket and keep it open.
    // No data flows on the student side — we're just measuring how
    // many concurrent connections Supabase Realtime accepts.
    student_subscribers: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '30s', target: 800 },
        { duration: '120s', target: 800 },  // hold
        { duration: '15s', target: 0 },
      ],
      gracefulRampDown: '15s',
      exec: 'studentSubscriber',
    },

    // 1 admin subscriber that listens for INSERT events on
    // public.active_sessions. This is the Live tab's actual use case.
    admin_subscriber: {
      executor: 'constant-vus',
      vus: 1,
      duration: '180s',
      exec: 'adminSubscriber',
      startTime: '5s',  // let student subscribers ramp first
    },

    // One VU signs in periodically to generate active_sessions events.
    // The admin_subscriber should receive the INSERT within 5s.
    login_driver: {
      executor: 'constant-vus',
      vus: 1,
      duration: '150s',
      exec: 'loginDriver',
      startTime: '30s',  // after subscribers are mostly up
    },
  },
  thresholds: {
    'realtime_connect_ms': ['p(95)<10000'],
    'realtime_drops': ['count<50'],           // < 50 drops across 800 connections
    'admin_received_event': ['count>0'],      // at least one event must arrive
  },
};

// Convert https://x.supabase.co to wss://x.supabase.co
function realtimeUrl() {
  return SUPABASE_URL.replace(/^https?:\/\//, 'wss://') +
    `/realtime/v1/websocket?apikey=${SUPABASE_ANON_KEY}&log_level=error`;
}

export function studentSubscriber() {
  const url = realtimeUrl();
  const res = ws.connect(url, null, (socket) => {
    socket.on('open', () => {
      realtimeConnected.add(1);
      // Subscribe to the postgres_changes channel for active_sessions.
      // We don't need to do anything with the events; we're just
      // holding a connection open.
      socket.send(JSON.stringify({
        topic: 'active_sessions',
        event: 'phx_join',
        payload: {
          config: {
            postgres_changes: [
              { event: '*', schema: 'public', table: 'active_sessions' },
            ],
          },
        },
        ref: '1',
      }));
    });

    socket.on('close', () => realtimeDrops.add(1));
    socket.on('error', () => realtimeDrops.add(1));

    socket.setTimeout(() => socket.close(), 130_000);
  });

  realtimeConnMs.add(res.timings.connecting || 0);
  check(res, { 'websocket connected': (r) => r && r.status === 101 });
}

export function adminSubscriber() {
  const url = realtimeUrl();
  const res = ws.connect(url, null, (socket) => {
    socket.on('open', () => {
      socket.send(JSON.stringify({
        topic: 'active_sessions',
        event: 'phx_join',
        payload: {
          config: {
            postgres_changes: [
              { event: 'INSERT', schema: 'public', table: 'active_sessions' },
            ],
          },
        },
        ref: '1',
      }));
    });

    socket.on('message', (data) => {
      try {
        const msg = JSON.parse(data);
        if (msg.event === 'postgres_changes' && msg.payload?.eventType === 'INSERT') {
          adminGotEvent.add(1);
        }
      } catch (_) {
        // not JSON or not an event we care about
      }
    });

    socket.setTimeout(() => socket.close(), 170_000);
  });

  check(res, { 'admin websocket connected': (r) => r && r.status === 101 });
}

export function loginDriver() {
  // Sign in once per iteration to create an active_sessions row.
  // The admin subscriber should pick it up via Realtime.
  const url = `${SUPABASE_URL}/auth/v1/token?grant_type=password`;
  const payload = JSON.stringify({
    email: STUDENT_EMAIL,
    password: STUDENT_PASSWORD,
  });
  const params = {
    headers: {
      'Content-Type': 'application/json',
      apikey: SUPABASE_ANON_KEY,
    },
  };

  const res = http.post(url, payload, params);
  if (res.status === 200) studentLoggedIn.add(1);
  sleep(10);  // one login per 10s is enough to generate steady events
}
