// चौतारी reader: from the text of a bill (or cash-book page) to a suggested entry.
//
// This file only reads text and checks arithmetic. It never decides anything:
//   - every field comes out as {value, status: 'ok' | 'check', why?, alts?}
//   - 'ok' needs independent agreement (two readings of the photo, or the bill's own arithmetic)
//   - anything else is 'check': the person looks at the photo and types the right figure
// A named person confirms every entry; nothing here can sign, approve or record.
import NepaliDate from 'nepali-date-converter';

// ---------------------------------------------------------------------------
// text clean-up
// ---------------------------------------------------------------------------
const DEV = '०१२३४५६७८९';
const toAscii = (s) => s.replace(/[०-९]/g, (c) => String(DEV.indexOf(c)));

/** Devanagari digits to 0-9. OCR often shows the Nepali १ as a Latin 9 inside a Devanagari number
 *  ("9००" for "१००"); a real ९ would have been read as ९, so in such mixed tokens 9 means १. */
export function normalizeDigits(text) {
  return text.split(/(\s+)/).map((tok) => (/[०-९]/.test(tok) ? toAscii(tok.replace(/9/g, '१')) : tok)).join('');
}

const NOISE = /[|_\[\]{}=~`^]/g;
const clean = (s) => normalizeDigits(s).replace(NOISE, ' ').replace(/\s+/g, ' ').replace(/(\d) ,(\d{3})/g, '$1,$2').trim();

export function parseAmount(s) {
  const n = Number(String(s).replace(/,/g, ''));
  return Number.isFinite(n) ? n : null;
}
// 1,10,740.00 / 12,800 / 3200 / 6.5
const AMT = /(?<![\d.,])(\d{1,3}(?:,\d{2,3})+|\d+)(?:\.(\d{1,2}))?(?![\d])|(?<![\d.])(,\d{3})(?:\.(\d{1,2}))?(?!\d)/g;
export function amountsIn(line) {
  const out = [];
  for (const m of line.matchAll(AMT)) {
    const raw = m[0];
    const v = parseAmount(raw.replace(/^,/, ''));
    if (v !== null) out.push({ value: v, raw, index: m.index, garbled: raw.startsWith(',') });
  }
  return out;
}

// ---------------------------------------------------------------------------
// dates (Bikram Sambat; an AD date is accepted and converted)
// ---------------------------------------------------------------------------
const p2 = (n) => String(n).padStart(2, '0');
const isoLocal = (dt) => `${dt.getFullYear()}-${p2(dt.getMonth() + 1)}-${p2(dt.getDate())}`;
const DATE = /(?<!\d)(20\d\d)\s*[\/\-.]\s*(\d{1,2})\s*[\/\-.]\s*(\d{1,2})(?!\d)/;
export function parseDate(text) {
  const m = DATE.exec(text);
  if (!m) return null;
  const y = +m[1], mo = +m[2], d = +m[3];
  if (mo < 1 || mo > 12 || d < 1 || d > 32) return { invalid: m[0] };
  try {
    if (y >= 2070) { // Bikram Sambat
      const nd = new NepaliDate(y, mo - 1, d);
      if (nd.getYear() !== y || nd.getMonth() !== mo - 1 || nd.getDate() !== d) return { invalid: m[0] };
      return { bs: `${y}/${p2(mo)}/${p2(d)}`, ad: isoLocal(nd.toJsDate()), raw: m[0] };
    }
    const ad = new Date(y, mo - 1, d, 12); // local noon: the calendar day, whatever the server's time zone
    if (ad.getMonth() !== mo - 1) return { invalid: m[0] };
    const nd = new NepaliDate(ad);
    return { bs: `${nd.getYear()}/${p2(nd.getMonth() + 1)}/${p2(nd.getDate())}`, ad: isoLocal(ad), raw: m[0], from_ad: true };
  } catch { return { invalid: m[0] }; }
}

// ---------------------------------------------------------------------------
// the CFUG's expense heads (directive annex 6): suggest, never decide
// ---------------------------------------------------------------------------
const HEADS = [
  ['EX-1.02', /चिया|खाजा|समोसा|भेला|बैठक|tea|snack|meeting/i],
  ['EX-1.04', /कागज|छपाई|स्टेशनरी|रजिस्टर|paper|print|register|stationer|notice/i],
  ['EX-1.08', /पेट्रोल|डिजेल|इन्धन|petrol|diesel|fuel|pump/i],
  ['EX-1.03', /तालिम|गोष्ठी|हल\s*भाडा|training|workshop|hall/i],
  ['EX-2.02', /बिरुवा|नर्सरी|बीउ|प्लास्टिक\s*ट्रे|sapling|seedling|nursery/i],
  ['EX-2.01', /तार|किला|घेराबार|सिमेन्ट|बालुवा|रड|jcb|माटो|खाल्डा|पैनी|fenc|cement|sand|\bgi\b|mesh|मेसिनरी|machinery/i],
  ['EX-1.06', /भाडा|औजार|chainsaw|आरा|rent|tool|कटर/i],
];
export function suggestHead(...texts) {
  const hay = texts.join(' ');
  const hits = HEADS.filter(([, re]) => re.test(hay)).map(([code]) => code);
  return { code: hits[0] ?? null, alts: hits.slice(1) };
}

// ---------------------------------------------------------------------------
// a bill
// ---------------------------------------------------------------------------
const RE_SUB = /उप\s*-?\s*जम्मा|उपजम्मा|sub\s*-?\s*total/i;
const RE_VAT = /(?<!\d)13\s*%|\bvat\b|मू\.?\s*अ\.?\s*कर/i;
const RE_TOTAL = /जम्मा|कुल|\btotal\b|grand|payable/i;
const RE_BANK = /बैंक|\bbank\b|चेक|cheque|check/i;
const RE_CASH = /नगद|\bcash\b/i;
const VAT_RATE = 0.13;
const near = (a, b, tol = 0.51) => a != null && b != null && Math.abs(a - b) < tol;

function parseItemLines(lines) {
  // item rows sit between the header and the sub-total; name and figures may be on one or two lines
  const items = [];
  let pending = null;
  for (const ln of lines) {
    if (RE_SUB.test(ln) || RE_TOTAL.test(ln) || RE_VAT.test(ln)) { if (items.length) break; else continue; }
    const amts = amountsIn(ln);
    // trailing figures: the last up-to-three numbers on the line
    const tail = amts.slice(-3);
    const head = tail.length ? ln.slice(0, tail[0].index) : ln;
    if (!amts.length) {
      const nm = ln.replace(/[^\p{L}\p{M}\d().\- ]/gu, ' ').trim();
      if (nm.replace(/[^\p{L}]/gu, '').length >= 3 && !/नमूना|sample|bill|बिल|मिति|date|PAN|ग्राहक|customer|क्र|विवरण|description|धन्यवाद|thank|नुवाकोट|nuwakot|काकानी|kakani|-{2,}/i.test(nm)) pending = nm;
      continue;
    }
    if (DATE.test(ln) || /मिति|\bdate\b|\bpan\b|बिल\s*नं|bill\s*no/i.test(ln)) continue; // header lines, not items
    let name = head.replace(/[x×X]\s*$/, '').replace(/[^\p{L}\p{M}\d().\- ]/gu, ' ').replace(/^\s*\d+\s+(?=\p{L})/u, '').trim();
    if (!name && pending) { name = pending; }
    pending = null;
    if (tail.length < 2 || name.replace(/[^\p{L}]/gu, '').length < 2) continue;
    let qty = null, rate = null, amount = tail.at(-1).value;
    if (tail.length === 3) { qty = tail[0].value; rate = tail[1].value; }
    else { rate = tail[0].value; if (rate) { const q = amount / rate; if (q > 0 && Math.abs(q - Math.round(q * 10) / 10) < 0.001) qty = Math.round(q * 10) / 10; } }
    const computed = qty != null && rate != null ? Math.round(qty * rate * 100) / 100 : null;
    items.push({ name: name.replace(/\s+/g, ' '), qty, rate, amount, computed, qty_inferred: tail.length < 3 });
  }
  return items;
}

/** One reading of a bill: lines are the OCR text lines for one pass. */
export function parseBill(rawLines) {
  const lines = rawLines.map(clean).filter(Boolean);
  const text = lines.join('\n');
  const f = { flags: [] };

  // --- who (first lines) ---
  const head = lines.slice(0, 4).filter((l) => l.replace(/[^\p{L}]/gu, '').length >= 5
    && !/^(कर\s*बिजक|tax\s*invoice|नगद|cash\s*memo)/i.test(l) && !/pan|पान/i.test(l) && !/\d{4}/.test(l));
  f.vendor = head.sort((a, b) => b.length - a.length)[0] ?? null;

  // --- PAN (9 digits in Nepal) ---
  const pan = /(?:pan|पान|करदाता)[^\d\n]{0,40}(\d{6,10})/i.exec(text);
  f.pan = pan ? pan[1] : null;

  // --- bill number ---
  const bn = /(?:बिल\s*नं|बिलनं|bill\s*no|invoice\s*no|विल\s*नं)\.?\s*[:.]?\s*([0-9][0-9A-Za-z\-\/]*)/i.exec(text)
    ?? /(?:^|\n)\s*(?:नं|no)\.?\s*([0-9][0-9\-\/]*)/i.exec(text);
  f.bill_no = bn ? bn[1] : null;

  // --- date ---
  const dline = lines.find((l) => DATE.test(l)) ?? null;
  f.date = dline ? parseDate(dline) : null;

  // --- money ---
  const lastAmt = (re, exclude) => {
    let best = null;
    for (const l of lines) {
      if (!re.test(l) || (exclude && exclude.some((x) => x.test(l)))) continue;
      const a = amountsIn(l);
      if (a.length) best = [...(best ?? []), a.at(-1)];
    }
    return best;
  };
  const subs = lastAmt(RE_SUB);
  const vats = lastAmt(RE_VAT, [RE_SUB]);
  const tots = lastAmt(RE_TOTAL, [RE_SUB, RE_VAT]);
  f.subtotal = subs ? subs.at(-1).value : null;
  f.vat = vats ? vats.at(-1).value : null;
  f.total = tots ? Math.max(...tots.map((a) => a.value)) : null;
  f.total_garbled = tots ? tots.some((a) => a.garbled) : false;
  f.has_vat_line = vats != null;

  // --- how it was paid ---
  f.method = RE_BANK.test(text) ? 'bank' : RE_CASH.test(text) ? 'cash' : null;

  // --- items ---
  f.items = parseItemLines(lines);

  // --- whose receipt: our own body's receipt book means money came in ---
  f.kind = /उपभोक्ता\s*समूह|सहकारी|cfug|cooperative|गुठी|guthi/i.test(f.vendor ?? '') && !f.pan ? 'income' : 'expense';
  return f;
}

// ---------------------------------------------------------------------------
// the bill's own arithmetic
// ---------------------------------------------------------------------------
export function reconcile({ subtotal: S, vat: V, total: T, items = [] }) {
  const r = { subtotal: S, vat: V, total: T, total_ok: false, repaired: [], notes: [] };
  if (S != null && V != null && T != null) {
    if (near(S + V, T)) r.total_ok = true;
    else if (V > 0 && near(V / VAT_RATE + V, T)) { r.subtotal = Math.round((V / VAT_RATE) * 100) / 100; r.repaired.push('subtotal'); r.total_ok = true; }
    else if (near(S * VAT_RATE, V)) { r.total = Math.round((S + V) * 100) / 100; r.repaired.push('total'); r.notes.push('total_from_parts'); }
    else if (near(T / (1 + VAT_RATE) * VAT_RATE, V)) { r.subtotal = Math.round((T - V) * 100) / 100; r.repaired.push('subtotal'); r.total_ok = true; }
  } else if (S != null && T != null && V == null) {
    r.total_ok = near(S, T);
  } else if (T != null && V != null && S == null) {
    r.total_ok = near(T / (1 + VAT_RATE) * VAT_RATE, V);
  }
  // items against the sub-total (or the total when there is no VAT)
  const base = r.subtotal ?? r.total;
  const sumOcr = items.reduce((a, i) => a + i.amount, 0);
  const sumCalc = items.reduce((a, i) => a + (i.computed ?? i.amount), 0);
  r.items_ok = items.length ? (near(sumOcr, base) ? true : near(sumCalc, base) ? 'calc' : false) : null;
  return r;
}

// ---------------------------------------------------------------------------
// putting several readings of the same photo together
// ---------------------------------------------------------------------------
const key = (v) => (v == null ? null : typeof v === 'string' ? v : String(v));
function vote(values) {
  const cnt = new Map();
  values.forEach((v) => { const k = key(v); if (k !== null) cnt.set(k, (cnt.get(k) ?? 0) + 1); });
  if (!cnt.size) return { value: null, votes: 0, alts: [] };
  const sorted = [...cnt.entries()].sort((a, b) => b[1] - a[1]);
  const top = sorted[0];
  const value = values.find((v) => key(v) === top[0]);
  return { value, votes: top[1], alts: sorted.slice(1).map(([k]) => values.find((v) => key(v) === k)), of: values.length };
}
const fld = (value, status, why, alts) => ({ value, status, ...(why ? { why } : {}), ...(alts?.length ? { alts } : {}) });
const MSG = {
  one_reading: ['एउटा मात्र पढाइ मिल्यो', 'only one reading agreed'],
  readings_differ: ['पढाइहरू फरक परे', 'the readings differ'],
  not_found: ['फोटोमा भेटिएन', 'not found in the photo'],
  sum_mismatch: ['जोड मिलेन', 'the figures do not add up'],
  pan_length: ['PAN ९ अङ्कको हुनुपर्छ', 'a PAN has 9 digits'],
  garbled: ['अङ्क अस्पष्ट', 'figure unclear'],
  repaired: ['बिलको जोडबाट सच्याइयो', 'corrected from the bill\'s own sums'],
  from_parts: ['उप-जम्मा र कर जोडेर', 'worked out from sub-total + VAT'],
  future_date: ['मिति भविष्यको छ', 'the date is in the future'],
  old_date: ['मिति १ वर्षभन्दा पुरानो', 'the date is over a year old'],
  assumed: ['अनुमान: नगद', 'assumed: cash'],
  invalid_date: ['मिति मिलेन', 'not a valid date'],
  short_date: ['महिना/दिन एक अङ्कको छ — फोटोसँग मिलाउनुहोस्', 'month or day has one digit — compare with the photo'],
  identifier: ['फोटोसँग मिलाउनुहोस्', 'compare with the photo'],
  items_mismatch: ['वस्तुको जोड मिलेन', 'the items do not add up'],
};
export const why = (code) => MSG[code] ?? [code, code];

/** @param passes array of parseBill() outputs for the same photo
 *  @param today  'YYYY-MM-DD' (to catch dates that cannot be right) */
export function mergePasses(passes, { today = new Date().toISOString().slice(0, 10) } = {}) {
  const n = passes.length;
  const out = { fields: {}, flags: [], passes: n };

  // money: reconcile each pass, then vote on the repaired figures
  const recs = passes.map((p) => ({ p, r: reconcile(p) }));
  const T = vote(recs.map(({ r }) => r.total));
  const S = vote(recs.map(({ r }) => r.subtotal));
  const V = vote(recs.map(({ p }) => p.vat));
  const winRec = recs.find(({ r }) => key(r.total) === key(T.value)) ?? recs[0];
  const agreed = T.votes >= 2 || n === 1;
  const sumsOk = winRec.r.total_ok;
  // a tick needs two independent supports: the 13% VAT triple (sub-total + VAT = total), or, without VAT,
  // the item lines adding up to the total. One misread line cannot satisfy either by itself.
  const R = winRec.r;
  const vatTriple = R.subtotal != null && R.vat != null && R.total != null && near(R.subtotal + R.vat, R.total) && near(R.subtotal * VAT_RATE, R.vat, 1.01);
  const noVat = winRec.p.vat == null;
  const itemsSupport = R.items_ok === true && (winRec.p.subtotal == null || near(winRec.p.subtotal, T.value));
  let totalStatus = 'check', totalWhy = null;
  if (T.value == null) totalWhy = 'not_found';
  else if (winRec.p.total_garbled) totalWhy = 'garbled';
  else if (R.repaired.includes('total')) totalWhy = 'from_parts';
  else if (!(vatTriple || (noVat && itemsSupport))) totalWhy = noVat && R.items_ok === false ? 'items_mismatch' : 'sum_mismatch';
  else if (T.votes < 2 && n > 1) totalWhy = 'one_reading';
  else totalStatus = 'ok';
  out.fields.total = fld(T.value, totalStatus, totalWhy, T.alts);
  out.fields.subtotal = fld(S.value, winRec.r.repaired.includes('subtotal') ? 'check' : (sumsOk && S.votes >= 1 ? 'ok' : 'check'),
    winRec.r.repaired.includes('subtotal') ? 'repaired' : (sumsOk ? null : 'sum_mismatch'), S.alts);
  out.fields.vat = fld(V.value, sumsOk && V.votes >= 2 ? 'ok' : 'check', V.value == null ? null : (sumsOk ? null : 'sum_mismatch'), V.alts);

  // date
  const dates = passes.map((p) => p.date);
  const dv = vote(dates.map((d) => (d && d.bs) || null));
  const dObj = dates.find((d) => d && d.bs === dv.value) ?? null;
  let dStatus = 'check', dWhy = null;
  if (!dObj) dWhy = dates.some((d) => d?.invalid) ? 'invalid_date' : 'not_found';
  else if (dv.votes < 2 && n > 1) dWhy = 'one_reading';
  else if (!/^\d{4}\s*[\/\-.]\s*\d{2}\s*[\/\-.]\s*\d{2}$/.test(dObj.raw)) dWhy = 'short_date';
  else if (dObj.ad > today) dWhy = 'future_date';
  else if (dObj.ad < new Date(Date.parse(today) - 366 * 864e5).toISOString().slice(0, 10)) dWhy = 'old_date';
  else dStatus = 'ok';
  out.fields.date_bs = fld(dObj?.bs ?? null, dStatus, dWhy, dv.alts);
  out.fields.date_ad = fld(dObj?.ad ?? null, dStatus, dWhy);

  // bill number, PAN, vendor, payment method
  const bn = vote(passes.map((p) => p.bill_no));
  out.fields.bill_no = fld(bn.value, bn.votes === n && bn.value ? 'ok' : 'check', bn.value == null ? 'not_found' : bn.votes < n ? 'readings_differ' : null, bn.alts);
  const pn = vote(passes.map((p) => p.pan));
  const panOk = pn.value && /^\d{9}$/.test(pn.value);
  out.fields.pan = fld(pn.value, panOk && pn.votes === n ? 'ok' : 'check', pn.value == null ? null : !panOk ? 'pan_length' : pn.votes < n ? 'readings_differ' : null, pn.alts);
  const vn = vote(passes.map((p) => p.vendor));
  out.fields.vendor = fld(vn.value, vn.votes === n ? 'ok' : 'check', vn.value == null ? 'not_found' : vn.votes < n ? 'readings_differ' : null, vn.alts);
  const mv = vote(passes.map((p) => p.method));
  out.fields.method = mv.value ? fld(mv.value, mv.votes === n ? 'ok' : 'check', mv.votes < n ? 'readings_differ' : null) : fld('cash', 'check', 'assumed');

  // document kind and the expense head are always only a suggestion
  const kv = vote(passes.map((p) => p.kind));
  out.fields.kind = fld(kv.value ?? 'expense', 'check', null, kv.alts);
  const items = (winRec.p.items ?? []).map((i) => ({ ...i }));
  const head = suggestHead(out.fields.vendor.value ?? '', items.map((i) => i.name).join(' '));
  out.fields.account_code = fld(head.code, 'check', head.code ? null : 'not_found', head.alts);

  // items (shown to the person; never the basis of an 'ok')
  out.items = items.map((i) => ({ name: i.name, qty: i.qty, rate: i.rate, amount: (winRec.r.items_ok === 'calc' && i.computed != null) ? i.computed : i.amount, ocr_amount: i.amount }));
  out.items_ok = winRec.r.items_ok;
  out.fields.memo_np = fld(items.length ? items.slice(0, 3).map((i) => i.name).join(', ') + (items.length > 3 ? ' …' : '') : (out.fields.vendor.value ?? ''), 'check');

  // flags: what the person must look at first
  for (const [name, f] of Object.entries(out.fields)) {
    if (f.status === 'check' && ['total', 'date_bs', 'bill_no', 'pan', 'vendor', 'subtotal', 'vat'].includes(name) && f.why) {
      out.flags.push({ field: name, code: f.why, np: why(f.why)[0], en: why(f.why)[1] });
    }
  }
  if (winRec.r.items_ok === false) out.flags.push({ field: 'items', code: 'sum_mismatch', np: 'वस्तुहरूको जोड मिलेन', en: 'the items do not add up to the sub-total' });
  return out;
}

// ---------------------------------------------------------------------------
// an old cash-book page: date, particulars, receipt or payment, balance
// The running balance tells which column a figure was in, and checks it.
// ---------------------------------------------------------------------------
export function parseCashbook(rawLines) {
  const lines = rawLines.map(clean).filter(Boolean);
  const rows = [];
  let prev = null;
  for (const ln of lines) {
    const d = parseDate(ln);
    if (!d || d.invalid) continue;
    const after = ln.slice(ln.indexOf(d.raw) + d.raw.length);
    const amts = amountsIn(after);
    const firstAmt = amts[0]?.index ?? after.length;
    const particulars = after.slice(0, firstAmt).replace(/[^\p{L}\p{M}\d ,.()\-]/gu, ' ').replace(/\s+/g, ' ').trim();
    const vals = amts.map((a) => a.value);
    // a minus (or bracket) before the balance: keep the sign, and mark cash below zero for the person.
    // Reading the balance without its sign once made a false sum close on the next row.
    const lastAmt = amts.at(-1);
    const negative = lastAmt && /[-–(]\s*$/.test(after.slice(0, lastAmt.index));
    const row = { date_bs: d.bs, date_ad: d.ad, particulars, receipt: null, payment: null, balance: null, status: 'check', why: null };
    if (vals.length === 0) { row.why = 'not_found'; }
    else if (prev == null) {
      row.balance = vals.at(-1);
      if (vals.length >= 2 && near(vals[0], vals.at(-1))) { row.receipt = vals[0]; row.opening = true; row.status = 'ok'; }
      else { row.why = 'garbled'; }
    } else if (vals.length >= 2) {
      const x = vals[0], bal = vals.at(-1);
      row.balance = bal;
      if (near(prev + x, bal)) { row.receipt = x; row.status = 'ok'; }
      else if (near(prev - x, bal)) { row.payment = x; row.status = 'ok'; }
      else {
        const delta = Math.round((bal - prev) * 100) / 100;
        row.why = 'sum_mismatch';
        row[delta >= 0 ? 'receipt' : 'payment'] = x; // as read; the person decides
        row.implied = Math.abs(delta);
      }
    } else { row.why = 'garbled'; row.receipt = null; row.payment = null; row.amount_read = vals[0]; }
    if (negative) { row.status = 'check'; row.why = 'negative_balance'; row.balance = row.balance != null ? -row.balance : null; }
    if (row.balance != null && row.status === 'ok') prev = row.balance;
    else if (row.balance != null && prev != null && row.why === 'sum_mismatch') prev = row.balance; // keep following the page's own balance
    rows.push(row);
  }
  return rows;
}

/** Several readings of one cash-book page, put together. For each row every figure any reading saw is a
 *  candidate; a row is 'ok' only when some reading's balance before it, plus or minus some reading's
 *  amount, gives exactly some reading's balance after it. Misreads rarely make a sum close by chance. */
export function mergeCashbookPasses(sets) {
  // rows are in page order: the reading with the most rows is the backbone; a reading with the same
  // number of rows lines up row by row, any other only where the date matches exactly
  const backbone = [...sets].sort((x, y) => y.length - x.length)[0] ?? [];
  const groups = backbone.map((r) => [r]);
  for (const rows of sets) {
    if (rows === backbone) continue;
    if (rows.length === backbone.length) rows.forEach((r, i) => groups[i].push(r));
    else rows.forEach((r) => { const i = backbone.findIndex((b) => b.date_bs === r.date_bs); if (i >= 0) groups[i].push(r); });
  }
  const cand = groups.map((rs) => {
    const bal = new Set(), amt = new Set();
    for (const r of rs) {
      if (r.balance != null) bal.add(r.balance);
      for (const v of [r.receipt, r.payment, r.amount_read]) if (v != null) amt.add(v);
    }
    const pick = (vals) => vals.filter(Boolean).sort((a, b) => vals.filter((x) => x === b).length - vals.filter((x) => x === a).length)[0] ?? null;
    const date_bs = pick(rs.map((r) => r.date_bs));
    return { rows: rs, bal: [...bal], amt: [...amt], particulars: pick(rs.map((r) => r.particulars)) ?? '', date_bs,
             date_ad: rs.find((r) => r.date_bs === date_bs)?.date_ad ?? null, dates_differ: new Set(rs.map((r) => r.date_bs)).size > 1 };
  });
  // walk the page: best path through balance candidates that closes the most rows
  const out = []; let prevSet = null;
  for (const c of cand) {
    const row = { date_bs: c.date_bs, date_ad: c.date_ad, particulars: c.particulars, receipt: null, payment: null, balance: null, status: 'check', why: 'sum_mismatch' };
    if (prevSet == null) {
      const open = c.bal.find((b) => c.amt.some((a) => near(a, b)));
      if (open != null) { Object.assign(row, { receipt: open, balance: open, opening: true, status: 'ok', why: null }); prevSet = [open]; }
      else { row.balance = c.bal[0] ?? null; prevSet = c.bal; }
      out.push(row); continue;
    }
    let hit = null;
    for (const p of prevSet) for (const b of c.bal) for (const a of c.amt) {
      if (!hit && near(p + a, b)) hit = { b, receipt: a };
      if (!hit && near(p - a, b)) hit = { b, payment: a };
    }
    if (hit) { Object.assign(row, { balance: hit.b, receipt: hit.receipt ?? null, payment: hit.payment ?? null, status: 'ok', why: null }); prevSet = [hit.b]; }
    else {
      const best = c.rows.find((r) => r.receipt != null || r.payment != null) ?? c.rows[0];
      // which column it was in is not known: the person says receipt or payment
      Object.assign(row, { balance: best.balance, amount_read: best.receipt ?? best.payment ?? best.amount_read ?? null, alts: { balances: c.bal, amounts: c.amt } });
      prevSet = c.bal.length ? c.bal : prevSet;
    }
    if (row.status === 'ok' && c.dates_differ) { row.status = 'check'; row.why = 'readings_differ'; }
    out.push(row);
  }
  return out;
}
