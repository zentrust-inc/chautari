// बिलको फोटोबाट हिसाब — a bill's photo becomes a suggested entry; a named person checks it against
// the photo and confirms it in their own name. The reader (our own server) only suggests.
import { useEffect, useMemo, useState } from 'preact/hooks';
import NepaliDate from 'nepali-date-converter';
import { lang, roleName } from '../lib/i18n';
import { rs, num, digits, fiscalYear } from '../lib/format';
import { me, officerRoles, pub, go } from '../state';
import { source, DemoWrite, type Reading, type BillCheck } from '../data/source';
import { Screen, Section, Pill } from '../ui';
import { Sent, type SentState } from './Tasks';

type Row = Record<string, any>;
const L = (np: string, en: string) => (lang.value === 'np' ? np : en);
export const READER_ROLES = ['treasurer', 'ledger_keeper'];

const WHY: Record<string, [string, string]> = {
  one_reading: ['एउटा मात्र पढाइ मिल्यो', 'only one reading agreed'],
  readings_differ: ['पढाइहरू फरक परे', 'the readings differ'],
  not_found: ['फोटोमा भेटिएन', 'not found in the photo'],
  sum_mismatch: ['जोड मिलेन', 'the figures do not add up'],
  items_mismatch: ['वस्तुको जोड मिलेन', 'the items do not add up'],
  pan_length: ['PAN ९ अङ्कको हुनुपर्छ', 'a PAN has 9 digits'],
  garbled: ['अङ्क अस्पष्ट', 'figure unclear'],
  repaired: ['बिलको जोडबाट सच्याइयो', 'corrected from the bill’s own sums'],
  from_parts: ['उप-जम्मा र कर जोडेर', 'worked out from sub-total + VAT'],
  future_date: ['मिति भविष्यको छ', 'the date is in the future'],
  old_date: ['मिति १ वर्षभन्दा पुरानो', 'the date is over a year old'],
  assumed: ['अनुमान मात्र', 'a guess'],
  invalid_date: ['मिति मिलेन', 'not a valid date'],
  short_date: ['महिना/दिन एक अङ्कको', 'one-digit month or day'],
};

function Status({ f }: { f?: { status: string; why?: string } }) {
  if (!f) return null;
  if (f.status === 'ok') return <Pill tone="good">✓ {L('पढियो', 'read')}</Pill>;
  const w = f.why && WHY[f.why];
  return <Pill tone="warn">! {L('जाँच्नुहोस्', 'check')}{w ? ` · ${L(w[0], w[1])}` : ''}</Pill>;
}

const bsToAd = (bs: string): string | null => {
  const m = /^(\d{4})[\/\-.](\d{1,2})[\/\-.](\d{1,2})$/.exec(bs.trim().replace(/[०-९]/g, (c) => String('०१२३४५६७८९'.indexOf(c))));
  if (!m) return null;
  try {
    const nd = new NepaliDate(+m[1], +m[2] - 1, +m[3]);
    if (nd.getMonth() !== +m[2] - 1 || nd.getDate() !== +m[3]) return null;
    const d = nd.toJsDate();
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
  } catch { return null; }
};

// the registered payee most like the name on the bill
function bestPayee(payees: Row[], vendor: string | null): string {
  if (!vendor) return '';
  const norm = (s: string) => s.replace(/\s+/g, '').toLowerCase();
  const v = norm(vendor);
  let best = '', score = 0;
  for (const p of payees) {
    const n = norm(p.name ?? '');
    if (!n) continue;
    if (n === v) return p.payee_id;
    const common = [...new Set(n)].filter((c) => v.includes(c)).length / Math.max(new Set(n).size, 1);
    if (common > score) { score = common; best = p.payee_id; }
  }
  return score >= 0.8 ? best : '';
}

