import { lang, t } from '../lib/i18n';
import { rs, num, bsDate } from '../lib/format';
import { pub, byEntity, MPC } from '../state';
import { Screen, Section, Stat, Pill, Meter } from '../ui';
import { yearOf } from './Home';
import { source } from '../data/source';

export function Coop() {
  const p = pub.value!;
  const body = p.bodies.find((b) => b.id === MPC);
  const s = byEntity(p.mpc_summary, MPC)[0];
  const loans = byEntity(p.loan_register, MPC);
  const grants = byEntity(p.grant_register, MPC);
  const ents = byEntity(p.enterprise_results, MPC);
  const fy = yearOf(byEntity(p.income_and_spending, MPC));
  const budget = byEntity(p.budget_status, MPC).filter((b) => b.fiscal_year === fy);
  const rule = (k: string) => p.rules.find((r) => r.entity_id === MPC && r.key === k)?.value;
  const np = lang.value === 'np';

  return (
    <Screen title={body?.name_np ?? t('coop')}>
      <p class="banner">{source.mode === 'sample' && <><Pill tone="warn">{t('sample')}</Pill> </>}{t('coop_note')}</p>
      {s && (
        <div class="stats stats-3">
          <Stat label={t('members')} value={num(s.members)} />
          <Stat label={t('share_capital')} value={rs(s.share_capital)} sub={np ? 'हरेक सदस्यको एक कित्ता (रु १००)' : 'one share of Rs 100 per member'} />
          <Stat label={t('in_bank')} value={rs(s.in_bank)} />
          <Stat label={t('loans_out')} value={rs(s.loans_outstanding)} />
          <Stat label={t('grants_unspent')} value={rs(s.grants_unspent)} />
          <Stat label={t('equal_rate')} value={`${rs(s.hourly_rate)}`} sub={np ? 'प्रति घण्टा, सबैलाई' : 'per hour, for everyone'} />
        </div>
      )}

      <Section title={t('enterprises')}>
        <ul class="list">
          {ents.map((e) => (
            <li class="item item-stack" key={e.enterprise_id}>
              <div class="row-between"><span class="item-title">{e.name_np}</span><span class="item-amount">{rs(e.net)}</span></div>
              <span class="item-meta">{np ? 'आम्दानी' : 'Income'} {rs(e.income)} · {t('spent')} {rs(e.spending)} · {num(e.paid_hours)} {np ? 'घण्टा काम' : 'hours worked'}</span>
              <span class="item-meta"><strong>{t('earn_per_hour')}: {rs(Math.round(e.earnings_per_hour))}</strong> · {t('equal_rate')} {rs(s?.hourly_rate)}</span>
            </li>
          ))}
        </ul>
      </Section>

      <Section title={t('loan_register')} note={np ? `सदस्यको परियोजना ऋणमा सबैलाई एउटै दर, हाल वार्षिक ${num(rule('member_loan_rate'))}%। रु १ लाखसम्म ३ महिनाको सूचनामा फिर्ता; त्यसभन्दा बढी ३–५ वर्षको। अरूबाट ऋण बढीमा ${num(rule('loan_rate_cap'))}%। (विनियम ४.१५ दफा ८)` : `Members' project loans all earn one rate, now ${rule('member_loan_rate')}%. Up to Rs 1 lakh back on 3 months' notice; above that, 3–5 years fixed. Loans from others at most ${rule('loan_rate_cap')}%. (Bylaws v4.15 s.8)`}>
        <ul class="list">
          {loans.map((l) => (
            <li class="item item-stack" key={l.loan_id}>
              <div class="row-between"><span class="item-title">{l.lender_name ?? t('member_lender')}</span><span class="item-amount">{rs(l.outstanding)}</span></div>
              <span class="item-meta">{rs(l.amount)} · {t('rate')} {num(l.rate_pct)}% · {l.withdrawal === 'notice' ? t('on_notice') : `${num(l.term_months)} ${np ? 'महिना' : 'months'}`} · {bsDate(l.received_on)}</span>
              {l.notice_given_on && <span class="item-meta"><Pill tone="warn">{t('notice_given')}: {rs(l.notice_amount)}</Pill> {t('repay_from')} {bsDate(l.repay_due_on)}</span>}
              <span class="item-meta">{l.decision_ref}{l.related_party ? (np ? ' · पदाधिकारीको घर: निर्णयमा अलग रहने' : ' · officer household: stands aside') : ''}</span>
            </li>
          ))}
        </ul>
      </Section>

      <Section title={t('grant_register')} note={np ? 'अनुदान तोकिएको कामका लागि मात्र; नाफामा गनिँदैन।' : 'Spent only on its purpose; never counted as surplus.'}>
        <ul class="list">
          {grants.map((g) => (
            <li class="item item-stack" key={g.grant_id}>
              <div class="row-between"><span class="item-title">{g.purpose_np}</span><span class="item-amount">{rs(g.amount)}</span></div>
              <Meter value={Number(g.used)} max={Number(g.amount)} />
              <span class="item-meta">{g.donor} · {t('spent')} {rs(g.used)} · {t('left')} {rs(g.unspent)} · {g.agreement_ref}</span>
            </li>
          ))}
        </ul>
      </Section>

      {budget.length > 0 && (
        <Section title={`${t('budget')} ${fy}`}>
          <ul class="list">
            {budget.map((b) => (
              <li class="item item-stack" key={b.line_id}>
                <div class="row-between"><span class="item-title">{b.title_np}</span><span class="item-amount">{rs(b.budget)}</span></div>
                <Meter value={Number(b.spent)} max={Number(b.budget)} />
                <span class="item-meta">{t('spent')} {rs(b.spent)} · {t('left')} {rs(b.remaining)}</span>
              </li>
            ))}
          </ul>
        </Section>
      )}

      <Section title={t('split')} note={np ? 'सबै खर्च र ब्याज तिरेपछिको खुद बचत; विनियम ४.१५ दफा १४' : 'Net surplus after all costs and interest; bylaws v4.15 s.14'}>
        <ol class="split">
          <li><strong>{num(rule('reserve_pct'))}%</strong> {np ? 'जगेडा कोष (कम्तीमा)' : 'reserve fund (at least)'}</li>
          <li><strong>{num(rule('promotion_pct'))}%</strong> {np ? 'सहकारी प्रवर्द्धन कोष' : 'cooperative promotion fund'}</li>
          <li>{np ? 'बाँकी:' : 'Then:'} <strong>{num(rule('split_community_pct'))}%</strong> {np ? 'सामुदायिक विकास' : 'community development'} · <strong>{num(rule('split_member_pct'))}%</strong> {np ? 'संरक्षित पूँजी फिर्ता कोष (सक्रिय सदस्यलाई काम घण्टाअनुसार)' : 'protected capital return fund (to active members by hours worked)'} · <strong>{num(100 - Number(rule('split_community_pct')) - Number(rule('split_member_pct')))}%</strong> {np ? 'पूँजी, प्रविधि र तालिम' : 'capital, technology and training'}</li>
        </ol>
      </Section>
    </Screen>
  );
}
