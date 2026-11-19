import { useEffect, useState } from 'preact/hooks';
import { lang, t, roleName } from '../lib/i18n';
import { rs, num, bsDate, hours, fiscalYear } from '../lib/format';
import { me, officerRoles, pub, loadAll } from '../state';
import { source, DemoWrite, type OfficerQueues } from '../data/source';
import { Screen, Section, Pill } from '../ui';

type Row = Record<string, any>;
export type SentState = null | { ok: true; seq: number } | { demo: Row } | { error: string };

// What happened after pressing a button. In sample mode it shows the exact entry the real
// system would add to the record, so people can see what a signature is.
export function Sent({ s }: { s: Exclude<SentState, null> }) {
  if ('ok' in s) return <p class="sent ok">✓ {t('sent')} · {lang.value === 'np' ? 'इन्ट्री नं.' : 'entry'} {num(s.seq)}</p>;
  if ('error' in s) return <p class="sent error">{s.error}</p>;
  return (
    <div class="sent demo">
      <p>{t('demo_write')}:</p>
      <pre>{JSON.stringify({ type: s.demo.type, payload: s.demo.payload }, null, 1)}</pre>
    </div>
  );
}

function useAction() {
  const [state, setState] = useState<Record<string, SentState>>({});
  const run = async (key: string, entity: string, type: string, payload: Row, fy?: string) => {
    try {
      const r = await source.record(entity, type, payload, {}, fy ?? fiscalYear());
      setState((s) => ({ ...s, [key]: { ok: true, seq: r.seq } }));
      await loadAll();
    } catch (e) {
      setState((s) => ({ ...s, [key]: e instanceof DemoWrite ? { demo: e.entry } : { error: (e as Error).message } }));
    }
  };
  return [state, run] as const;
}

