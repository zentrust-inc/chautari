import { useEffect, useState } from 'preact/hooks';
import { lang, t, roleName, type Key } from '../lib/i18n';
import { rs, num, hours, bsDate, bsShort, monthRange } from '../lib/format';
import { me, MPC, loadAll } from '../state';
import { DemoWrite } from '../data/source';
import { Sent, type SentState } from './Tasks';
import { source } from '../data/source';
import { Screen, Section, Stat, Pill, Meter } from '../ui';

type Row = Record<string, any>;

export function Mine() {
  if (!me.value) return <SignIn />;
  return <MyRecord />;
}

function SignIn() {
  const [phone, setPhone] = useState('');
  const [code, setCode] = useState('');
  const [sent, setSent] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  if (source.mode === 'sample') {
    const people = source.samplePeople!();
    return (
      <Screen title={t('mine')} back={false}>
        <p class="banner"><Pill tone="warn">{t('sample')}</Pill> {t('sample_note')}</p>
        <Section title={t('pick_person')}>
          <ul class="people">
            {people.map((p) => (
              <li key={p.id}>
                <button class="person" onClick={async () => { source.signInAs!(p.id); await loadAll(); }}>
                  <span class="person-name">{p.name}</span>
                  <span class="item-meta">{t('house')} {num(p.house_no ?? 0)}{p.roles.length ? ' · ' + [...new Set(p.roles.map((r) => roleName(r.role)))].join(', ') : ''}</span>
                </button>
              </li>
            ))}
          </ul>
        </Section>
      </Screen>
    );
  }

  const submit = async (e: Event) => {
    e.preventDefault(); setErr(null);
    try {
      if (!sent) { await source.sendCode!(phone); setSent(true); }
      else { await source.verifyCode!(phone, code); await loadAll(); }
    } catch (x) { setErr((x as Error).message); }
  };
  return (
    <Screen title={t('sign_in')} back={false}>
      <form class="form" onSubmit={submit}>
        <label for="phone">{t('phone')}</label>
        <input id="phone" type="tel" inputMode="numeric" autoComplete="tel" placeholder="98XXXXXXXX" value={phone}
          onInput={(e) => setPhone((e.target as HTMLInputElement).value)} disabled={sent} />
        {sent && <>
          <label for="otp">{t('code')}</label>
          <input id="otp" inputMode="numeric" autoComplete="one-time-code" value={code} onInput={(e) => setCode((e.target as HTMLInputElement).value)} />
        </>}
        {err && <p class="error">{err}</p>}
        <button class="btn btn-wide" type="submit">{sent ? t('verify') : t('send_code')}</button>
      </form>
    </Screen>
  );
}

function MyRecord() {
  const [rec, setRec] = useState<Row | null>(null);
  const [acct, setAcct] = useState<Row | null>(null);
  const [tab, setTab] = useState<'cfug' | 'mpc'>('cfug');
  useEffect(() => { source.myRecord().then(setRec); source.myAccount(MPC).then(setAcct); }, [me.value?.id]);
  const person = me.value!;

  return (
    <Screen title={person.name} back={false}>
      <div class="row-between">
        <span class="item-meta">{t('house')} {num(person.house_no ?? 0)}{person.roles.length ? ' · ' + [...new Set(person.roles.map((r) => roleName(r.role)))].join(', ') : ''}</span>
        <button class="text-btn" onClick={async () => { await source.signOut(); me.value = null; }}>{t('sign_out')}</button>
      </div>
      <div class="tabs" role="tablist">
        <button role="tab" aria-selected={tab === 'cfug'} class={tab === 'cfug' ? 'on' : ''} onClick={() => setTab('cfug')}>{t('cfug_record')}</button>
        <button role="tab" aria-selected={tab === 'mpc'} class={tab === 'mpc' ? 'on' : ''} onClick={() => setTab('mpc')}>{t('my_account')}</button>
      </div>
      {tab === 'cfug' ? (rec ? <CfugRecord r={rec} /> : <p class="empty">{t('loading')}</p>)
        : (acct ? <Account a={acct} /> : <p class="empty">{t('loading')}</p>)}
    </Screen>
  );
}

