import { useState } from 'preact/hooks';
import { t } from '../lib/i18n';
import { rs, num, sum, pct } from '../lib/format';
import { pub, byEntity, CFUG, me } from '../state';
import { Screen, Section, Stat, Pill, Meter } from '../ui';
import { PaymentRow, yearOf } from './Home';
import { source, DemoWrite } from '../data/source';
import { Sent, type SentState } from './Tasks';

export function Money({ entity = CFUG }: { entity?: string }) {
  const p = pub.value!;
  const money = byEntity(p.money_status, entity)[0];
  const led = byEntity(p.income_and_spending, entity);
  const fy = yearOf(led);
  const year = led.filter((r) => r.fiscal_year === fy);

  // totals by account head for the year (the view is by month)
  const heads = new Map<string, { name: string; kind: string; amount: number }>();
  for (const r of year) {
    const h = heads.get(r.account_code) ?? { name: r.name_np, kind: r.kind, amount: 0 };
    h.amount += Number(r.amount); heads.set(r.account_code, h);
  }
  const incomeHeads = [...heads.values()].filter((h) => h.kind === 'income').sort((a, b) => b.amount - a.amount);
  const spendHeads = [...heads.values()].filter((h) => h.kind === 'expense').sort((a, b) => b.amount - a.amount);
  const income = sum(incomeHeads, (h) => h.amount), spending = sum(spendHeads, (h) => h.amount);

  const budget = byEntity(p.budget_status, entity).filter((b) => b.fiscal_year === fy);
  const shares = byEntity(p.spending_shares, entity).find((s) => s.fiscal_year === fy);
  const payments = byEntity(p.payments, entity).sort((a, b) => b.voucher_no - a.voucher_no);

  return (
    <Screen title={t('money')}>
      <div class="stats">
        <Stat label={t('in_bank')} value={rs(money?.in_bank)} />
        <Stat label={t('cash')} value={rs(money?.cash_in_hand)} />
      </div>
      {(money?.cash_over_limit || money?.late_banking) && (
        <p class="flags">
          {money.cash_over_limit && <Pill tone="bad">{t('cash_over')}</Pill>}
          {money.late_banking && <Pill tone="bad">{t('late_bank')}</Pill>}
        </p>
      )}

      <Section title={`${fy}`}>
        <div class="two-col">
          <div>
            <h3>{t('income_year')}</h3>
            <p class="big">{rs(income)}</p>
            <ul class="mini">{incomeHeads.map((h) => <li key={h.name}><span>{h.name}</span><span>{rs(h.amount)}</span></li>)}</ul>
          </div>
          <div>
            <h3>{t('spending_year')}</h3>
            <p class="big">{rs(spending)}</p>
            <ul class="mini">{spendHeads.map((h) => <li key={h.name}><span>{h.name}</span><span>{rs(h.amount)}</span></li>)}</ul>
          </div>
        </div>
      </Section>

      {budget.length > 0 && (
        <Section title={t('budget')}>
          <ul class="list">
            {budget.map((b) => {
              const used = Number(b.spent) / Number(b.budget);
              return (
                <li class="item item-stack" key={b.line_id}>
                  <div class="row-between"><span class="item-title">{b.title_np}</span><span class="item-amount">{rs(b.budget)}</span></div>
                  <Meter value={Number(b.spent)} max={Number(b.budget)} tone={used > 0.9 ? 'warn' : 'accent'} />
                  <span class="item-meta">{t('spent')} {rs(b.spent)} · {t('left')} {rs(b.remaining)} · {b.decision_ref}</span>
                </li>
              );
            })}
          </ul>
        </Section>
      )}

      {shares && (
        <Section title={t('shares_rule')} note="वन ऐन दफा २२; विधान दफा १५">
          <ShareMeter label={t('forest_share')} spent={+shares.forest_spent} need={+shares.forest_required} />
          <ShareMeter label={t('poor_share')} spent={+shares.pro_poor_spent} need={+shares.pro_poor_required} />
        </Section>
      )}

      <Section title={t('all_payments')}>
        <ul class="list">{payments.map((x) => <PaymentRow key={x.voucher_no} x={x} action={<Ask entity={entity} voucher={x.voucher_no} />} />)}</ul>
      </Section>
    </Screen>
  );
}

function ShareMeter({ label, spent, need }: { label: string; spent: number; need: number }) {
  const ok = spent >= need;
  return (
    <div class="share">
      <div class="row-between"><span>{label}</span><Pill tone={ok ? 'good' : 'warn'}>{ok ? t('on_track') : t('behind')}</Pill></div>
      <Meter value={spent} max={Math.max(spent, need) * 1.15} mark={need} tone={ok ? 'good' : 'warn'} />
      <span class="item-meta">{t('spent')} {rs(spent)} · {t('need')} {rs(need)}{need > 0 ? ` (${pct((spent / need) * 100)})` : ''}</span>
    </div>
  );
}

// Asking about an entry: the question goes to the accounts committee, and question and answer
// both stay on the record. The asker's name is seen only by the committee.
let seqs: Map<string, number> | null = null;
async function seqFor(entity: string, voucher: number) {
  if (!seqs) {
    seqs = new Map();
    for (const r of await source.chain()) {
      if (r.type === 'payment.released') {
        const v = JSON.parse(r.payload_text).voucher_no;
        seqs.set(`${r.entity_id}:${v}`, Number(r.seq));
      }
    }
  }
  return seqs.get(`${entity}:${voucher}`);
}
const uuid = () => (crypto as any).randomUUID?.() ??
  'xxxxxxxx-xxxx-4xxx-8xxx-xxxxxxxxxxxx'.replace(/x/g, () => ((Math.random() * 16) | 0).toString(16));

export function Ask({ entity, voucher }: { entity: string; voucher: number }) {
  const [open, setOpen] = useState(false);
  const [text, setText] = useState('');
  const [state, setState] = useState<SentState>(null);
  if (!me.value) return null;
  if (state) return <Sent s={state} />;
  if (!open) return <button class="text-btn" onClick={() => setOpen(true)}>{t('ask')}</button>;
  const send = async (e: Event) => {
    e.preventDefault();
    if (!text.trim()) return;
    try {
      const about = await seqFor(entity, voucher);
      const r = await source.record(entity, 'question.raised', { question_id: uuid(), about_seq: about }, { text_np: text.trim() });
      setState({ ok: true, seq: r.seq });
    } catch (err) {
      setState(err instanceof DemoWrite ? { demo: err.entry } : { error: (err as Error).message });
    }
  };
  return (
    <form class="ask" onSubmit={send}>
      <label for={`ask-${entity}-${voucher}`} class="sr">{t('ask_ph')}</label>
      <textarea id={`ask-${entity}-${voucher}`} rows={2} placeholder={t('ask_ph')} value={text}
        onInput={(e) => setText((e.target as HTMLTextAreaElement).value)} />
      <div class="row-gap">
        <button class="btn" type="submit">{t('send')}</button>
        <button class="btn btn-quiet" type="button" onClick={() => setOpen(false)}>{t('cancel')}</button>
      </div>
    </form>
  );
}

