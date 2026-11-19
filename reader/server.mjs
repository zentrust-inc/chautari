#!/usr/bin/env node
// The reader service, on our own server. The app sends a bill's photo here; nothing goes to any outside service.
//
//   POST /read?entity=thumki-cfug&kind=bill   body: the photo (image/jpeg or image/png), header: Authorization: Bearer <user's token>
//     -> keeps the photo under DOCS_DIR/<entity>/<sha256>.<ext>, reads it, hands the suggestion to the
//        database (public.record_suggestion, service key) and returns the reading with its suggestion_id
//   GET  /documents/<entity>/<sha256>.<ext>   the photo, for signed-in people
//   GET  /health
//
// Settings (environment): PORT (8787), DOCS_DIR (./documents), SUPABASE_URL, SUPABASE_SERVICE_KEY,
// ALLOW_ORIGIN (the app's address), MAX_BYTES (8 MB).
// The service key stays on this server. The reader can only suggest: confirm_suggestion needs a signed-in person.
import { createServer } from 'node:http';
import { mkdir, writeFile, readFile, rename } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import NepaliDate from 'nepali-date-converter';
import { readDocument } from './read.mjs';

const env = (k, d) => process.env[k] ?? d;

export function bestPayee(payees, vendor) {
  if (!vendor) return null;
  const norm = (s) => String(s).replace(/\s+/g, '').toLowerCase();
  const v = norm(vendor);
  let best = null, score = 0;
  for (const p of payees) {
    const n = norm(p.name ?? '');
    if (!n) continue;
    if (n === v) return p.payee_id;
    const set = new Set(n);
    const common = [...set].filter((c) => v.includes(c)).length / Math.max(set.size, 1);
    if (common > score) { score = common; best = p.payee_id; }
  }
  return score >= 0.8 ? best : null;
}

export function fiscalYearOf(iso) {
  if (!iso) return null;
  const [y, m, d] = iso.split('-').map(Number);
  const n = new NepaliDate(new Date(y, m - 1, d, 12));
  const fy = n.getMonth() >= 3 ? n.getYear() : n.getYear() - 1;
  return `${fy}/${String((fy + 1) % 100).padStart(2, '0')}`;
}

/** what the database keeps as the reader's suggestion (the same keys confirm_suggestion compares) */
export function toSuggestion(reading, { payees = [], lines = [] } = {}) {
  const f = reading.fields;
  const type = f.kind?.value === 'income' ? 'income.recorded' : 'expense.recorded';
  const fy = fiscalYearOf(f.date_ad?.value);
  const line = lines.find((l) => l.account_code === f.account_code?.value && (!fy || l.fiscal_year === fy));
  const payload = {
    amount: f.total?.value ?? null, account_code: f.account_code?.value ?? null,
    payee_id: bestPayee(payees, f.vendor?.value), method: f.method?.value ?? null,
    budget_line_id: line?.line_id ?? null, memo_np: f.memo_np?.value ?? null, bill_no: f.bill_no?.value ?? null,
  };
  return { type, occurred_on: f.date_ad?.value ?? null, fiscal_year: fy, payload, fields: f, flags: reading.flags, items: reading.items };
}

