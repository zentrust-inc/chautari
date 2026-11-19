// The same check as scripts/verify-chain.mjs, run on the phone with WebCrypto.
// Must match ww.canonical() in supabase/migrations/20261105000100_event_log.sql.
export interface ChainRow {
  ward_id: string; seq: number; entity_id: string; type: string; occurred_on: string;
  fiscal_year: string | null; recorded_at_utc: string; payload_text: string; private_digest: string;
  evidence_text: string; prev_hash: string; hash: string;
}
export interface WardReport { ward: string; entries: number; head: string; ok: boolean; problem: { seq: number; reason: string } | null }

const GENESIS = '0'.repeat(64);
const enc = new TextEncoder();
async function sha256(s: string) {
  const b = new Uint8Array(await crypto.subtle.digest('SHA-256', enc.encode(s)));
  let h = ''; for (const x of b) h += x.toString(16).padStart(2, '0'); return h;
}
export const canonical = (r: ChainRow) => ['wwos-v1', r.ward_id, String(r.seq), r.entity_id, r.type, r.occurred_on,
  r.fiscal_year ?? '', r.recorded_at_utc, r.payload_text, r.private_digest, r.evidence_text, r.prev_hash].join('|');

export async function verify(rows: ChainRow[]): Promise<WardReport[]> {
  const byWard = new Map<string, ChainRow[]>();
  for (const r of rows) { if (!byWard.has(r.ward_id)) byWard.set(r.ward_id, []); byWard.get(r.ward_id)!.push(r); }
  const out: WardReport[] = [];
  for (const [ward, list] of byWard) {
    list.sort((a, b) => Number(a.seq) - Number(b.seq));
    let prev = GENESIS, expected = 1, problem: WardReport['problem'] = null;
    for (const r of list) {
      if (Number(r.seq) !== expected) { problem = { seq: r.seq, reason: 'missing' }; break; }
      if (r.prev_hash !== prev) { problem = { seq: r.seq, reason: 'link' }; break; }
      if ((await sha256(canonical(r))) !== r.hash) { problem = { seq: r.seq, reason: 'content' }; break; }
      prev = r.hash; expected += 1;
    }
    out.push({ ward, entries: list.length, head: prev, ok: !problem, problem });
  }
  return out;
}
