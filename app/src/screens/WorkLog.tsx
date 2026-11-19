// काम र घण्टा लेख्ने फारम — the ledger keeper or a supervisor records a worker's hours.
// Worker, project and task, hours, paid or voluntary, before and after photos, in the officer's own name.
// The database's rules decide (work.logged): at most 12 hours a person a day, both photos unless a
// supervisor writes it, and a supervisor approves it later (never their own or their household's hours).
// The worker's name is private (members see their own hours, the public sees hours by house number);
// the photos stay on our own server and the chain carries their SHA-256.
import { useEffect, useState } from 'preact/hooks';
import { lang } from '../lib/i18n';
import { num, hours as fmtHours, bsDate, fiscalYear } from '../lib/format';
import { me, officerRoles, pub, go } from '../state';
import { source, sha256Hex } from '../data/source';
import { submit, newId as newWorkId, type Outcome } from '../lib/outbox';
import { Screen, Section } from '../ui';
import { Sent, type SentState, fromOutcome } from './Tasks';

type Row = Record<string, any>;
const L = (np: string, en: string) => (lang.value === 'np' ? np : en);
export const WORK_LOG_ROLES = ['ledger_keeper', 'supervisor'];
const today = () => { const d = new Date(); return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`; };

// a phone photo is 3–8 MB; on weak signal we send at most 1600 px, which is still clear for a field or a pond
async function shrink(file: File, max = 1600): Promise<Blob> {
  try {
    const url = URL.createObjectURL(file);
    const img = await new Promise<HTMLImageElement>((ok, bad) => { const i = new Image(); i.onload = () => ok(i); i.onerror = bad; i.src = url; });
    const k = Math.min(1, max / Math.max(img.naturalWidth, img.naturalHeight));
    const c = document.createElement('canvas');
    c.width = Math.round(img.naturalWidth * k); c.height = Math.round(img.naturalHeight * k);
    c.getContext('2d')!.drawImage(img, 0, 0, c.width, c.height);
    URL.revokeObjectURL(url);
    return await new Promise<Blob>((ok) => c.toBlob((b) => ok(b ?? file), 'image/jpeg', 0.75));
  } catch { return file; }
}

// a photo is kept on the phone with the entry and sent with it when there is signal
interface Shot { kind: 'before' | 'after'; preview: string; blob?: Blob; sha256?: string; busy?: boolean }

export function WorkLog() {
  const roles = officerRoles.value.filter((r) => WORK_LOG_ROLES.includes(r.role));
  const entities = [...new Set(roles.map((r) => r.entity))];
  const [picked, setEntity] = useState('');
  // the person may load after the first render (sign-in, or opening #worklog directly)
  const entity = entities.includes(picked) ? picked : entities[0] ?? '';
  const [workers, setWorkers] = useState<Row[]>([]);
  const [find, setFind] = useState('');
  const [worker, setWorker] = useState('');
  const [project, setProject] = useState('');
  const [other, setOther] = useState('');
  const [task, setTask] = useState('');
  const [h, setH] = useState('');
  const [paid, setPaid] = useState(true);
  const [qty, setQty] = useState('');
  const [unit, setUnit] = useState('');
  const [on, setOn] = useState(today());
  const [shots, setShots] = useState<Record<'before' | 'after', Shot | null>>({ before: null, after: null });
  const [state, setState] = useState<SentState>(null);

  useEffect(() => { if (entity) source.officerWorkers(entity).then(setWorkers).catch(() => setWorkers([])); }, [entity, me.value?.id]);

  const title = L('काम र घण्टा लेख्ने', 'Record work hours');
  if (!me.value || !roles.length) {
    return <Screen title={title}>
      <p class="empty">{L('यो काम लेखापाल वा सुपरिवेक्षकको हो। नमुनामा "मेरो" मा गीता (लेखापाल) वा विकास (सुपरिवेक्षक) छान्नुहोस्।',
        'This is for the ledger keeper or a supervisor. In the sample, choose गीता (ledger keeper) or विकास (supervisor) under Mine.')}</p>
      <button class="btn" onClick={() => go('mine')}>{L('मेरो खोल्नुहोस्', 'Open Mine')}</button>
    </Screen>;
  }

  const myRolesHere = roles.filter((r) => r.entity === entity).map((r) => r.role);
  const isSupervisor = myRolesHere.includes('supervisor');
  const nameOf = (e: string) => pub.value?.bodies.find((b) => b.id === e)?.name_np ?? e;
  const projects = [...new Set((pub.value?.project_hours ?? []).filter((r) => r.entity_id === entity).map((r) => r.project as string))];
  const proj = project === '__other' ? other.trim() : project;
  const hv = Number(h);
  const hoursOk = h !== '' && hv > 0 && hv <= 12 && Math.round(hv * 4) === hv * 4;   // quarter hours at most
  const photosOk = isSupervisor || (!!shots.before?.blob && !!shots.after?.blob);
  const busy = !!(shots.before?.busy || shots.after?.busy);
  const ready = !!worker && !!proj && !!task.trim() && hoursOk && photosOk && !busy && !!on;
  const w = workers.find((x) => x.person_id === worker);
  const shown = workers.filter((x) => !find.trim() || String(x.name).includes(find.trim()) || String(x.house_no ?? '') === find.trim().replace(/[०-९]/g, (d) => String('०१२३४५६७८९'.indexOf(d))));

  const takePhoto = async (kind: 'before' | 'after', file?: File) => {
    if (!file) return;
    const preview = URL.createObjectURL(file);
    setShots((s) => ({ ...s, [kind]: { kind, preview, busy: true } }));
    const blob = await shrink(file);
    const sha256 = await sha256Hex(blob).catch(() => undefined);
    setShots((s) => ({ ...s, [kind]: { kind, preview, blob, sha256 } }));
  };

  const send = async () => {
    const payload: Row = { work_id: newWorkId(), project: proj, task_np: task.trim(), hours: hv, paid };
    if (qty !== '' && Number(qty) >= 0) { payload.output_qty = Number(qty); if (unit.trim()) payload.output_unit = unit.trim(); }
    const photos = (['before', 'after'] as const).filter((k) => shots[k]?.blob).map((k) => ({ kind: k, blob: shots[k]!.blob! }));
    const label = `${w?.name ?? ''} · ${num(hv, hv % 1 ? 2 : 0)} ${L('घण्टा', 'h')} · ${proj} · ${bsDate(on)}`;
    const out: Outcome = await submit(me.value!.id, entity, 'work.logged', payload, { person_id: worker }, fiscalYear(new Date(on + 'T12:00')), on, photos, label);
    setState(fromOutcome(out));
  };
  // several people often do the same work together: keep the work, the hours and the photos, change the person
  const again = () => { setState(null); setWorker(''); setFind(''); };
  const fresh = () => { again(); setTask(''); setH(''); setQty(''); setShots({ before: null, after: null }); };

  const Photo = ({ kind }: { kind: 'before' | 'after' }) => {
    const s = shots[kind];
    return (
      <div class="work-photo">
        <label class="btn btn-quiet photo-btn">
          {s?.busy ? L('मिलाउँदै…', 'Preparing…') : s ? L('फेरि खिच्नुहोस्', 'Take again')
            : kind === 'before' ? L('काम अघिको फोटो', 'Photo before') : L('काम पछिको फोटो', 'Photo after')}
          <input type="file" accept="image/*" capture="environment" hidden onChange={(e) => takePhoto(kind, (e.target as HTMLInputElement).files?.[0])} />
        </label>
        {s && <img src={s.preview} alt="" />}
        {s?.blob && <p class="item-meta">✓ {L('फोनमा राखियो', 'Kept on the phone')}{s.sha256 ? ` · ${L('औँठाछाप', 'fingerprint')} ${s.sha256.slice(0, 12)}…` : ''}</p>}
      </div>
    );
  };

  return (
    <Screen title={title}>
      {entities.length > 1 && (
        <div class="row-gap">
          {entities.map((e) => <button key={e} class={`btn ${e === entity ? '' : 'btn-quiet'}`} onClick={() => { setEntity(e); setWorker(''); setProject(''); }}>{nameOf(e)}</button>)}
        </div>
      )}
      <p class="lede">{nameOf(entity)}</p>
      {state ? (
        <Section title={'error' in state ? L('लेखिएन', 'Not recorded') : 'waiting' in state ? L('फोनमा राखियो', 'Kept on the phone') : L('लेखियो', 'Recorded')}>
          <Sent s={state} />
          {!('error' in state) && !('waiting' in state) && <p class="item-meta">{L(`${w?.name ?? ''} · ${num(hv, hv % 1 ? 2 : 0)} घण्टा · ${bsDate(on)}। अब सुपरिवेक्षकले स्वीकृत गर्छन्; काम गर्ने व्यक्तिको नाम सार्वजनिक खातामा देखिँदैन।`,
            `${w?.name ?? ''} · ${num(hv, hv % 1 ? 2 : 0)} h · ${bsDate(on)}. A supervisor approves it next; the worker's name does not appear in the public record.`)}</p>}
          {'error' in state ? <div class="row-gap"><button class="btn" onClick={() => setState(null)}>{L('फारममा फर्केर मिलाउनुहोस्', 'Back to the form to fix it')}</button></div> :
          <div class="row-gap">
            <button class="btn" onClick={again}>{L('अर्को व्यक्ति, उही काम', 'Another person, same work')}</button>
            <button class="btn btn-quiet" onClick={fresh}>{L('नयाँ काम', 'New work')}</button>
            <button class="btn btn-quiet" onClick={() => go('tasks')}>{L('काम बाँकी', 'To do')}</button>
          </div>}
        </Section>
      ) : (
        <form class="form" onSubmit={(e) => { e.preventDefault(); if (ready) send(); }}>
          <Section title={L('१. कसले काम गर्नुभयो?', '1. Who worked?')}>
            <label for="wl-find">{L('नाम वा घर नम्बरले खोज्नुहोस्', 'Search by name or house number')}</label>
            <input id="wl-find" value={find} onInput={(e) => setFind((e.target as HTMLInputElement).value)} />
            <select aria-label={L('काम गर्ने', 'Worker')} value={worker} onChange={(e) => setWorker((e.target as HTMLSelectElement).value)}>
              <option value="">{L('— छान्नुहोस् —', '— choose —')}</option>
              {shown.map((x) => <option key={x.person_id} value={x.person_id}>{x.name}{x.house_no != null ? ` · ${L('घर', 'house')} ${num(x.house_no)}` : ''}</option>)}
            </select>
            {!workers.length && <p class="item-meta">{L('सूची आएन। इन्टरनेट जाँचेर फेरि खोल्नुहोस्।', 'The list did not load. Check the signal and open again.')}</p>}
            {w && w.person_id === me.value.id && <p class="item-meta">{L('आफ्नै काम लेख्दै हुनुहुन्छ: अर्को सुपरिवेक्षकले स्वीकृत गर्छन्।', 'You are recording your own work: another supervisor approves it.')}</p>}
          </Section>

          <Section title={L('२. के काम?', '2. What work?')}>
            <label for="wl-proj">{L('परियोजना', 'Project')}</label>
            <select id="wl-proj" value={project} onChange={(e) => setProject((e.target as HTMLSelectElement).value)}>
              <option value="">{L('— छान्नुहोस् —', '— choose —')}</option>
              {projects.map((p) => <option key={p} value={p}>{p}</option>)}
              <option value="__other">{L('अर्को (लेख्नुहोस्)', 'Other (write it)')}</option>
            </select>
            {project === '__other' && <input aria-label={L('परियोजनाको नाम', 'Project name')} value={other} onInput={(e) => setOther((e.target as HTMLInputElement).value)} />}
            <label for="wl-task">{L('काम (जस्तै: पोखरीको किनार बलियो पार्ने)', 'Task (e.g. strengthening the pond edge)')}</label>
            <input id="wl-task" value={task} onInput={(e) => setTask((e.target as HTMLInputElement).value)} />
            <label for="wl-on">{L('मिति', 'Date')}{on ? ` · ${bsDate(on)}` : ''}</label>
            <input id="wl-on" type="date" value={on} max={today()} onInput={(e) => setOn((e.target as HTMLInputElement).value)} />
          </Section>

          <Section title={L('३. कति घण्टा?', '3. How many hours?')}>
            <div class="row-gap">
              {[2, 4, 6, 8].map((x) => <button type="button" key={x} class={`btn ${hv === x ? '' : 'btn-quiet'}`} onClick={() => setH(String(x))}>{fmtHours(x)}</button>)}
            </div>
            <label for="wl-h">{L('वा आफैं लेख्नुहोस् (आधा घण्टा = ०.५)', 'Or type it (half an hour = 0.5)')}</label>
            <input id="wl-h" inputMode="decimal" value={h} onInput={(e) => setH((e.target as HTMLInputElement).value)} />
            {h !== '' && !hoursOk && <p class="sent error">{L('० भन्दा बढी र १२ घण्टासम्म, पाव घण्टाको हिसाबमा।', 'More than 0 and at most 12, in quarter hours.')}</p>}
            <div class="row-gap">
              <button type="button" class={`btn ${paid ? '' : 'btn-quiet'}`} onClick={() => setPaid(true)}>{L('ज्याला पाउने', 'Paid')}</button>
              <button type="button" class={`btn ${!paid ? '' : 'btn-quiet'}`} onClick={() => setPaid(false)}>{L('स्वयंसेवा', 'Voluntary')}</button>
            </div>
            <p class="item-meta">{paid ? L('ज्याला सबैलाई एउटै दरमा, सुपरिवेक्षकले स्वीकृत गरेका घण्टामा मात्र।', 'Paid at the one rate for everyone, and only for hours a supervisor approves.')
              : L('स्वयंसेवाको घण्टा पनि अभिलेखमा बस्छ, तर ज्याला आउँदैन।', 'Voluntary hours are recorded too, but earn no wage.')}</p>
            <label for="wl-qty">{L('कति काम भयो? (नचाहिए खाली छोड्नुहोस्)', 'How much was done? (leave empty if not needed)')}</label>
            <div class="row-gap">
              <input id="wl-qty" inputMode="decimal" style={{ flex: 1 }} value={qty} onInput={(e) => setQty((e.target as HTMLInputElement).value)} />
              <input aria-label={L('एकाइ', 'Unit')} placeholder={L('मिटर, बिरुवा, किलो…', 'metres, plants, kg…')} style={{ flex: 1 }} value={unit} onInput={(e) => setUnit((e.target as HTMLInputElement).value)} />
            </div>
          </Section>

          <Section title={L('४. काम अघि र पछिको फोटो', '4. Photos before and after')}
            note={isSupervisor ? L('सुपरिवेक्षकले आफैं लेख्दा फोटो ऐच्छिक छ, तर राख्नु राम्रो।', 'When a supervisor records it, photos are optional, but better kept.')
              : L('दुवै फोटो चाहिन्छ। फोटो हाम्रै सर्भरमा बस्छ; अभिलेखमा त्यसको औँठाछाप (SHA-256) मात्र जान्छ।', 'Both photos are needed. They stay on our own server; the record carries only their fingerprint (SHA-256).')}>
            <div class="work-photos"><Photo kind="before" /><Photo kind="after" /></div>
          </Section>

          <button class="btn btn-wide" type="submit" disabled={!ready}>{L(`मेरो नाममा लेख्नुहोस् (${me.value.name})`, `Record in my name (${me.value.name})`)}</button>
          {!ready && <p class="item-meta">{isSupervisor ? L('काम गर्ने, परियोजना, काम र घण्टा भरेपछि बटन खुल्छ।', 'The button opens once worker, project, task and hours are filled in.')
            : L('काम गर्ने, परियोजना, काम, घण्टा र दुवै फोटो भरेपछि बटन खुल्छ।', 'The button opens once worker, project, task, hours and both photos are in.')}</p>}
        </form>
      )}
    </Screen>
  );
}
