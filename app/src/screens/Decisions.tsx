import { lang, t, roleName, type Key } from '../lib/i18n';
import { num, rs, bsDate, digits } from '../lib/format';
import { pub, byEntity, CFUG } from '../state';
import { Screen, Section, Pill } from '../ui';
import type { Pub } from '../data/source';
import { springTrends } from './Nature';
import { yearOf } from './Home';

// What the published figures say needs the assembly's attention. These follow the rules'
// own thresholds (PRD v0.3, "Changing the rules"); the OS shows them, people decide.
export function watchList(p: Pub, entity: string): { text: string; tone: 'warn' | 'bad' | 'water' }[] {
  const np = lang.value === 'np';
  const out: { text: string; tone: 'warn' | 'bad' | 'water' }[] = [];
  const fy = yearOf(byEntity(p.income_and_spending, entity));
  const sh = byEntity(p.spending_shares, entity).find((s) => s.fiscal_year === fy);
  if (sh && +sh.pro_poor_spent < +sh.pro_poor_required)
    out.push({ tone: 'warn', text: np
      ? `विपन्न, महिला र उद्यममा ${rs(sh.pro_poor_spent)} खर्च भयो; वर्षभरिमा ${rs(sh.pro_poor_required)} चाहिन्छ।`
      : `${rs(sh.pro_poor_spent)} spent on poor households, women and enterprise; ${rs(sh.pro_poor_required)} needed this year.` });
  if (sh && +sh.forest_spent < +sh.forest_required)
    out.push({ tone: 'warn', text: np ? `वन काममा ${rs(sh.forest_spent)} मात्र; ${rs(sh.forest_required)} चाहिन्छ।` : `Only ${rs(sh.forest_spent)} on forest work; ${rs(sh.forest_required)} needed.` });
  for (const s of springTrends(byEntity(p.nature_readings, entity)).filter((s) => s.trend === 'falling'))
    out.push({ tone: 'water', text: np
      ? `${s.site} को पानी ${digits(Math.abs(Math.round(s.change)))}% घट्यो (${num(s.first, 1)} → ${num(s.last, 1)} लि/मि)।`
      : `${s.site} spring is down ${Math.abs(Math.round(s.change))}% (${s.first} → ${s.last} L/min).` });
  const m = byEntity(p.money_status, entity)[0];
  if (m?.cash_over_limit) out.push({ tone: 'bad', text: np ? 'हातमा नगद सीमाभन्दा बढी छ।' : 'Cash in hand is over the limit.' });
  if (m?.late_banking) out.push({ tone: 'bad', text: np ? 'नगद ७ दिनभित्र बैंकमा जम्मा भएन।' : 'Cash was not banked within 7 days.' });
  const old = byEntity(p.questions, entity).filter((q) => q.status === 'open' && q.asked_on &&
    (Date.now() - new Date(q.asked_on).getTime()) / 864e5 > 30);
  if (old.length) out.push({ tone: 'warn', text: np ? `${num(old.length)} प्रश्नको जवाफ ३० दिनभित्र आएन।` : `${old.length} questions unanswered after 30 days.` });
  return out;
}

export function Decisions() {
  const p = pub.value!;
  const watch = watchList(p, CFUG);
  const qs = byEntity(p.questions, CFUG).sort((a, b) => (a.asked_on < b.asked_on ? 1 : -1));
  const rules = byEntity(p.rules, CFUG).filter((r) => !['share_price', 'min_shares', 'max_shares', 'loan_rate_cap', 'member_loan_rate', 'notice_loan_max',
    'notice_days', 'fixed_term_min_months', 'fixed_term_max_months', 'reserve_pct', 'promotion_pct', 'split_community_pct',
    'split_member_pct', 'active_min_hours'].includes(r.key));
  const officers = byEntity(p.office_holders, CFUG);
  const prices = byEntity(p.price_list ?? [], CFUG);

  return (
    <Screen title={t('decisions')}>
      <Section title={t('watch')} note={lang.value === 'np' ? 'प्रणालीले देखाउँछ; निर्णय साधारण सभाले गर्छ।' : 'The system shows; the assembly decides.'}>
        {watch.length ? <ul class="watch">{watch.map((w, i) => <li key={i} class={`watch-${w.tone}`}>{w.text}</li>)}</ul>
          : <p class="empty">{t('nothing_to_watch')}</p>}
      </Section>

      <Section title={t('questions')}>
        <ul class="list">
          {qs.map((q) => (
            <li class="item item-stack" key={q.id}>
              <div class="row-between">
                <span class="item-meta">{bsDate(q.asked_on)} · {lang.value === 'np' ? 'इन्ट्री नं.' : 'Entry'} {num(q.about_seq)}</span>
                <Pill tone={q.status === 'open' ? 'warn' : 'good'}>{q.status === 'open' ? t('open') : t(q.outcome as Key)}</Pill>
              </div>
              {q.answer_np && <p class="answer">{q.answer_np}</p>}
            </li>
          ))}
        </ul>
      </Section>

      <Section title={t('officers')}>
        <ul class="mini">{officers.map((o) => <li key={o.role}><span>{roleName(o.role)}</span><span>{o.display_name}</span></li>)}</ul>
      </Section>

      <Section title={t('rules')}>
        <ul class="rules">
          {rules.map((r) => (
            <li key={r.key}>
              <p>{lang.value === 'np' ? r.purpose_np : r.purpose_en}</p>
              <p class="item-meta">{t('source')}: {r.source}{r.decision_ref ? ` · ${t('decided')}: ${r.decision_ref}` : ''}</p>
            </li>
          ))}
        </ul>
      </Section>

      {prices.length > 0 && (
        <Section title={lang.value === 'np' ? 'गाउँको मूल्यसूची' : 'Village price list'}
          note={lang.value === 'np' ? 'बिलमा कुनै वस्तुको दर यसभन्दा धेरै बढी भए जाँच्न देखाइन्छ। मूल्य समितिको निर्णयले तय हुन्छ।'
            : 'A bill item priced well above this is flagged for checking. Prices are set by committee decision.'}>
          <ul class="mini">{prices.map((p) => <li key={p.item_np + p.unit}><span>{p.item_np} / {p.unit}</span><span>{rs(p.price)}</span></li>)}</ul>
          <p class="item-meta">{t('decided')}: {[...new Set(prices.map((p) => p.decision_ref))].join(', ')}</p>
        </Section>
      )}
    </Screen>
  );
}
