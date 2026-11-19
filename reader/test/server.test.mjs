// The reader service with a stand-in database: sign-in is required, the photo is kept by its
// fingerprint, and the suggestion handed to the database carries the payee and budget line it matched.
import test from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { mkdtemp, readFile, stat } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { makeServer, toSuggestion, fiscalYearOf } from '../server.mjs';

const listen = (srv) => new Promise((r) => srv.listen(0, () => r(srv.address().port)));

test('fiscal year from a date (Shrawan starts it)', () => {
  assert.equal(fiscalYearOf('2026-10-22'), '2083/84');
  assert.equal(fiscalYearOf('2026-06-01'), '2082/83');
});

test('the service: sign in, keep the photo, suggest to the database', async () => {
  const calls = [];
  const db = createServer(async (req, res) => {
    let body = ''; for await (const c of req) body += c;
    calls.push({ url: req.url, body: body ? JSON.parse(body) : null });
    res.setHeader('content-type', 'application/json');
    if (req.url === '/auth/v1/user') return res.end(req.headers.authorization === 'Bearer good' ? '{"id":"u1"}' : (res.statusCode = 401, '{}'));
    if (req.url === '/rest/v1/rpc/officer_payees') return res.end(JSON.stringify([{ payee_id: 'p1', kind: 'shop', name: 'नमूना हार्डवेयर तथा निर्माण सामग्री' }]));
    if (req.url.startsWith('/rest/v1/budget_status')) return res.end(JSON.stringify([{ line_id: 'l1', account_code: 'EX-2.01', fiscal_year: '2083/84' }]));
    if (req.url === '/rest/v1/rpc/record_suggestion') return res.end('"s-1"');
    res.statusCode = 404; res.end('{}');
  });
  const dbPort = await listen(db);
  const docs = await mkdtemp(join(tmpdir(), 'docs-'));
  const fake = { // a stand-in reading, so the test needs no OCR
    doc: { sha256: 'x' }, reader: { name: 'chautari-reader/0.1.0', engine_version: 'test' }, flags: [], items: [],
    fields: { total: { value: 100, status: 'ok' }, date_ad: { value: '2026-10-22', status: 'ok' }, vendor: { value: 'नमूना हार्डवेयर तथा निर्माण सामग्री' },
      account_code: { value: 'EX-2.01', status: 'check' }, method: { value: 'cash' }, memo_np: { value: 'तार' }, bill_no: { value: '0417' }, kind: { value: 'expense' } },
  };
  const srv = makeServer({ docsDir: docs, supabaseUrl: `http://127.0.0.1:${dbPort}`, serviceKey: 'svc', read: async () => fake });
  const port = await listen(srv);
  const base = `http://127.0.0.1:${port}`;
  const photo = Buffer.from('not really a jpeg, but bytes are bytes');

  let r = await fetch(`${base}/read?entity=thumki-cfug`, { method: 'POST', body: photo, headers: { 'content-type': 'image/jpeg' } });
  assert.equal(r.status, 401, 'no sign-in, no reading');

  r = await fetch(`${base}/read?entity=thumki-cfug`, { method: 'POST', body: photo, headers: { 'content-type': 'text/plain', authorization: 'Bearer good' } });
  assert.equal(r.status, 415);

  r = await fetch(`${base}/read?entity=thumki-cfug`, { method: 'POST', body: photo, headers: { 'content-type': 'image/jpeg', authorization: 'Bearer good' } });
  assert.equal(r.status, 200);
  const j = await r.json();
  assert.equal(j.suggestion_id, 's-1');
  const sug = calls.find((c) => c.url === '/rest/v1/rpc/record_suggestion').body;
  assert.match(sug.p_doc_sha256, /^[0-9a-f]{64}$/);
  assert.equal(sug.p_suggested.type, 'expense.recorded');
  assert.equal(sug.p_suggested.payload.payee_id, 'p1');
  assert.equal(sug.p_suggested.payload.budget_line_id, 'l1');
  assert.equal(sug.p_suggested.fiscal_year, '2083/84');
  const kept = join(docs, 'thumki-cfug', `${sug.p_doc_sha256}.jpg`);
  assert.ok((await stat(kept)).size === photo.length, 'the photo is kept under its fingerprint');

  r = await fetch(`${base}${j.photo_url}`, { headers: { authorization: 'Bearer good' } });
  assert.deepEqual(Buffer.from(await r.arrayBuffer()), await readFile(kept));
  r = await fetch(`${base}${j.photo_url}`);
  assert.equal(r.status, 401, 'photos only for signed-in people');
  srv.close(); db.close();
});

test('a suggestion never names a payee it is not sure of', () => {
  const s = toSuggestion({ fields: { vendor: { value: 'कुनै अर्कै पसल' }, total: { value: 5 }, kind: { value: 'expense' } }, flags: [], items: [] },
    { payees: [{ payee_id: 'p1', name: 'Sample Petroleum Pump' }] });
  assert.equal(s.payload.payee_id, null);
});