function CfugRecord({ r }: { r: Row }) {
  const work = (r.work as Row[]);
  return (
    <>
      <Section title={t('my_work')}>
        <ul class="list">
          {work.map((w, i) => (
            <li class="item" key={i}>
              <div class="item-main"><span class="item-title">{w.project}{w.task_np && w.task_np !== w.project ? `: ${w.task_np}` : ''}</span><span class="item-meta">{bsDate(w.date)}</span></div>
              <span class="item-amount">{hours(w.hours)} {w.status === 'pending' && <Pill tone="warn">{t('pending_hours')}</Pill>}</span>
            </li>
          ))}
        </ul>
      </Section>
      {r.payments_to_me.length > 0 && (
        <Section title={t('paid_to_me')}>
          <ul class="list">{(r.payments_to_me as Row[]).map((x, i) => (
            <li class="item" key={i}><div class="item-main"><span class="item-title">{x.memo_np}</span></div><span class="item-amount">{rs(x.amount)}</span></li>
          ))}</ul>
        </Section>
      )}
      {r.household_turns.length > 0 && (
        <Section title={t('household_turns')}>
          <ul class="mini">{(r.household_turns as Row[]).map((h, i) => (
            <li key={i}><span>{monthRange(h.month)}</span><span>{hours(h.paid_hours)}{h.declined > 0 ? ` · ${num(h.declined)} ${t('declined')}` : ''}</span></li>
          ))}</ul>
        </Section>
      )}
      {r.parma.length > 0 && (
        <Section title={t('parma')}>
          <ul class="mini">{(r.parma as Row[]).map((x, i) => (
            <li key={i}><span>{t('house')} {num(x.other_house_no)}</span><span>{t('we_helped')} {num(x.days_we_helped ?? 0, 1)} · {t('they_helped')} {num(x.days_they_helped ?? 0, 1)} {t('days')}</span></li>
          ))}</ul>
        </Section>
      )}
      {r.my_questions.length > 0 && (
        <Section title={t('my_questions')}>
          <ul class="mini">{(r.my_questions as Row[]).map((q) => (
            <li key={q.id}><span>{lang.value === 'np' ? 'इन्ट्री नं.' : 'Entry'} {num(q.about_seq)}</span>
              <Pill tone={q.status === 'open' ? 'warn' : 'good'}>{q.status === 'open' ? t('open') : t(q.outcome as Key)}</Pill></li>
          ))}</ul>
        </Section>
      )}
    </>
  );
}

const KIND: Record<string, Key> = { shares_bought: 'k_shares_bought', shares_refunded: 'k_shares_refunded', wages: 'k_wages',
  payment: 'k_payment', benefit: 'k_benefit', loan_given: 'k_loan_given', loan_repaid: 'k_loan_repaid', loan_notice: 'k_loan_notice' };

// मेरो खाता — like a bank app: one balance, then what it is made of, then every line with its voucher.
function Account({ a }: { a: Row }) {
  if (!a.member) return <p class="empty">{t('not_member')}</p>;
  const est = a.benefit_estimate;
  const minH = Number(est.active_min_hours);
  const active = Number(est.my_hours) >= minH;
  return (
    <>
      <p class="banner">{source.mode === 'sample' && <><Pill tone="warn">{t('sample')}</Pill> </>}{t('coop_note')}</p>
      <div class="balance">
        <span class="stat-label">{t('my_money')}</span>
        <span class="balance-figure">{rs(a.my_money)}</span>
        <span class="item-meta">{lang.value === 'np' ? 'सदस्य नं.' : 'Member no.'} {num(a.member_no)} · {bsDate(a.since)} {lang.value === 'np' ? 'देखि' : ''}</span>
      </div>
      <div class="stats">
        <Stat label={t('shares')} value={rs(a.shares.value)} sub={`${num(a.shares.kitta)} ${t('kitta')}`} />
        <Stat label={t('loan_to_coop')} value={rs(a.loans_outstanding)} sub={a.loans[0] ? `${t('rate')} ${num(a.loans[0].rate_pct)}%` : undefined} />
        <Stat label={t('wages')} value={rs(a.work.wages_paid)} sub={`${hours(a.work.approved_paid_hours)} ${t('approved_hours')}`} />
        <Stat label={t('wages_due')} value={rs(a.work.wages_due)} sub={Number(a.work.pending_hours) ? `${hours(a.work.pending_hours)} ${t('pending_hours')}` : undefined} />
      </div>

      {(a.loans as Row[]).map((l) => <LoanCard key={l.loan_id} l={l} />)}

      <Section title={t('benefit_est')} note={t('benefit_note')}>
        <p class="big">{rs(est.my_share)}</p>
        <Meter value={Number(est.my_hours)} max={minH} tone={active ? 'good' : 'warn'} />
        <p class="item-meta">{t('active_hours')} {hours(minH)}: {hours(est.my_hours)}
          {!active && (lang.value === 'np' ? ` — यो नपुगे वर्षान्तमा लाभ पाइँदैन।` : ` — below this, no benefit at year end.`)}</p>
      </Section>

      <Section title={t('statement')}>
        <ul class="list">
          {(a.statement as Row[]).map((s) => (
            <li class="item" key={s.seq}>
              <div class="item-main">
                <span class="item-title">{t(KIND[s.kind] ?? 'k_payment')}{s.kitta ? ` · ${num(s.kitta)} ${t('kitta')}` : ''}{s.hours ? ` · ${hours(s.hours)}` : ''}</span>
                <span class="item-meta">{bsShort(s.date)}{s.voucher_no != null ? ` · ${t('voucher')} ${num(s.voucher_no)}` : ''}{s.interest ? ` · ${t('interest_paid')} ${rs(s.interest)}` : ''}{s.repay_from ? ` · ${t('repay_from')} ${bsDate(s.repay_from)}` : ''}</span>
              </div>
              <span class={`item-amount ${s.direction === 'to_me' ? 'in' : s.direction === 'note' ? 'muted' : ''}`}>{s.direction === 'to_me' ? '+' : ''}{rs(s.amount)}</span>
            </li>
          ))}
        </ul>
      </Section>
    </>
  );
}

