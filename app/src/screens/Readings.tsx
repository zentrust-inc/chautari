// पानी र वर्षा नाप्ने फारम — the nature guardian or ledger keeper records a spring's flow or the rain gauge.
// Same path as every entry: their own name, the database's rules, an entry nobody can change afterwards.
import { useState } from 'preact/hooks';
import { lang } from '../lib/i18n';
import { num, fiscalYear, bsDate } from '../lib/format';
import { me, officerRoles, pub, go } from '../state';
import { submit } from '../lib/outbox';
import { Screen, Section } from '../ui';
import { Sent, type SentState, fromOutcome } from './Tasks';

const L = (np: string, en: string) => (lang.value === 'np' ? np : en);
export const READING_ROLES = ['ledger_keeper', 'nature_guardian'];
const today = () => { const d = new Date(); return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`; };

export function Readings() {
  const roles = officerRoles.value.filter((r) => READING_ROLES.includes(r.role));
  const entity = roles[0]?.entity ?? '';
  const sites = (type: string) => [...new Set((pub.value?.nature_readings ?? []).filter((r) => r.entity_id === entity && r.type === type).map((r) => r.site as string))];
  const springs = sites('reading.spring'), gauges = sites('reading.rain');
  const [kind, setKind] = useState<'spring' | 'rain'>('spring');
  const [site, setSite] = useState(springs[0] ?? '');
  const [value, setValue] = useState('');
  const [on, setOn] = useState(today());
  const [state, setState] = useState<SentState>(null);

  if (!me.value || !roles.length) {
    return <Screen title={L('पानी र वर्षा नाप', 'Water and rain readings')}>
      <p class="empty">{L('यो काम प्रकृति हेरालु वा लेखापालको हो। नमुनामा "मेरो" मा सरिता (प्रकृति हेरालु) वा गीता (लेखापाल) छान्नुहोस्।',
        'This is for the nature guardian or the ledger keeper. In the sample, choose सरिता (nature guardian) or गीता (ledger keeper) under Mine.')}</p>
      <button class="btn" onClick={() => go('mine')}>{L('मेरो खोल्नुहोस्', 'Open Mine')}</button>
    </Screen>;
  }
  const list = kind === 'spring' ? springs : gauges;
  const v = Number(value);
  const last = (pub.value?.nature_readings ?? []).filter((r) => r.entity_id === entity && r.site === site).slice(-1)[0];
  const send = async () => {
    const type = kind === 'spring' ? 'reading.spring' : 'reading.rain';
    const payload = kind === 'spring' ? { spring_id: site, litres_per_minute: v, method: 'बाल्टी र घडी' } : { gauge_id: site, mm: v };
    const label = `${site} · ${num(v, v % 1 ? 1 : 0)} ${kind === 'spring' ? L('लि/मि', 'l/min') : 'mm'} · ${bsDate(on)}`;
    setState(fromOutcome(await submit(me.value!.id, entity, type, payload, {}, fiscalYear(new Date(on + 'T12:00')), on, [], label)));
  };
  return (
    <Screen title={L('पानी र वर्षा नाप', 'Water and rain readings')}>
      <Section title={L('के नाप्नुभयो?', 'What did you measure?')}>
        <div class="row-gap">
          <button class={`btn ${kind === 'spring' ? '' : 'btn-quiet'}`} onClick={() => { setKind('spring'); setSite(springs[0] ?? ''); setState(null); }}>{L('मूलको पानी', 'Spring flow')}</button>
          <button class={`btn ${kind === 'rain' ? '' : 'btn-quiet'}`} onClick={() => { setKind('rain'); setSite(gauges[0] ?? ''); setState(null); }}>{L('वर्षा', 'Rain')}</button>
        </div>
        {state ? <><Sent s={state} /><button class="btn btn-quiet" onClick={() => { setState(null); setValue(''); }}>{L('अर्को नाप', 'Another reading')}</button></> : (
          <form class="form" onSubmit={(e) => { e.preventDefault(); if (site && value !== '' && v >= 0) send(); }}>
            <label for="rd-site">{kind === 'spring' ? L('कुन मूल?', 'Which spring?') : L('कुन वर्षा मापक?', 'Which rain gauge?')}</label>
            <select id="rd-site" value={site} onChange={(e) => setSite((e.target as HTMLSelectElement).value)}>
              {list.map((s) => <option key={s} value={s}>{s}</option>)}
            </select>
            <label for="rd-val">{kind === 'spring' ? L('लिटर प्रति मिनेट', 'Litres per minute') : L('मिलिमिटर (पछिल्लो नापदेखि)', 'Millimetres (since the last reading)')}</label>
            <input id="rd-val" inputMode="decimal" value={value} onInput={(e) => setValue((e.target as HTMLInputElement).value)} />
            {kind === 'spring' && <p class="item-meta">{L('तरिका: बाल्टी र घडी — १० लिटरको बाल्टी भरिन कति सेकेन्ड लाग्यो? ६०० ÷ सेकेन्ड = लिटर/मिनेट।',
              'Method: bucket and watch — how many seconds to fill a 10-litre bucket? 600 ÷ seconds = litres per minute.')}</p>}
            {last && <p class="item-meta">{L('पछिल्लो नाप:', 'Last reading:')} {num(last.value, last.value % 1 ? 1 : 0)} {last.unit === 'mm' ? 'mm' : L('लि/मि', 'l/min')}</p>}
            <label for="rd-on">{L('मिति', 'Date')}</label>
            <input id="rd-on" type="date" value={on} max={today()} onInput={(e) => setOn((e.target as HTMLInputElement).value)} />
            <button class="btn" type="submit" disabled={!site || value === '' || !(v >= 0)}>{L(`मेरो नाममा लेख्नुहोस् (${me.value.name})`, `Record in my name (${me.value.name})`)}</button>
          </form>
        )}
      </Section>
    </Screen>
  );
}