export function Capture() {
  const roles = officerRoles.value.filter((r) => READER_ROLES.includes(r.role));
  const entities = [...new Set(roles.map((r) => r.entity))];
  const [picked, setEntity] = useState('');
  // the person may load after the first render (sign-in, or opening #capture directly)
  const entity = entities.includes(picked) ? picked : entities[0] ?? '';
  const [samples, setSamples] = useState<Reading[]>([]);
  const [waiting, setWaiting] = useState<Reading[]>([]);
  const [payees, setPayees] = useState<Row[]>([]);
  const [reading, setReading] = useState<Reading | null>(null);
  const [photo, setPhoto] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    if (source.sampleReadings) source.sampleReadings().then((d) => setSamples(d.bills));
  }, []);
  useEffect(() => { if (entity) source.officerPayees(entity).then(setPayees).catch(() => setPayees([])); }, [entity]);
  // bills the reader has already read on our server, waiting for a person (live only)
  const loadWaiting = () => { if (entity && source.waitingBills) source.waitingBills(entity).then(setWaiting).catch(() => setWaiting([])); };
  useEffect(loadWaiting, [entity, me.value?.id]);

  if (!me.value || !roles.length) {
    return <Screen title={L('बिलको फोटोबाट हिसाब', 'From a bill’s photo')}>
      <p class="empty">{L('यो काम कोषाध्यक्ष वा लेखापालको हो। नमुनामा "मेरो" मा गीता (लेखापाल) वा हरि (कोषाध्यक्ष) छान्नुहोस्।',
        'This is for the treasurer or ledger keeper. In the sample, choose गीता (ledger keeper) or हरि (treasurer) under Mine.')}</p>
      <button class="btn" onClick={() => go('mine')}>{L('मेरो खोल्नुहोस्', 'Open Mine')}</button>
    </Screen>;
  }

  const onPhoto = async (file: File | undefined) => {
    if (!file) return;
    setErr(null); setReading(null);
    setPhoto(URL.createObjectURL(file));
    if (source.mode === 'sample' || !source.readBill) {
      setErr(L('नमुनामा बिल पढ्ने काम जोडिएको छैन; यो हाम्रै सर्भरमा चल्छ। तलका नमुना बिलमध्ये एउटा छान्नुहोस्।',
        'In the sample the reader is not connected; it runs on our own server. Choose one of the sample bills below.'));
      return;
    }
    setBusy(true);
    try { setReading(await source.readBill(entity, file)); }
    catch (e) { setErr((e as Error).message); }
    finally { setBusy(false); }
  };

  return (
    <Screen title={L('बिलको फोटोबाट हिसाब', 'From a bill’s photo')}>
      <p class="note">{L('एआईले बिल पढेर सुझाव दिन्छ। तपाईं फोटोसँग मिलाएर आफ्नै नाममा पुष्टि गर्नुहुन्छ। एआईले आफैं केही लेख्न, हस्ताक्षर गर्न वा बदल्न सक्दैन।',
        'The AI reads the bill and suggests. You check it against the photo and confirm in your own name. The AI cannot record, sign or change anything itself.')}</p>
      {entities.length > 1 && (
        <div class="form"><label for="cap-entity">{L('कुन संस्थाको?', 'Which body?')}</label>
          <select id="cap-entity" value={entity} onChange={(e) => { setEntity((e.target as HTMLSelectElement).value); setReading(null); }}>
            {entities.map((e) => <option key={e} value={e}>{pub.value?.bodies.find((b) => b.id === e)?.name_np ?? e}</option>)}
          </select></div>
      )}

      {!reading && (
        <Section title={L('१. बिलको फोटो', '1. Photo of the bill')}>
          <label class="btn btn-wide photo-btn">
            {busy ? L('पढ्दैछ…', 'Reading…') : L('फोटो खिच्नुहोस् वा छान्नुहोस्', 'Take or choose a photo')}
            <input type="file" accept="image/*" capture="environment" hidden onChange={(e) => onPhoto((e.target as HTMLInputElement).files?.[0])} />
          </label>
          <p class="item-meta">{L('पूरा बिल देखिने गरी, उज्यालोमा, सिधा माथिबाट खिच्नुहोस्।', 'The whole bill, in good light, straight from above.')}</p>
          {photo && <img class="bill-photo" src={photo} alt="" />}
          {err && <p class="sent error">{err}</p>}
          {waiting.length > 0 && <>
            <h3 class="sub">{L('पढिसकेका, पुष्टि पर्खँदै', 'Already read, waiting for you')} ({num(waiting.length)})</h3>
            <div class="sample-bills">
              {waiting.map((b) => (
                <button key={b.suggestion_id} class="sample-bill" onClick={() => { setErr(null); setPhoto(null); setReading(b); }}>
                  {b.image && <img src={b.image} alt="" />}
                  <span>{b.label ?? L('बिल', 'bill')}</span>
                  {b.fields.total?.value != null && <span class="item-meta">{rs(b.fields.total.value)}</span>}
                  {(b.checks ?? []).length > 0 && <Pill tone={(b.checks ?? []).some((c) => c.block) ? 'bad' : 'warn'}>! {num((b.checks ?? []).length)} {L('जाँच', 'checks')}</Pill>}
                </button>
              ))}
            </div>
          </>}
          {samples.length > 0 && <>
            <h3 class="sub">{L('नमुना बिल (काल्पनिक) — एआईले साँच्चै पढेको नतिजा', 'Sample bills (fictional) — what the AI really read')}</h3>
            <div class="sample-bills">
              {samples.map((b) => (
                <button key={b.id} class="sample-bill" onClick={() => { setErr(null); setPhoto(null); setReading(b); }}>
                  <img src={b.image} alt="" />
                  <span>{b.label}</span>
                  <span class="item-meta">{b.quality === 'clean' ? L('सफा फोटो', 'clear photo') : b.quality === 'phone' ? L('साधारण फोटो', 'ordinary photo') : L('धमिलो फोटो', 'poor photo')}</span>
                </button>
              ))}
            </div>
          </>}
        </Section>
      )}

      {reading && <Review key={reading.doc.sha256} entity={entity} reading={reading} photo={reading.image ?? photo} payees={payees}
        onDone={() => { setReading(null); setPhoto(null); loadWaiting(); }} />}
    </Screen>
  );
}