export function Tasks() {
  const roles = officerRoles.value;
  const entities = [...new Set(roles.map((r) => r.entity))];
  const [queues, setQueues] = useState<Record<string, OfficerQueues>>({});
  useEffect(() => {
    Promise.all(entities.map(async (e) => [e, await source.officer(e, roles.filter((r) => r.entity === e).map((r) => r.role))] as const))
      .then((x) => setQueues(Object.fromEntries(x)));
  }, [me.value?.id, pub.value]);
  const [state, run] = useAction();

  if (!me.value || !roles.length) return <Screen title={t('tasks')}><p class="empty">{t('no_tasks')}</p></Screen>;
  const nameOf = (e: string) => pub.value?.bodies.find((b) => b.id === e)?.name_np ?? e;
  const signerRoles = ['treasurer', 'chair', 'secretary'];

  return (
    <Screen title={t('tasks')} back={false}>
      {entities.map((entity) => {
        const q = queues[entity] ?? {};
        const mine = roles.filter((r) => r.entity === entity).map((r) => r.role);
        const myRole = mine.find((r) => signerRoles.includes(r));
        const total = (q.payments_waiting?.length ?? 0) + (q.work_waiting?.length ?? 0) + (q.questions?.filter((x) => x.status === 'open').length ?? 0);
        return (
          <Section key={entity} title={nameOf(entity)} note={mine.map(roleName).join(', ')}>
            {total === 0 && <p class="empty">{t('no_tasks')}</p>}

            {q.payments_waiting?.map((x) => {
              const signed: Row[] = x.signed_by;
              const has = (r: string) => signed.some((s) => s.role === r);
              const ready = has('treasurer') && (has('chair') || has('secretary'));
              const canSign = myRole && !has(myRole) && !signed.some((s) => s.name === me.value!.name);
              const key = 'p' + x.expense_id;
              return (
                <article class="task" key={key}>
                  <div class="row-between"><span class="item-title">{x.memo_np}</span><span class="item-amount">{rs(x.amount)}</span></div>
                  <p class="item-meta">{x.payee} · {x.budget_line ?? (lang.value === 'np' ? 'बजेटबाहिर' : 'unbudgeted')} · {x.method === 'bank' ? (lang.value === 'np' ? 'बैंक' : 'bank') : (lang.value === 'np' ? 'नगद' : 'cash')}</p>
                  <p class="signers">{t('signed_by')}: {signed.length ? signed.map((s) => <Pill key={s.role} tone="good">{roleName(s.role)} · {s.name}</Pill>) : '—'}</p>
                  {state[key] ? <Sent s={state[key]!} /> : (
                    <div class="row-gap">
                      {canSign && <button class="btn" onClick={() => run(key, entity, 'payment.approved', { expense_id: x.expense_id, as_role: myRole })}>{t('sign')} ({roleName(myRole!)})</button>}
                      {ready && myRole && <button class="btn" onClick={() => run(key, entity, 'payment.released', { expense_id: x.expense_id }, fiscalYear())}>{t('release')}</button>}
                    </div>
                  )}
                </article>
              );
            })}

            {q.work_waiting?.map((w) => {
              const key = 'w' + w.work_id;
              const own = w.worker === me.value!.name || w.house_no === me.value!.house_no;
              return (
                <article class="task" key={key}>
                  <div class="row-between"><span class="item-title">{w.project}{w.task_np && w.task_np !== w.project ? `: ${w.task_np}` : ''}</span><span class="item-amount">{hours(w.hours)}</span></div>
                  <p class="item-meta">{w.worker} · {t('house')} {num(w.house_no)} · {bsDate(w.work_date)}{w.paid ? '' : (lang.value === 'np' ? ' · स्वयंसेवा' : ' · voluntary')}</p>
                  {state[key] ? <Sent s={state[key]!} /> : (mine.includes('supervisor') && !own
                    ? <button class="btn" onClick={() => run(key, entity, 'work.approved', { work_id: w.work_id })}>{t('approve')}</button>
                    : <p class="item-meta">{own ? (lang.value === 'np' ? 'आफ्नो वा आफ्नो घरको काम: अर्को सुपरिवेक्षकले स्वीकृत गर्छ।' : 'Your own or your household’s work: another supervisor approves it.')
                        : (lang.value === 'np' ? 'सुपरिवेक्षकले स्वीकृत गर्छ; लेखा समितिले हेर्छ।' : 'The supervisor approves; the accounts committee watches.')}</p>)}
                </article>
              );
            })}

            {q.questions?.filter((x) => x.status === 'open').map((x) => <AnswerQuestion key={x.question_id} entity={entity} q={x} run={run} state={state} />)}
          </Section>
        );
      })}
    </Screen>
  );
}

function AnswerQuestion({ entity, q, run, state }: { entity: string; q: Row; run: ReturnType<typeof useAction>[1]; state: Record<string, SentState> }) {
  const [outcome, setOutcome] = useState('explained');
  const [answer, setAnswer] = useState('');
  const key = 'q' + q.question_id;
  return (
    <article class="task">
      <p class="item-meta">{lang.value === 'np' ? 'इन्ट्री नं.' : 'Entry'} {num(q.about_seq)} · {q.asked_by}</p>
      <p class="item-title">“{q.text_np}”</p>
      {state[key] ? <Sent s={state[key]!} /> : (
        <form class="form" onSubmit={(e) => { e.preventDefault(); if (answer.trim()) run(key, entity, 'question.closed', { question_id: q.question_id, outcome, answer_np: answer.trim() }); }}>
          <label for={`out-${key}`}>{lang.value === 'np' ? 'नतिजा' : 'Outcome'}</label>
          <select id={`out-${key}`} value={outcome} onChange={(e) => setOutcome((e.target as HTMLSelectElement).value)}>
            {(['explained', 'difference_returned', 'refunded', 'improved'] as const).map((o) => <option key={o} value={o}>{t(o)}</option>)}
          </select>
          <label for={`ans-${key}`}>{lang.value === 'np' ? 'जवाफ (सबैले देख्छन्)' : 'Answer (public)'}</label>
          <textarea id={`ans-${key}`} rows={3} value={answer} onInput={(e) => setAnswer((e.target as HTMLTextAreaElement).value)} />
          <button class="btn" type="submit">{t('answer')}</button>
        </form>
      )}
    </article>
  );
}
