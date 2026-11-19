import { t } from '../lib/i18n';
import { num, bsDate, bsShort } from '../lib/format';
import { pub, byEntity, CFUG } from '../state';
import { Screen, Section, LineChart, Pill } from '../ui';

type Reading = Record<string, any>;
export function springTrends(readings: Reading[]) {
  const sites = new Map<string, Reading[]>();
  for (const r of readings.filter((r) => r.type === 'reading.spring')) {
    if (!sites.has(r.site)) sites.set(r.site, []);
    sites.get(r.site)!.push(r);
  }
  const order = { falling: 0, rising: 1, steady: 2 };
  return [...sites.entries()].map(([site, rows]) => {
    rows.sort((a, b) => (a.occurred_on < b.occurred_on ? -1 : 1));
    const first = Number(rows[0].value), last = Number(rows[rows.length - 1].value);
    const change = first ? ((last - first) / first) * 100 : 0;
    const trend = change <= -10 ? 'falling' : change >= 10 ? 'rising' : 'steady';
    return { site, rows, first, last, change, trend: trend as 'falling' | 'rising' | 'steady' };
  }).sort((a, b) => order[a.trend] - order[b.trend] || a.change - b.change);
}

export function Nature() {
  const p = pub.value!;
  const readings = byEntity(p.nature_readings, CFUG);
  const springs = springTrends(readings);
  const rain = readings.filter((r) => r.type === 'reading.rain').sort((a, b) => (a.occurred_on < b.occurred_on ? 1 : -1));

  return (
    <Screen title={t('nature')}>
      <Section title={t('springs')} note="बाल्टिन र घडीले, हरेक दुई हप्तामा नापिएको।">
        {springs.map((s) => (
          <div class="spring" key={s.site}>
            <div class="row-between">
              <h3>{s.site}</h3>
              <Pill tone={s.trend === 'falling' ? 'water' : 'neutral'}>{t(s.trend)}</Pill>
            </div>
            <p class="item-meta">
              {num(s.first, 1)} → <strong>{num(s.last, 1)} {t('lpm')}</strong> ({bsShort(s.rows[0].occurred_on)} – {bsShort(s.rows[s.rows.length - 1].occurred_on)})
            </p>
            <LineChart unit={t('lpm')} points={s.rows.map((r) => ({ x: r.occurred_on, y: Number(r.value), label: bsShort(r.occurred_on) }))} />
          </div>
        ))}
      </Section>
      {rain.length > 0 && (
        <Section title={t('rain')}>
          <ul class="list">
            {rain.map((r) => (
              <li class="item" key={r.seq}>
                <div class="item-main"><span class="item-title">{r.site}</span><span class="item-meta">{bsDate(r.occurred_on)}</span></div>
                <span class="item-amount">{num(r.value)} {t('mm')}</span>
              </li>
            ))}
          </ul>
        </Section>
      )}
    </Screen>
  );
}
