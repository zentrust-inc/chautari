// node --test reader/test/   — the reader's checks, without any photo or OCR
import test from 'node:test';
import assert from 'node:assert/strict';
import { normalizeDigits, amountsIn, parseDate, parseBill, reconcile, mergePasses, parseCashbook, mergeCashbookPasses, suggestHead } from '../parse.mjs';

const TODAY = '2026-11-19';

test('Devanagari digits become 0-9; a Latin 9 inside a Nepali number is १', () => {
  assert.equal(normalizeDigits('जम्मा रु. १६,१२५.१०'), 'जम्मा रु. 16,125.10');
  assert.equal(normalizeDigits('सदस्यता 9००'), 'सदस्यता 100');
  assert.equal(normalizeDigits('Total 950'), 'Total 950'); // all-Latin numbers are left alone
});

test('amounts with lakh grouping', () => {
  assert.deepEqual(amountsIn('कुल 1,10,740.00').map((a) => a.value), [110740]);
  assert.deepEqual(amountsIn('4 3,200 12,800').map((a) => a.value), [4, 3200, 12800]);
});

test('Bikram Sambat dates convert; impossible ones do not', () => {
  assert.deepEqual(parseDate('मिति: 2083/07/05'), { bs: '2083/07/05', ad: '2026-10-22', raw: '2083/07/05' });
  assert.ok(parseDate('2083/13/05').invalid);
  assert.equal(parseDate('2026-10-22').bs, '2083/07/05');
});

test('a bill\'s own sums repair a misread sub-total (VAT and total agree)', () => {
  const r = reconcile({ subtotal: 96000, vat: 12740, total: 110740 });
  assert.equal(r.subtotal, 98000);
  assert.deepEqual(r.repaired, ['subtotal']);
  assert.equal(r.total_ok, true);
});

test('figures that do not add up are never ok', () => {
  assert.equal(reconcile({ subtotal: 4222, vat: null, total: 222 }).total_ok, false);
});

const bill = (over = {}) => ({
  vendor: 'नमूना हार्डवेयर', pan: '100200301', bill_no: '0417', date: parseDate('2083/07/05'), method: 'cash',
  subtotal: 14270, vat: 1855.1, total: 16125.1, items: [], kind: 'expense', ...over,
});

test('agreeing readings with fitting sums are ok', () => {
  const m = mergePasses([bill(), bill(), bill()], { today: TODAY });
  assert.equal(m.fields.total.status, 'ok');
  assert.equal(m.fields.date_bs.status, 'ok');
  assert.equal(m.fields.bill_no.status, 'ok');
  assert.equal(m.fields.account_code.status, 'check'); // the head is always the person's choice
});

test('an identifier needs every reading to agree', () => {
  const m = mergePasses([bill(), bill(), bill({ bill_no: '7417', pan: '900200301' })], { today: TODAY });
  assert.equal(m.fields.bill_no.status, 'check');
  assert.deepEqual(m.fields.bill_no.alts, ['7417']);
  assert.equal(m.fields.pan.status, 'check');
});

test('a total whose items do not add up is not ok', () => {
  const items = [{ name: 'Petrol', qty: 6.5, rate: 88, amount: 222, computed: 572 }];
  const m = mergePasses([bill({ subtotal: 7222, vat: null, total: 7222, items }), bill({ subtotal: 7222, vat: null, total: 7222, items })], { today: TODAY });
  assert.equal(m.fields.total.status, 'check');
  assert.equal(m.fields.total.why, 'items_mismatch');
});

test('dates: one-digit day, future and old dates go to the person', () => {
  assert.equal(mergePasses([bill({ date: parseDate('2083/07/5') }), bill({ date: parseDate('2083/07/5') })], { today: TODAY }).fields.date_bs.why, 'short_date');
  assert.equal(mergePasses([bill({ date: parseDate('2083/09/05') }), bill({ date: parseDate('2083/09/05') })], { today: TODAY }).fields.date_bs.why, 'future_date');
  assert.equal(mergePasses([bill({ date: parseDate('2081/07/05') }), bill({ date: parseDate('2081/07/05') })], { today: TODAY }).fields.date_bs.why, 'old_date');
});

test('a PAN must have 9 digits', () => {
  const m = mergePasses([bill({ pan: '00200304' }), bill({ pan: '00200304' })], { today: TODAY });
  assert.equal(m.fields.pan.why, 'pan_length');
});