export function makeServer({ docsDir = env('DOCS_DIR', './documents'), supabaseUrl = env('SUPABASE_URL'), serviceKey = env('SUPABASE_SERVICE_KEY'),
  allowOrigin = env('ALLOW_ORIGIN', ''), maxBytes = Number(env('MAX_BYTES', 8 << 20)), read = readDocument } = {}) {
  const sb = async (path, init = {}) => {
    const res = await fetch(supabaseUrl + path, { ...init, headers: { apikey: serviceKey, authorization: `Bearer ${serviceKey}`, 'content-type': 'application/json', ...(init.headers ?? {}) } });
    if (!res.ok) throw new Error(`database: ${res.status} ${await res.text()}`);
    return res.status === 204 ? null : res.json();
  };
  const signedIn = async (req) => {
    const tok = /^Bearer (.+)$/.exec(req.headers.authorization ?? '')?.[1];
    if (!tok) return null;
    const res = await fetch(supabaseUrl + '/auth/v1/user', { headers: { apikey: serviceKey, authorization: `Bearer ${tok}` } });
    return res.ok ? res.json() : null;
  };
  const send = (res, code, body, type = 'application/json') => {
    res.writeHead(code, { 'content-type': type, ...(allowOrigin ? { 'access-control-allow-origin': allowOrigin, 'access-control-allow-headers': 'authorization, content-type', 'access-control-allow-methods': 'GET, POST' } : {}) });
    res.end(type === 'application/json' ? JSON.stringify(body) : body);
  };

  return createServer(async (req, res) => {
    try {
      const url = new URL(req.url, 'http://x');
      if (req.method === 'OPTIONS') return send(res, 204, '');
      if (url.pathname === '/health') return send(res, 200, { ok: true });

      const user = await signedIn(req);
      if (!user) return send(res, 401, { error: 'sign in first' });

      const doc = /^\/documents\/([a-z0-9-]+)\/([0-9a-f]{64})\.(jpg|jpeg|png)$/.exec(url.pathname);
      if (req.method === 'GET' && doc) {
        return send(res, 200, await readFile(join(docsDir, doc[1], `${doc[2]}.${doc[3]}`)), doc[3] === 'png' ? 'image/png' : 'image/jpeg');
      }

      if (req.method === 'POST' && url.pathname === '/read') {
        const entity = url.searchParams.get('entity') ?? '';
        if (!/^[a-z0-9-]+$/.test(entity)) return send(res, 400, { error: 'which body? (entity)' });
        const type = String(req.headers['content-type'] ?? '');
        const ext = type.includes('png') ? 'png' : type.includes('jpeg') || type.includes('jpg') ? 'jpg' : null;
        if (!ext) return send(res, 415, { error: 'send a JPEG or PNG photo' });
        const chunks = []; let size = 0;
        for await (const c of req) { size += c.length; if (size > maxBytes) return send(res, 413, { error: 'photo too large' }); chunks.push(c); }
        const body = Buffer.concat(chunks);
        const sha = createHash('sha256').update(body).digest('hex');
        const dir = join(docsDir, entity); await mkdir(dir, { recursive: true });
        const tmp = join(tmpdir(), `chautari-${sha}.${ext}`); await writeFile(tmp, body);
        const reading = await read(tmp, { kind: 'bill' });
        await rename(tmp, join(dir, `${sha}.${ext}`)).catch(async () => { await writeFile(join(dir, `${sha}.${ext}`), body); });
        const [payees, lines] = await Promise.all([
          sb('/rest/v1/rpc/officer_payees', { method: 'POST', body: JSON.stringify({ p_entity: entity }) }).catch(() => []),
          sb(`/rest/v1/budget_status?entity_id=eq.${entity}`).catch(() => []),
        ]);
        const suggested = toSuggestion(reading, { payees, lines });
        const readerName = `${reading.reader.name} (${reading.reader.engine_version})`;
        const suggestion_id = await sb('/rest/v1/rpc/record_suggestion', { method: 'POST', body: JSON.stringify({
          p_entity: entity, p_doc_sha256: sha, p_doc_kind: 'bill', p_doc_path: `documents/${entity}/${sha}.${ext}`, p_reader: readerName, p_suggested: suggested }) });
        return send(res, 200, { suggestion_id, doc: reading.doc, reader: readerName, fields: reading.fields, flags: reading.flags, items: reading.items,
          image: null, photo_url: `/documents/${entity}/${sha}.${ext}` });
      }
      send(res, 404, { error: 'not found' });
    } catch (e) {
      send(res, 500, { error: String(e.message ?? e) });
    }
  });
}

if (import.meta.url === `file://${process.argv[1]}`) {
  if (!process.env.SUPABASE_URL || !process.env.SUPABASE_SERVICE_KEY) { console.error('set SUPABASE_URL and SUPABASE_SERVICE_KEY'); process.exit(2); }
  const port = Number(env('PORT', 8787));
  makeServer().listen(port, () => console.log(`चौतारी reader on :${port}`));
}
