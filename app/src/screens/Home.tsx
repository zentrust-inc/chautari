import { lang, t } from '../lib/i18n';
import { rs, num, sum, bsShort, digits, fiscalYear, hours, monthRange } from '../lib/format';
import { pub, byEntity, CFUG, go, chainReport } from '../state';
import { Glyph, Pill } from '../ui';
import { springTrends } from './Nature';
import { watchList } from './Decisions';
import { source } from '../data/source';

export function yearOf(rows: Record<string, any>[]) {
  const fys = [...new Set(rows.map((r) => r.fiscal_year).filter(Boolean))].sort();
  return fys[fys.length - 1] ?? fiscalYear();
}

export function Home() {
  const p = pub.value!;
  const body = p.bodies.find((b) => b.id === CFUG);
  const money = byEntity(p.money_status, CFUG)[0];
  const led = byEntity(p.income_and_spending, CFUG);
  const fy = yearOf(led);
  const income = sum(led.filter((r) => r.kind === 'income' && r.fiscal_year === fy), (r) => r.amount);
  const spending = sum(led.filter((r) => r.kind === 'expense' && r.fiscal_year === fy), (r) => r.amount);

  const turns = byEntity(p.fair_turns, CFUG);
  const lastMonth = turns.map((r) => r.month).sort().pop();
  const monthTurns = turns.filter((r) => r.month === lastMonth);
  const worked = monthTurns.filter((r) => Number(r.paid_hours) > 0).length;
  const monthHours = sum(monthTurns, (r) => r.paid_hours);

  const spring = springTrends(byEntity(p.nature_readings, CFUG))[0];
  const openQs = byEntity(p.questions, CFUG).filter((q) => q.status === 'open').length;
  const watch = watchList(p, CFUG);
  const payments = byEntity(p.payments, CFUG).filter((x) => x.status === 'paid')
    .sort((a, b) => b.voucher_no - a.voucher_no).slice(0, 3);
  const rep = chainReport.value;

  return (
    <main class="screen home">
      <header class="hero">
        <p class="eyebrow">{body?.ward_name_np}</p>
        <h1 class="hero-title">{lang.value === 'np' ? body?.name_np : body?.name_en}</h1>
        {source.mode === 'sample' && <p class="sample-line"><Pill tone="warn">{t('sample')}</Pill> {t('sample_note')}</p>}
        <button class={`chain-strip ${rep ? (rep.every((r) => r.ok) ? 'ok' : 'bad') : ''}`} onClick={() => go('check')}>
          <span class="seal" aria-hidden="true" />
          {rep ? (rep.every((r) => r.ok)
            ? <>{t('chain_ok')} · {num(sum(rep, (r) => r.entries))} {t('entries')}</>
            : t('chain_bad')) : t('chain_checking')}
        </button>
      </header>

      <div class="tiles">
        <button class="tile tile-money" onClick={() => go('money')}>
          <span class="tile-head"><Glyph name="money" />{t('money')}</span>
          <span class="tile-figure">{rs(Number(money?.in_bank) + Number(money?.cash_in_hand))}</span>
          <span class="tile-sub">{t('income_year')} {rs(income)} · {t('spent')} {rs(spending)}</span>
          {money?.payments_waiting > 0 && <Pill tone="warn">{num(money.payments_waiting)} {t('payments_waiting')}</Pill>}
        </button>
        <button class="tile tile-work" onClick={() => go('work')}>
          <span class="tile-head"><Glyph name="work" />{t('work')}</span>
          <span class="tile-figure">{num(worked)} <small>/ {num(monthTurns.length)}</small></span>
          <span class="tile-sub">{t('households_worked')}{lastMonth ? ` (${monthRange(lastMonth)})` : ''} · {hours(monthHours)}</span>
        </button>
        <button class="tile tile-nature" onClick={() => go('nature')}>
          <span class="tile-head"><Glyph name="nature" />{t('nature')}</span>
          {spring ? <>
            <span class="tile-figure">{num(spring.last, 1)} <small>{t('lpm')}</small></span>
            <span class="tile-sub">{spring.site} · {t(spring.trend)} {spring.change !== 0 && `(${digits(Math.abs(Math.round(spring.change)))}%)`}</span>
          </> : <span class="tile-sub">—</span>}
          {spring?.trend === 'falling' && <Pill tone="water">{t('falling')}</Pill>}
        </button>
        <button class="tile tile-decisions" onClick={() => go('decisions')}>
          <span class="tile-head"><Glyph name="decisions" />{t('decisions')}</span>
          <span class="tile-figure">{num(openQs)} <small>{t('open_questions')}</small></span>
          <span class="tile-sub">{watch.length ? `${t('watch')}: ${num(watch.length)}` : t('nothing_to_watch')}</span>
        </button>
      </div>

      <section class="section">
        <div class="row-between"><h2>{t('recent_payments')}</h2><a href="#money" class="link">{t('all_payments')} →</a></div>
        <ul class="list">{payments.map((x) => <PaymentRow key={x.voucher_no} x={x} />)}</ul>
      </section>

      <button class="coop-link" onClick={() => go('coop')}>
        <Glyph name="coop" />
        <span><strong>{p.bodies.find((b) => b.kind === 'mpc')?.name_np}</strong><br /><small>{t('sample')} · {t('coop')}</small></span>
        <span aria-hidden="true">→</span>
      </button>
    </main>
  );
}

export function PaymentRow({ x, action }: { x: Record<string, any>; action?: preact.ComponentChildren }) {
  return (
    <li class="item">
      <div class="item-main">
        <span class="item-title">{x.memo_np}</span>
        <span class="item-meta">{t('voucher')} {num(x.voucher_no)} · {bsShort(x.paid_on)} · {x.head_np}</span>
        <span class="item-meta">{x.payee_name ?? t('person_hidden')}{x.estimated ? ` · ${t('estimated')}` : ''}</span>
        {action}
      </div>
      <span class={`item-amount ${x.status === 'reversed' ? 'struck' : ''}`}>{rs(x.amount)}</span>
    </li>
  );
}