test('reading a whole bill from text', () => {
  const f = parseBill([
    'नमूना हार्डवेयर तथा निर्माण सामग्री', 'नुवाकोट बजार, नुवाकोट', 'करदाता दर्ता नं. (PAN): १००२००३०१',
    'बिल नं.: ०४१७ मिति: २०८३/०७/०५', '१ GI तार (बन्डल) ४ ३,२०० १२,८००', '२ किला (केजी) ५ १८० ९००',
    'उप-जम्मा: १३,७००', 'मू.अ.कर (१३%): १,७८१', 'भुक्तानी: नगद कुल जम्मा: १५,४८१']);
  assert.equal(f.vendor, 'नमूना हार्डवेयर तथा निर्माण सामग्री');
  assert.equal(f.pan, '100200301');
  assert.equal(f.bill_no, '0417');
  assert.equal(f.date.bs, '2083/07/05');
  assert.equal(f.total, 15481);
  assert.equal(f.subtotal, 13700);
  assert.equal(f.vat, 1781);
  assert.equal(f.method, 'cash');
  assert.equal(f.items.length, 2);
  assert.equal(reconcile(f).items_ok, true);
});

test('expense heads are suggested from the words on the bill', () => {
  assert.equal(suggestHead('नमूना चिया पसल', 'चिया (कप) समोसा').code, 'EX-1.02');
  assert.equal(suggestHead('Namuna Nursery', 'लप्सी बिरुवा').code, 'EX-2.02');
  assert.equal(suggestHead('???').code, null);
});

test('cash book: the running balance decides receipt or payment, and only a closing sum is ok', () => {
  const lines = ['2083/07/01 अघिल्लो बाँकी 5,000 5,000', '2083/07/02 सदस्यता 100 5,100', '2083/07/03 तार 1,000 4,100', '2083/07/04 चिया 750 9,999'];
  const rows = mergeCashbookPasses([parseCashbook(lines)]);
  assert.equal(rows[0].opening, true);
  assert.equal(rows[1].receipt, 100); assert.equal(rows[1].status, 'ok');
  assert.equal(rows[2].payment, 1000); assert.equal(rows[2].status, 'ok');
  assert.equal(rows[3].status, 'check'); assert.equal(rows[3].receipt, null); assert.equal(rows[3].payment, null);
});

test('cash book: a figure only one reading saw is suggested but goes to the person', () => {
  // two readers misreading the same digit the same way is what sums cannot catch, so a tick needs two readings
  const a = parseCashbook(['2083/07/01 बाँकी 5,000 5,000', '2083/07/02 तार 1,800 4,100']);
  const b = parseCashbook(['2083/07/01 बाँकी 5,000 5,000', '2083/07/02 तार 900 4,100']);
  const rows = mergeCashbookPasses([a, b]);
  assert.equal(rows[0].status, 'ok');
  assert.equal(rows[1].payment, 900);
  assert.equal(rows[1].status, 'check');
  assert.equal(rows[1].why, 'readings_differ');
});

test('cash book: two readings that agree get the tick', () => {
  const a = parseCashbook(['2083/07/01 बाँकी 5,000 5,000', '2083/07/02 तार 900 4,100']);
  const rows = mergeCashbookPasses([a, structuredClone(a)]);
  assert.equal(rows[1].payment, 900);
  assert.equal(rows[1].status, 'ok');
});

test('cash book: an opening balance the readings disagree on is not ticked', () => {
  const a = parseCashbook(['२०८३/९/७  अघिल्लो बाँकी  २१२३६  २१२३६']);
  const b = parseCashbook(['२०८३/९/७  अघिल्लो बाँकी  २९२३५  २९२३५']);
  const rows = mergeCashbookPasses([a, b]);
  assert.equal(rows[0].status, 'check');
});

test('cash book: "/-" closing a figure is not a minus sign', () => {
  const rows = parseCashbook(['२०८३/०८/०३  अघिल्लो बाँकी  ३१,२५०/-  ३१,२५०', '२०८३/०८/०४  सदस्यता शुल्क  ३००/-  ३१,५५०']);
  assert.equal(rows[0].balance, 31250); assert.equal(rows[0].status, 'ok');
  assert.equal(rows[1].receipt, 300); assert.equal(rows[1].balance, 31550); assert.equal(rows[1].status, 'ok');
});

test('a cash balance below zero keeps its sign and is marked for the person', () => {
  const rows = parseCashbook(['2083/07/29 Timber sale 20,000 34,351', '2083/08/01 Cement 37,991 -3,640', '2083/08/02 Saplings 4,950 8,290']);
  const neg = rows.find((r) => r.date_bs === '2083/08/01');
  assert.equal(neg.status, 'check');
  assert.equal(neg.why, 'negative_balance');
  assert.equal(neg.balance, -3640);
});

test('cash book: an opening row whose date the readings disagree on is not ticked', () => {
  const a = parseCashbook(['२०८३/३/७  अघिल्लो बाँकी  २९२३५  २९२३५']);
  const b = parseCashbook(['२०८३/९/७  अघिल्लो बाँकी  २९२३५  २९२३५']);
  const rows = mergeCashbookPasses([a, structuredClone(a), b]);
  assert.equal(rows[0].status, 'check');
  assert.equal(rows[0].why, 'readings_differ');
});
