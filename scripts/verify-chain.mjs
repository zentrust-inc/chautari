#!/usr/bin/env node
// Chautari — independent chain verifier.
//
// Anyone (the CFUG, the ward office, ZenTrust, any member) can run this on the
// public export and check that no entry was changed, removed or inserted.
// It needs only Node.js, no database and no login.
//
//   node scripts/verify-chain.mjs export.json            # verify an export file
//   node scripts/verify-chain.mjs export.json --head <hash>   # and compare with a published head
//
// export.json is an array of rows from the public view `chain_export`
// (the nightly job also commits it to the public Git repository).

import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';

const sha256 = (s) => createHash('sha256').update(s, 'utf8').digest('hex');
const GENESIS = '0'.repeat(64);

// Must match ww.canonical() in supabase/migrations/20261105000100_event_log.sql
export function canonical(r) {
  return [
    'wwos-v1',
    r.ward_id,
    String(r.seq),
    r.entity_id,
    r.type,
    r.occurred_on,
    r.fiscal_year ?? '',
    r.recorded_at_utc,
    r.payload_text,
    r.private_digest,
    r.evidence_text,
    r.prev_hash,
  ].join('|');
}

export function verify(rows) {
  const byWard = new Map();
  for (const r of rows) {
    if (!byWard.has(r.ward_id)) byWard.set(r.ward_id, []);
    byWard.get(r.ward_id).push(r);
  }
  const report = [];
  for (const [ward, list] of byWard) {
    list.sort((a, b) => Number(a.seq) - Number(b.seq));
    let prev = GENESIS;
    let expected = 1;
    let problem = null;
    for (const r of list) {
      if (Number(r.seq) !== expected) { problem = { seq: r.seq, reason: `missing entry: expected ${expected}` }; break; }
      if (r.prev_hash !== prev) { problem = { seq: r.seq, reason: 'link to the previous entry is broken' }; break; }
      if (sha256(canonical(r)) !== r.hash) { problem = { seq: r.seq, reason: 'content does not match its fingerprint' }; break; }
      prev = r.hash;
      expected += 1;
    }
    report.push({ ward, entries: list.length, head: prev, ok: !problem, problem });
  }
  return report;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const [file, flag, head] = process.argv.slice(2);
  if (!file) {
    console.error('usage: node scripts/verify-chain.mjs export.json [--head <hash>]');
    process.exit(2);
  }
  const rows = JSON.parse(readFileSync(file, 'utf8'));
  const report = verify(rows);
  let allOk = true;
  for (const r of report) {
    if (r.ok) {
      console.log(`✔ ${r.ward}: ${r.entries} entries, unbroken. Head ${r.head}`);
      if (flag === '--head' && head && head !== r.head) {
        console.log(`✘ ${r.ward}: head does not match the published head ${head}`);
        allOk = false;
      }
    } else {
      console.log(`✘ ${r.ward}: problem at entry ${r.problem.seq}: ${r.problem.reason}`);
      allOk = false;
    }
  }
  process.exit(allOk ? 0 : 1);
}
