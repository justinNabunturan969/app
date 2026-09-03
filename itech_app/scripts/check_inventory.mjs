// scripts/check_inventory.mjs
// Diagnostic: snapshot equipment counts + open-borrowing counts + the
// discrepancy between them. Lets the user see exactly which equipment
// rows are off without me touching the DB.
//
// CREDENTIALS:
//   Reads SUPABASE_URL and SUPABASE_ANON_KEY from the process environment.
//   These used to be hardcoded in this file (git-tracked, public) — that
//   was a security issue (see docs/security-audit-2026-09-03.md §2.2 H1)
//   because it pinned the project URL in a tracked file even though the
//   anon key is technically public. The key is now read at runtime.
//
//   Two ways to set them:
//     1. Inline:
//          SUPABASE_URL=https://x.supabase.co SUPABASE_ANON_KEY=eyJ... \
//            node scripts/check_inventory.mjs
//     2. From .env (use the template in scripts/.env.example):
//          cp scripts/.env.example scripts/.env
//          edit scripts/.env
//          node --env-file=scripts/.env scripts/check_inventory.mjs   # Node 20.6+
//        (or any other dotenv loader, e.g. `dotenvx run -- node ...`)

import { readFileSync } from 'node:fs';

// Minimal .env loader so this script runs on any Node version without
// needing --env-file or a third-party package. Silent if the file is
// absent — env vars set in the shell take precedence.
function loadEnv(path) {
  try {
    const text = readFileSync(path, 'utf8');
    for (const line of text.split('\n')) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith('#')) continue;
      const eq = trimmed.indexOf('=');
      if (eq < 0) continue;
      const key = trimmed.slice(0, eq).trim();
      let value = trimmed.slice(eq + 1).trim();
      // strip surrounding quotes
      if (
        (value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))
      ) {
        value = value.slice(1, -1);
      }
      if (process.env[key] === undefined) process.env[key] = value;
    }
  } catch {
    // .env is optional — the user may have set env vars in their shell.
  }
}
loadEnv(new URL('./.env', import.meta.url));

const URL = process.env.SUPABASE_URL;
const ANON = process.env.SUPABASE_ANON_KEY;

if (!URL || !ANON) {
  console.error(
    'Missing credentials.\n' +
      '\n' +
      'Set SUPABASE_URL and SUPABASE_ANON_KEY in your environment, e.g.:\n' +
      '  cp scripts/.env.example scripts/.env\n' +
      '  edit scripts/.env\n' +
      '  node --env-file=scripts/.env scripts/check_inventory.mjs\n' +
      '\n' +
      'Or inline:\n' +
      '  SUPABASE_URL=https://x.supabase.co SUPABASE_ANON_KEY=eyJ... node scripts/check_inventory.mjs',
  );
  process.exit(1);
}

const headers = {
  apikey: ANON,
  Authorization: `Bearer ${ANON}`,
  'Content-Type': 'application/json',
};

async function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

async function fetchWithRetry(url, opts, tries = 3) {
  let lastErr;
  for (let i = 0; i < tries; i++) {
    try {
      const r = await fetch(url, opts);
      return r;
    } catch (e) {
      lastErr = e;
      await sleep(800 * (i + 1));
    }
  }
  throw lastErr;
}

async function main() {
  console.log('Reading equipment rows...');
  const eqResp = await fetchWithRetry(
    `${URL}/rest/v1/equipment?select=id,code,name,available_count,total_count&order=code`,
    { headers },
  );
  console.log('  status', eqResp.status);
  const equipment = await eqResp.json();
  console.log(`Got ${equipment.length} equipment rows.`);

  console.log('Reading open borrowings...');
  const borrowResp = await fetchWithRetry(
    `${URL}/rest/v1/borrowings?select=id,equipment_id,status,quantity&status=in.(active,overdue,return_requested)&limit=500`,
    { headers },
  );
  console.log('  status', borrowResp.status);
  const openBorrowings = await borrowResp.json();
  console.log(`Got ${openBorrowings.length} open borrowings.`);

  // Compute expected available_count for each equipment row.
  const expected = new Map();
  for (const b of openBorrowings) {
    expected.set(b.equipment_id, (expected.get(b.equipment_id) || 0) + (b.quantity || 1));
  }

  // Build the report.
  const drift = [];
  for (const e of equipment) {
    const out = expected.get(e.id) || 0;
    const expectedAvail = Math.max(0, Math.min(e.total_count, e.total_count - out));
    if (e.available_count !== expectedAvail) {
      drift.push({
        code: e.code,
        name: e.name,
        available_count: e.available_count,
        expected: expectedAvail,
        open_units: out,
        total: e.total_count,
      });
    }
  }

  console.log('\n=== Equipment with count drift ===');
  if (drift.length === 0) {
    console.log('  (none — every available_count matches the open-borrowing count)');
  } else {
    console.table(drift);
  }

  // Also show ALL equipment for the user's reference.
  console.log('\n=== All equipment ===');
  console.table(
    equipment.map((e) => ({
      code: e.code,
      name: e.name,
      available: e.available_count,
      total: e.total_count,
    })),
  );
}

main().catch((e) => {
  console.error('ERR:', e.message);
  process.exit(1);
});
