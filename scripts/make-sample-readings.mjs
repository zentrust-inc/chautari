#!/usr/bin/env node
// Builds app/src/data/sample-readings.json: three SAMPLE bills with what the reader really read from them
// (samples/reader-output.json, made by `node reader/eval.mjs`), small photos for the screen, and
// fictional registered payees. The demo shows these; the real app gets readings from our own server.
import { readFile, writeFile } from 'node:fs/promises';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const out = JSON.parse(await readFile(join(root, 'samples/reader-output.json'), 'utf8'));
const truth = JSON.parse(await readFile(join(root, 'samples/truth.json'), 'utf8'));
const PICK = ['hw01', 'jcb01', 'fuel01'];
const payees = [
  { payee_id: 'e5e5e5e5-0000-0000-0000-000000000001', kind: 'shop', name: 'नमूना हार्डवेयर तथा निर्माण सामग्री' },
  { payee_id: 'e5e5e5e5-0000-0000-0000-000000000002', kind: 'contractor', name: 'नमूना भारी मेसिनरी सेवा' },
  { payee_id: 'e5e5e5e5-0000-0000-0000-000000000003', kind: 'shop', name: 'Sample Petroleum Pump' },
  { payee_id: 'e5e5e5e5-0000-0000-0000-000000000004', kind: 'shop', name: 'चाउथे किराना पसल' },
  { payee_id: 'e5e5e5e5-0000-0000-0000-000000000005', kind: 'shop', name: 'ककनी कृषि तथा बिउ पसल' },
];
const bills = PICK.map((id) => {
  const r = out[id]; const t = truth.bills.find((b) => b.id === id);
  const jpg = execFileSync('convert', [join(root, 'samples', t.file), '-resize', '620x', '-strip', '-quality', '58', 'jpg:-']);
  return {
    id, quality: t.quality, label: t.vendor,
    image: 'data:image/jpeg;base64,' + jpg.toString('base64'),
    doc: r.doc, reader: `${r.reader.name} (${r.reader.engine_version})`,
    fields: r.fields, flags: r.flags, items: r.items, items_ok: r.items_ok,
  };
});
// the sample assumes the hardware shop's bill 0417 is already recorded, so the duplicate check shows (sample only)
const recorded = [{ payee_id: 'e5e5e5e5-0000-0000-0000-000000000001', bill_no: '0417' }];
const data = { note: 'SAMPLE: fictional bills and payees; readings are the reader\'s real output on them.', payees, bills, recorded };
await writeFile(join(root, 'app/src/data/sample-readings.json'), JSON.stringify(data));
console.log(bills.map((b) => `${b.id} ${Math.round(b.image.length / 1024)} KB`).join(', '));
