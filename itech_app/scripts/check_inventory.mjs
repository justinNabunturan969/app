// scripts/check_inventory.mjs
// Diagnostic: snapshot equipment counts + open-borrowing counts + the
// discrepancy between them. Lets the user see exactly which equipment
// rows are off without me touching the DB.

const URL = 'https://obwdgxcfxxixnuqsjfpu.supabase.co';
const ANON = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9id2RneGNmeHhpeG51cXNqZnB1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU2MzkwMjYsImV4cCI6MjEwMTIxNTAyNn0.Nb1VQlS13rmOlbziFSRzVJR80S069yZtb4G-1VqM3WI';

const headers = {
  'apikey': ANON,
  'Authorization': `Bearer ${ANON}`,
  'Content-Type': 'application/json',
};

async function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

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
  const eqResp = await fetchWithRetry(`${URL}/rest/v1/equipment?select=id,code,name,available_count,total_count&order=code`, { headers });
  console.log('  status', eqResp.status);
  const equipment = await eqResp.json();
  console.log(`Got ${equipment.length} equipment rows.`);

  console.log('Reading open borrowings...');
  const borrowResp = await fetchWithRetry(`${URL}/rest/v1/borrowings?select=id,equipment_id,status,quantity&status=in.(active,overdue,return_requested)&limit=500`, { headers });
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
      drift.push({ code: e.code, name: e.name, available_count: e.available_count, expected: expectedAvail, open_units: out, total: e.total_count });
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
  console.table(equipment.map(e => ({ code: e.code, name: e.name, available: e.available_count, total: e.total_count })));
}

main().catch(e => { console.error('ERR:', e.message); process.exit(1); });
