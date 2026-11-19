import { t } from '../lib/i18n';
import { num, hours, monthRange } from '../lib/format';
import { pub, byEntity, CFUG } from '../state';
import { Screen, Section, Pill } from '../ui';

export function Work({ entity = CFUG }: { entity?: string }) {
  const p = pub.value!;
  const turns = byEntity(p.fair_turns, entity);
  const months = [...new Set(turns.map((r) => r.month))].sort().reverse();
  const projects = byEntity(p.project_hours, entity).sort((a, b) => (a.month < b.month ? 1 : -1));
  const rate = p.rules.find((r) => r.entity_id === entity && r.key === 'hourly_rate')?.value;

  return (
    <Screen title={t('work')}>
      <p class="lede">
        {t('equal_rate')}: <strong>{rate ? `रु ${num(rate)}` : '—'}</strong> / {hours(1).replace(/^\S+\s/, '')}
      </p>
      <Section title={t('fair_turns')} note="घर नम्बरले मात्र; नाम देखाइँदैन।">
        {months.map((m) => {
          const rows = turns.filter((r) => r.month === m).sort((a, b) => a.house_no - b.house_no);
          const max = Math.max(...rows.map((r) => Number(r.paid_hours)), 1);
          return (
            <div class="turns" key={m}>
              <h3>{monthRange(m)}</h3>
              <ul class="bars">
                {rows.map((r) => (
                  <li key={r.house_no} class={Number(r.paid_hours) === 0 && !(Number(r.declined) > 0) ? 'zero' : ''}>
                    <span class="bar-label">{t('house')} {num(r.house_no)}</span>
                    <span class="bar-track"><span class="bar-fill" style={{ width: `${(Number(r.paid_hours) / max) * 100}%` }} /></span>
                    <span class="bar-value">
                      {Number(r.paid_hours) > 0 ? hours(r.paid_hours) : Number(r.declined) > 0
                        ? <Pill tone="neutral">{num(r.declined)} {t('declined')}</Pill> : <Pill tone="warn">{t('no_paid_work')}</Pill>}
                    </span>
                  </li>
                ))}
              </ul>
            </div>
          );
        })}
      </Section>

      <Section title={t('projects')}>
        <ul class="list">
          {projects.map((r) => (
            <li class="item" key={r.project + r.month}>
              <div class="item-main">
                <span class="item-title">{r.project}</span>
                <span class="item-meta">{monthRange(r.month)}</span>
                {r.too_few_to_show && <span class="item-meta">{t('too_few')}</span>}
              </div>
              <span class="item-amount">{r.too_few_to_show ? '—' : <>{hours(r.hours)}<small> · {num(r.workers)} {t('workers')}</small></>}</span>
            </li>
          ))}
        </ul>
      </Section>
    </Screen>
  );
}
