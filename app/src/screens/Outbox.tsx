// पठाउन बाँकी — what is kept on this phone and not yet in the record. Shown at the top of काम बाँकी.
import { useState } from 'preact/hooks';
import { lang } from '../lib/i18n';
import { num } from '../lib/format';
import { me } from '../state';
import { outbox, lastSent, flush, remove, retry } from '../lib/outbox';
import { Section } from '../ui';

const L = (np: string, en: string) => (lang.value === 'np' ? np : en);

export function Outbox() {
  const items = outbox.value;
  const recent = lastSent.value;
  const [sure, setSure] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  if (!items.length && !recent.length) return null;
  const mine = items.filter((i) => i.by === me.value?.id);
  const others = items.length - mine.length;
  const waiting = mine.filter((i) => i.state === 'waiting');
  const problems = mine.filter((i) => i.state === 'problem');
  const sendNow = async () => { setBusy(true); await flush(me.value?.id); setBusy(false); };
  return (
    <Section title={L('पठाउन बाँकी', 'Waiting to send')}
      note={L('यी इन्ट्री यही फोनमा राखिएका छन्। सिग्नल आएपछि आफैं पठाइन्छन्; एउटै इन्ट्री दुई पटक लेखिँदैन।',
        'These entries are kept on this phone. They are sent by themselves when there is signal; an entry is never recorded twice.')}>
      {waiting.length > 0 && (
        <article class="task">
          <div class="row-between"><span class="item-title">{L('सिग्नल पर्खँदै', 'Waiting for signal')}</span><span class="item-amount">{num(waiting.length)}</span></div>
          <ul class="outbox-list">{waiting.map((i) => <li key={i.ref}>{i.label}{i.photos.length ? ` · ${L('फोटो', 'photos')} ${num(i.photos.length)}` : ''}</li>)}</ul>
          {waiting.some((i) => i.tries >= 3) && <p class="item-meta">{L('धेरै पटक पठाउन सकिएन। सिग्नल भएको ठाउँमा जानुहोस्; त्यसपछि पनि नगए फेरि साइन इन गर्नुहोस्।',
            'Could not send after several tries. Go where there is signal; if it still does not go, sign in again.')}</p>}
          <button class="btn" disabled={busy} onClick={sendNow}>{busy ? L('पठाउँदै…', 'Sending…') : L('अहिले पठाउनुहोस्', 'Send now')}</button>
        </article>
      )}
      {problems.map((i) => (
        <article class="task task-problem" key={i.ref}>
          <p class="item-title">{i.label}</p>
          <p class="sent error">{L('नियमअनुसार लेखिएन:', 'Not recorded under the rules:')} {i.error}</p>
          <p class="item-meta">{L('यसलाई हटाएर, मिलाएर फेरि लेख्नुहोस्।', 'Remove it, put it right and record it again.')}</p>
          <div class="row-gap">
            {sure === i.ref
              ? <><button class="btn" onClick={() => { remove(i.ref); setSure(null); }}>{L('हो, हटाउनुहोस्', 'Yes, remove it')}</button>
                  <button class="btn btn-quiet" onClick={() => setSure(null)}>{L('होइन', 'No')}</button></>
              : <><button class="btn btn-quiet" onClick={() => setSure(i.ref)}>{L('हटाउनुहोस्', 'Remove')}</button>
                  <button class="btn btn-quiet" onClick={() => retry(i.ref, me.value?.id)}>{L('फेरि प्रयास', 'Try again')}</button></>}
          </div>
        </article>
      ))}
      {others > 0 && <p class="item-meta">{L(`अर्को व्यक्तिले यही फोनमा राखेका ${num(others)} इन्ट्री उहाँ साइन इन गरेपछि पठाइन्छन्।`,
        `${num(others)} entries kept on this phone by someone else are sent when that person signs in.`)}</p>}
      {recent.length > 0 && (
        <details class="items-read">
          <summary>{L('भर्खर पठाइएका', 'Just sent')} ({num(recent.length)})</summary>
          <ul class="outbox-list">{recent.map((r) => <li key={r.at + r.label}>{r.label} · {'sent' in r.outcome ? `${L('इन्ट्री नं.', 'entry')} ${num(r.outcome.sent)}`
            : 'demo' in r.outcome ? L('नमुना: वास्तविकमा यहाँ लेखिन्थ्यो', 'sample: would be recorded here') : 'problem' in r.outcome ? L('लेखिएन', 'not recorded') : ''}</li>)}</ul>
        </details>
      )}
    </Section>
  );
}