function Review({ entity, reading, photo, payees, onDone }: { entity: string; reading: Reading; photo: string | null; payees: Row[]; onDone: () => void }) {
  const f = reading.fields;
  const lines = (pub.value?.budget_status ?? []).filter((l) => l.entity_id === entity && l.fiscal_year === fiscalYear());
  const suggestedLine = lines.find((l) => l.account_code === f.account_code?.value)?.line_id ?? '';
  const income = f.kind?.value === 'income';

  // what the reader suggests, as a payload (kept to show what the person changed)
  const suggested = useMemo(() => ({
    amount: f.total?.value ?? null, account_code: f.account_code?.value ?? null, payee_id: bestPayee(payees, f.vendor?.value) || null,
    method: f.method?.value ?? null, budget_line_id: suggestedLine || null, memo_np: f.memo_np?.value ?? null,
    bill_no: f.bill_no?.value ?? null,
  }), [payees.length]);

  const [amount, setAmount] = useState(String(f.total?.value ?? ''));
  const [dateBs, setDateBs] = useState(f.date_bs?.value ?? '');
  const [billNo, setBillNo] = useState(f.bill_no?.value ?? '');
  const [payee, setPayee] = useState(suggested.payee_id ?? '');
  const [line, setLine] = useState(suggestedLine);
  const [method, setMethod] = useState(f.method?.value ?? 'cash');
  const [memo, setMemo] = useState(f.memo_np?.value ?? '');
  const [checked, setChecked] = useState(false);
  const [big, setBig] = useState(false);
  const [state, setState] = useState<SentState>(null);
  const [rejecting, setRejecting] = useState(false);
  const [reason, setReason] = useState('');
  const [checks, setChecks] = useState<BillCheck[]>(reading.checks ?? []);
  const [dupReason, setDupReason] = useState('');
  useEffect(() => { if (!payee && suggested.payee_id) setPayee(suggested.payee_id); }, [suggested.payee_id]);

  const ad = bsToAd(dateBs);
  const amt = Number(amount.replace(/,/g, ''));
  // the database's checks, re-run as the person fills in payee, bill number, amount and date
  useEffect(() => {
    const t = setTimeout(() => {
      source.checkBill(entity, reading, { payee_id: payee || null, bill_no: billNo ? String(billNo) : null, amount: amt || null }, ad)
        .then(setChecks).catch(() => { /* keep the last checks; the database checks again on confirm */ });
    }, 400);
    return () => clearTimeout(t);
  }, [payee, billNo, amount, dateBs]);
  const samePhoto = checks.some((c) => c.code === 'same_photo');
  const sameBill = checks.some((c) => c.code === 'same_bill');
  const lineRow = lines.find((l) => l.line_id === line);
  const account = lineRow?.account_code ?? f.account_code?.value ?? '';
  const problems = [
    !(amt > 0) && L('रकम लेख्नुहोस्', 'enter the amount'),
    !ad && L('मिति (जस्तै २०८३/०७/०५) लेख्नुहोस्', 'enter the date (e.g. 2083/07/05)'),
    !payee && L('दर्ता भएको पसल/भुक्तानी पाउने छान्नुहोस्', 'choose the registered payee'),
    !account && L('खर्च शीर्षक वा बजेट रेखा छान्नुहोस्', 'choose the budget line'),
    !memo.trim() && L('विवरण लेख्नुहोस्', 'write what it was for'),
    !checked && L('फोटोसँग मिलाएको पुष्टि गर्नुहोस्', 'confirm you compared it with the photo'),
    samePhoto && L('यही फोटो पहिले नै लेखिएको छ: "यो बिल नलिने" थिच्नुहोस्', 'this photo is already recorded: tap "Do not take this bill"'),
    sameBill && !dupReason.trim() && L('दोहोरिएको होइन भने कारण लेख्नुहोस्, नत्र "यो बिल नलिने"', 'say why it is not a duplicate, or tap "Do not take this bill"'),
  ].filter(Boolean) as string[];

  const confirm = async () => {
    const payload: Row = {
      expense_id: crypto.randomUUID(), amount: amt, account_code: account, payee_id: payee, method,
      ...(line ? { budget_line_id: line } : {}), memo_np: memo.trim(), ...(billNo ? { bill_no: String(billNo) } : {}),
      ...(sameBill && dupReason.trim() ? { duplicate_reason_np: dupReason.trim() } : {}),
    };
    try {
      const r = await source.confirmSuggestion(entity, { ...reading, suggested_payload: reading.suggested_payload ?? suggested, suggested_date: reading.suggested_date ?? f.date_ad?.value ?? null, current_checks: checks } as any,
        'expense.recorded', payload, ad!, fiscalYear(new Date(ad! + 'T12:00')));
      setState({ ok: true, seq: r.seq });
    } catch (e) {
      setState(e instanceof DemoWrite ? { demo: e.entry } : { error: (e as Error).message });
    }
  };
  const reject = async () => {
    try { await source.rejectSuggestion(reading, reason); setState({ ok: true, seq: 0 }); }
    catch (e) { setState(e instanceof DemoWrite ? { demo: e.entry } : { error: (e as Error).message }); }
  };

  return (
    <>
      <Section title={L('२. फोटोसँग मिलाउनुहोस्', '2. Compare with the photo')}
        note={L('✓ = दुई पटक पढ्दा मिल्यो र बिलको जोड मिल्यो। ! = तपाईंले फोटो हेरेर ठीक गर्नुहोस्।',
          '✓ = two readings agreed and the bill’s own sums fit. ! = look at the photo and put it right.')}>
        {photo && <img class={`bill-photo${big ? ' big' : ''}`} src={photo} alt={L('बिलको फोटो', 'photo of the bill')} onClick={() => setBig(!big)} />}
        <p class="item-meta">{L('फोटो थिचेर ठूलो/सानो पार्नुहोस्।', 'Tap the photo to enlarge it.')} {reading.id && <Pill tone="water">{L('नमुना बिल', 'sample bill')}</Pill>}</p>
        {reading.flags.length > 0 && (
          <div class="flags">
            <p class="item-title">{L('पहिले यी हेर्नुहोस्:', 'Look at these first:')}</p>
            <ul>{reading.flags.map((x, i) => <li key={i}>{fieldName(x.field)}: {L(x.np, x.en)}</li>)}</ul>
          </div>
        )}
        {income && <p class="sent error">{L('यो हामीले दिएको रसिद (आम्दानी) जस्तो देखिन्छ। आम्दानी "आम्दानी लेख्ने" बाटो हुँदै लेख्नुहोस्; यहाँ खर्च मात्र।',
          'This looks like a receipt we issued (income). Record income through the income entry; this screen is for spending.')}</p>}
      </Section>

      <Section title={L('३. इन्ट्री', '3. The entry')}>
        {state ? <>
          <Sent s={state} />
          {'demo' in state && <p class="item-meta">{L('"ai_read" ले सबैलाई देखाउँछ: एआईले पढ्यो, र व्यक्तिले कुन कुरा सच्यायो। फोटोको औँठाछाप (sha256) प्रमाण हो; फोटो हाम्रै सर्भरमा रहन्छ।',
            '"ai_read" shows everyone that the AI read it and what the person corrected. The photo’s fingerprint (sha256) is the evidence; the photo stays on our server.')}</p>}
          <button class="btn btn-quiet" onClick={onDone}>{L('अर्को बिल', 'Next bill')}</button>
        </> : (
          <form class="form" onSubmit={(e) => { e.preventDefault(); if (!problems.length) confirm(); }}>
            {checks.length > 0 && (
              <div class={`flags${checks.some((c) => c.block) ? ' flags-block' : ''}`}>
                <p class="item-title">{L('जाँच (दोहोरिएको बिल, मूल्यसूची):', 'Checks (duplicate bills, price list):')}</p>
                <ul>{checks.map((c, i) => <li key={i}>{c.block ? '✕ ' : '! '}{L(digits(c.np), c.en)}</li>)}</ul>
                <p class="item-meta">{L('! भएकोले रोक्दैन, तर पुष्टि गरेपछि लेखा समितिले देख्छ र सबैले जाँचको नाम देख्छन्।',
                  '! does not stop the entry, but once confirmed the accounts committee sees it and everyone sees which check it raised.')}</p>
              </div>
            )}
            {sameBill && (
              <div class="field field-check">
                <label for="dup">{L('यो दोहोरिएको होइन भने किन? (सबैले देख्छन्)', 'If it is not a duplicate, why? (everyone sees this)')}</label>
                <input id="dup" placeholder={L('जस्तै: दुई पानाको बिल, यो दोस्रो पाना', 'e.g. a two-page bill, this is page two')} value={dupReason}
                  onInput={(e) => setDupReason((e.target as HTMLInputElement).value)} />
              </div>
            )}
            <Field label={L('जम्मा रकम (रु)', 'Total (Rs)')} f={f.total} alts={f.total?.alts}>
              <input inputMode="decimal" value={amount} onInput={(e) => setAmount((e.target as HTMLInputElement).value)} />
            </Field>
            {(f.subtotal?.value != null || f.vat?.value != null) && (
              <p class="item-meta">{L('उप-जम्मा', 'Sub-total')} {f.subtotal?.value != null ? rs(f.subtotal.value) : '—'} <Status f={f.subtotal} /> · {L('मू.अ.कर', 'VAT')} {f.vat?.value != null ? rs(f.vat.value) : '—'} <Status f={f.vat} /></p>
            )}
            <Field label={L('बिलको मिति (वि.सं.)', 'Bill date (BS)')} f={f.date_bs} alts={f.date_bs?.alts}>
              <input value={dateBs} placeholder="2083/07/05" onInput={(e) => setDateBs((e.target as HTMLInputElement).value)} />
            </Field>
            <Field label={L('बिल नं.', 'Bill no.')} f={f.bill_no} alts={f.bill_no?.alts}>
              <input value={billNo} onInput={(e) => setBillNo((e.target as HTMLInputElement).value)} />
            </Field>
            <Field label={L('भुक्तानी पाउने (दर्ता भएको)', 'Payee (registered)')} f={f.vendor}>
              <p class="item-meta">{L('बिलमा:', 'On the bill:')} {f.vendor?.value ?? '—'}{f.pan?.value ? ` · PAN ${digits(f.pan.value)}` : ''} <Status f={f.pan} /></p>
              <select value={payee} onChange={(e) => setPayee((e.target as HTMLSelectElement).value)}>
                <option value="">{L('— छान्नुहोस् —', '— choose —')}</option>
                {payees.map((p) => <option key={p.payee_id} value={p.payee_id}>{p.name}</option>)}
              </select>
              <p class="item-meta">{L('सूचीमा छैन? पहिले सचिव, कोषाध्यक्ष वा लेखापालले पसल दर्ता गर्नुपर्छ; दर्ता नभएकालाई भुक्तानी हुँदैन।',
                'Not in the list? The shop must first be registered by the secretary, treasurer or ledger keeper; unregistered payees cannot be paid.')}</p>
            </Field>
            <Field label={L('बजेट रेखा', 'Budget line')} f={f.account_code} suggestion={f.account_code?.value ? L(`एआईको सुझाव: शीर्षक ${f.account_code.value}`, `AI suggests head ${f.account_code.value}`) : undefined}>
              <select value={line} onChange={(e) => setLine((e.target as HTMLSelectElement).value)}>
                <option value="">{L('— बजेटबाहिर —', '— unbudgeted —')}</option>
                {lines.map((l) => <option key={l.line_id} value={l.line_id}>{l.title_np} ({l.account_code} · {L('बाँकी', 'left')} {rs(l.remaining)})</option>)}
              </select>
              {lineRow && amt > Number(lineRow.remaining) && <p class="sent error">{L('यो बजेट रेखामा बाँकीभन्दा बढी।', 'More than is left on this budget line.')}</p>}
            </Field>
            <Field label={L('भुक्तानी कसरी', 'Paid by')} f={f.method}>
              <select value={method} onChange={(e) => setMethod((e.target as HTMLSelectElement).value)}>
                <option value="cash">{L('नगद', 'cash')}</option><option value="bank">{L('बैंक', 'bank')}</option>
              </select>
            </Field>
            <Field label={L('के को लागि', 'What for')}>
              <input value={memo} onInput={(e) => setMemo((e.target as HTMLInputElement).value)} />
            </Field>
            {reading.items.length > 0 && (
              <details class="items-read"><summary>{L('बिलका वस्तु (एआईले पढेका)', 'Items on the bill (as read)')}</summary>
                <ul>{reading.items.map((i, k) => <li key={k}>{i.name}: {i.qty != null ? num(i.qty, i.qty % 1 ? 1 : 0) + ' × ' : ''}{i.rate != null ? num(i.rate) + ' = ' : ''}{rs(i.amount)}</li>)}</ul>
              </details>
            )}
            <label class="check-line"><input type="checkbox" checked={checked} onChange={(e) => setChecked((e.target as HTMLInputElement).checked)} />
              {L(' मैले रकम, मिति र पसल फोटोसँग मिलाएँ।', ' I compared the amount, date and shop with the photo.')}</label>
            {problems.length > 0 && <p class="item-meta">{L('बाँकी:', 'Still needed:')} {problems.join(' · ')}</p>}
            <button class="btn" type="submit" disabled={problems.length > 0}>
              {L(`मेरो नाममा पुष्टि गर्छु (${me.value?.name})`, `Confirm in my name (${me.value?.name})`)}
            </button>
            <p class="item-meta">{L('पुष्टि गर्दा खर्च "हस्ताक्षर पर्खँदै" मा जान्छ। भुक्तानी कोषाध्यक्ष र अध्यक्ष वा सचिवको हस्ताक्षरपछि मात्र। तपाईंले लेखेको खर्चमा तपाईं हस्ताक्षर गर्न पाउनुहुन्न।',
              'Confirming puts the expense under "waiting for signatures". It is paid only after the treasurer and the chair or secretary sign. You cannot sign an expense you recorded.')}</p>
            {!rejecting ? <button class="btn btn-quiet" type="button" onClick={() => setRejecting(true)}>{L('यो बिल नलिने', 'Do not take this bill')}</button> : (
              <div class="form">
                <label for="rej">{L('किन?', 'Why?')}</label>
                <select id="rej" value={reason} onChange={(e) => setReason((e.target as HTMLSelectElement).value)}>
                  <option value="">{L('— छान्नुहोस् —', '— choose —')}</option>
                  <option value="दोहोरिएको बिल (duplicate)">{L('दोहोरिएको बिल', 'a duplicate')}</option>
                  <option value="हाम्रो बिल होइन (not ours)">{L('हाम्रो बिल होइन', 'not our bill')}</option>
                  <option value="पढ्न नसकिने फोटो (unreadable)">{L('फोटो पढ्न सकिँदैन — फेरि खिच्छु', 'unreadable — I will take it again')}</option>
                </select>
                <button class="btn btn-quiet" type="button" disabled={!reason} onClick={reject}>{L('नलिने', 'Reject')}</button>
              </div>
            )}
          </form>
        )}
      </Section>
      <p class="item-meta">{L('पढ्ने:', 'Read by:')} {reading.reader} · {roleName('ledger_keeper')}/{roleName('treasurer')} {L('ले पुष्टि गर्छन्', 'confirm')}</p>
    </>
  );
}

function fieldName(k: string) {
  const n: Record<string, [string, string]> = {
    total: ['जम्मा', 'total'], subtotal: ['उप-जम्मा', 'sub-total'], vat: ['मू.अ.कर', 'VAT'], date_bs: ['मिति', 'date'],
    bill_no: ['बिल नं.', 'bill no.'], pan: ['PAN', 'PAN'], vendor: ['पसल', 'shop'], items: ['वस्तु', 'items'],
  };
  return n[k] ? L(n[k][0], n[k][1]) : k;
}

function Field({ label, f, alts, suggestion, children }: { label: string; f?: { status: string; why?: string }; alts?: any[]; suggestion?: string; children: any }) {
  return (
    <div class={`field${f?.status === 'check' ? ' field-check' : ''}`}>
      <div class="row-between"><label>{label}</label><Status f={f} /></div>
      {children}
      {alts && alts.length > 0 && <p class="item-meta">{L('अर्को पढाइ:', 'Another reading:')} {alts.map((a) => digits(String(a))).join(', ')}</p>}
      {suggestion && <p class="item-meta">{suggestion}</p>}
    </div>
  );
}