// A member's project loan (bylaws v4.15 s.8): one rate for everyone; up to Rs 1 lakh comes back
// on 3 months' notice given here in चौतारी; above that the term is fixed.
function LoanCard({ l }: { l: Row }) {
  const [open, setOpen] = useState(false);
  const [amount, setAmount] = useState(String(l.outstanding));
  const [state, setState] = useState<SentState>(null);
  const np = lang.value === 'np';
  const give = async (e: Event) => {
    e.preventDefault();
    try {
      const r = await source.record(MPC, 'loan.notice_given', { loan_id: l.loan_id, amount: Number(amount) });
      setState({ ok: true, seq: r.seq });
    } catch (err) { setState(err instanceof DemoWrite ? { demo: err.entry } : { error: (err as Error).message }); }
  };
  return (
    <Section title={t('loan_to_coop')} note={l.withdrawal === 'notice' ? t('notice_rule') : t('fixed_rule')}>
      <div class="task">
        <div class="row-between"><span class="item-title">{rs(l.outstanding)}</span><Pill tone="neutral">{t('rate')} {num(l.rate_pct)}%</Pill></div>
        <p class="item-meta">{rs(l.amount)} · {bsDate(l.received_on)} · {l.withdrawal === 'notice' ? t('on_notice') : `${t('fixed_term')} ${num(l.term_months)} ${np ? 'महिना' : 'months'}`}
          {l.interest_paid > 0 ? ` · ${t('interest_paid')} ${rs(l.interest_paid)}` : ''}</p>
        {l.withdrawal === 'fixed' && l.term_ends_on && <p class="item-meta">{t('term_ends')}: <strong>{bsDate(l.term_ends_on)}</strong></p>}
        {l.notice_given_on && (
          <p class="sent ok">{t('notice_given')} {bsDate(l.notice_given_on)} · {t('repay_from')}: <strong>{bsDate(l.repay_due_on)}</strong></p>
        )}
        {l.withdrawal === 'notice' && !l.notice_given_on && (state ? <Sent s={state} /> : !open
          ? <button class="btn btn-quiet" onClick={() => setOpen(true)}>{t('give_notice')}</button>
          : (
            <form class="form" onSubmit={give}>
              <label for={`notice-${l.loan_id}`}>{t('notice_amount')}</label>
              <input id={`notice-${l.loan_id}`} inputMode="numeric" value={amount} onInput={(e) => setAmount((e.target as HTMLInputElement).value)} />
              <div class="row-gap">
                <button class="btn" type="submit">{t('give_notice')}</button>
                <button class="btn btn-quiet" type="button" onClick={() => setOpen(false)}>{t('cancel')}</button>
              </div>
            </form>
          ))}
      </div>
    </Section>
  );
}
