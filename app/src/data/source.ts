// Where the app's data comes from.
//   live  : the real database through Supabase (public views, my_record, officer_* and record_event)
//   sample: a snapshot exported from a database built with seed/demo.sql (fictional people)
// Both return exactly the shapes the database's public API returns, so every screen
// works the same way in both modes.
import { signal } from '@preact/signals';
import type { ChainRow } from '../lib/chain';

type Row = Record<string, any>;
export interface Pub {
  bodies: Row[]; money_status: Row[]; income_and_spending: Row[]; budget_status: Row[]; spending_shares: Row[];
  payments: Row[]; fair_turns: Row[]; project_hours: Row[]; office_holders: Row[]; nature_readings: Row[];
  questions: Row[]; rules: Row[]; mpc_summary: Row[]; loan_register: Row[]; grant_register: Row[];
  enterprise_results: Row[]; surplus_allocations: Row[]; chain_heads: Row[];
}
export interface Person { id: string; name: string; house_no?: number; roles: { entity: string; role: string }[] }
export interface OfficerQueues { payments_waiting?: Row[]; work_waiting?: Row[]; questions?: Row[]; suggestions?: Row[]; workers?: Row[] }
// a photo attached to an entry: it stays on our own server, the chain carries its SHA-256
export interface Evidence { sha256: string; kind: string; path: string }

export class DemoWrite extends Error {
  constructor(public entry: { entity: string; type: string; payload: Row; private?: Row; evidence?: Row[]; note?: string }) { super('sample mode'); }
}

// A bill read by the reader: fields with 'ok' or 'check', flags, items. See reader/parse.mjs.
export interface Reading {
  suggestion_id?: string; id?: string; image?: string; label?: string; quality?: string;
  doc: { sha256: string; bytes?: number; ext?: string; kind?: string }; reader: string;
  fields: Record<string, { value: any; status: 'ok' | 'check'; why?: string; alts?: any[] }>;
  flags: { field: string; code: string; np: string; en: string }[];
  items: { name: string; qty: number | null; rate: number | null; amount: number }[];
}
// The fields a person can change; the database compares the same ones (confirm_suggestion)
export const CONFIRM_KEYS = ['amount', 'account_code', 'payee_id', 'method', 'budget_line_id', 'memo_np', 'receipt_no', 'bill_no', 'estimated'];

export interface Source {
  mode: 'live' | 'sample';
  load(): Promise<Pub>;
  chain(): Promise<ChainRow[]>;
  samplePeople?(): Person[];
  signInAs?(id: string): void;
  sendCode?(phone: string): Promise<void>;
  verifyCode?(phone: string, code: string): Promise<void>;
  signOut(): Promise<void>;
  me(): Promise<Person | null>;
  myRecord(): Promise<Row | null>;
  myAccount(entity: string): Promise<Row | null>;
  officer(entity: string, roles: string[]): Promise<OfficerQueues>;
  record(entity: string, type: string, payload: Row, priv?: Row, fiscalYear?: string, occurredOn?: string, evidence?: Evidence[]): Promise<Row>;
  // the work-hours form: who the hours can be written for, and keeping a before/after photo
  officerWorkers(entity: string): Promise<Row[]>;
  keepPhoto(entity: string, kind: 'before' | 'after', photo: Blob): Promise<Evidence>;
  // the document reader (it suggests; a named person confirms)
  officerPayees(entity: string): Promise<Row[]>;
  sampleReadings?(): Promise<{ payees: Row[]; bills: Reading[] }>;
  readBill?(entity: string, file: File): Promise<Reading>;
  confirmSuggestion(entity: string, reading: Reading, type: string, payload: Row, occurredOn: string, fiscalYear: string): Promise<Row>;
  rejectSuggestion(reading: Reading, reason: string): Promise<void>;
}

// what the person changed from the reader's suggestion (shown in the sample; the database works it out for real)
export function changedFields(suggested: Row, payload: Row, suggestedDate: string | null, date: string) {
  const ch = CONFIRM_KEYS.filter((k) => {
    const a = suggested[k], b = payload[k];
    if (a == null && b == null) return false;
    if (k === 'amount' && a != null && b != null) return Number(a) !== Number(b);
    return JSON.stringify(a) !== JSON.stringify(b);
  });
  if ((suggestedDate ?? null) !== date) ch.push('date');
  return ch;
}

// SHA-256 of a photo, as hex. crypto.subtle exists on https and on the phone's own files; the sample needs nothing else.
export async function sha256Hex(b: Blob): Promise<string> {
  const buf = await crypto.subtle.digest('SHA-256', await b.arrayBuffer());
  return [...new Uint8Array(buf)].map((x) => x.toString(16).padStart(2, '0')).join('');
}

const VIEWS: (keyof Pub)[] = ['bodies', 'money_status', 'income_and_spending', 'budget_status', 'spending_shares',
  'payments', 'fair_turns', 'project_hours', 'office_holders', 'nature_readings', 'questions', 'rules',
  'mpc_summary', 'loan_register', 'grant_register', 'enterprise_results', 'surplus_allocations', 'chain_heads'];

// the last good public data is kept so the notice board still opens without internet
const CACHE = 'wwos.public.v1';
const keep = (p: Pub) => { try { localStorage.setItem(CACHE, JSON.stringify(p)); } catch { /* full or off */ } };
const kept = (): Pub | null => { try { return JSON.parse(localStorage.getItem(CACHE) || 'null'); } catch { return null; } };
export const offline = signal(false);

// ---------------------------------------------------------------------------
// sample mode
// ---------------------------------------------------------------------------
function sampleSource(): Source {
  let snap: any = null;
  const get = async () => (snap ??= (await import('./sample-snapshot.json')).default);
  let who: string | null = (() => { try { return sessionStorage.getItem('wwos.sample.as'); } catch { return null; } })();
  const person = () => snap?.people.find((p: any) => p.auth === who) ?? null;
  return {
    mode: 'sample',
    async load() { const s = await get(); return s.public as Pub; },
    async chain() { const s = await get(); return s.public.chain_export as ChainRow[]; },
    samplePeople: () => (snap?.people ?? []).map((p: any) => ({ id: p.auth, name: p.name, house_no: p.house_no, roles: p.roles })),
    signInAs(id) { who = id; try { sessionStorage.setItem('wwos.sample.as', id); } catch { /* fine */ } },
    async signOut() { who = null; try { sessionStorage.removeItem('wwos.sample.as'); } catch { /* fine */ } },
    async me() { await get(); const p = person(); return p && { id: p.auth, name: p.name, house_no: p.house_no, roles: p.roles }; },
    async myRecord() { await get(); return person()?.my_record ?? null; },
    async myAccount() { await get(); return person()?.my_account ?? null; },
    async officer(entity) { await get(); return person()?.officer?.[entity] ?? {}; },
    async record(entity, type, payload, priv, _fy, _on, evidence) { throw new DemoWrite({ entity, type, payload, private: priv, ...(evidence?.length ? { evidence } : {}) }); },
    async officerWorkers(entity) { await get(); return person()?.officer?.[entity]?.workers ?? []; },
    // in the sample the photo stays on the phone; only its fingerprint is shown, as the real entry would carry it
    async keepPhoto(entity, kind, photo) { const sha256 = await sha256Hex(photo); return { sha256, kind, path: `documents/${entity}/${sha256}.jpg` }; },
    async officerPayees() { return (await import('./sample-readings.json')).default.payees; },
    async sampleReadings() { return (await import('./sample-readings.json')).default as any; },
    async confirmSuggestion(entity, reading, type, payload, occurredOn) {
      const suggested = (reading as any).suggested_payload ?? {};
      const changed = changedFields(suggested, payload, (reading as any).suggested_date ?? null, occurredOn);
      throw new DemoWrite({
        entity, type,
        payload: { ...payload, ai_read: { reader: reading.reader, suggestion: '(नमुना)', changed } },
        evidence: [{ sha256: reading.doc.sha256, kind: 'bill_photo', path: `documents/${entity}/${reading.doc.sha256}.jpg` }],
      });
    },
    async rejectSuggestion(reading, reason) {
      throw new DemoWrite({ entity: '', type: 'suggestion rejected (not an entry)', payload: { reason, photo_sha256: reading.doc.sha256 },
        note: 'reject' });
    },
  };
}

// ---------------------------------------------------------------------------
// live mode (Supabase). Loaded only when configured, so sample mode stays small.
// ---------------------------------------------------------------------------
function liveSource(url: string, key: string): Source {
  let client: any = null;
  const sb = async () => {
    if (client) return client;
    const { createClient } = await import('@supabase/supabase-js');
    return (client = createClient(url, key, { auth: { persistSession: true } }));
  };
  const ok = <T,>({ data, error }: { data: T; error: any }) => { if (error) throw new Error(error.message); return data; };
  let recordCache: Row | null = null;
  return {
    mode: 'live',
    async load() {
      try {
        const c = await sb();
        const res = await Promise.all(VIEWS.map((v) => c.from(v).select('*')));
        const p = Object.fromEntries(VIEWS.map((v, i) => [v, ok(res[i])])) as unknown as Pub;
        keep(p); offline.value = false; return p;
      } catch (e) {
        const p = kept(); if (!p) throw e; offline.value = true; return p;
      }
    },
    async chain() { return ok(await (await sb()).from('chain_export').select('*').order('seq')) as ChainRow[]; },
    async sendCode(phone) { ok(await (await sb()).auth.signInWithOtp({ phone: '+977' + phone.replace(/\D/g, '').slice(-10) })); },
    async verifyCode(phone, code) {
      ok(await (await sb()).auth.verifyOtp({ phone: '+977' + phone.replace(/\D/g, '').slice(-10), token: code, type: 'sms' }));
    },
    async signOut() { recordCache = null; await (await sb()).auth.signOut(); },
    async me() {
      const c = await sb();
      const { data } = await c.auth.getSession();
      if (!data.session) return null;
      try { recordCache = ok(await c.rpc('my_record')); } catch { return null; }
      const r = recordCache!;
      return { id: r.person.id, name: r.person.name, house_no: r.person.house_no, roles: r.roles };
    },
    async myRecord() { return recordCache ?? ok(await (await sb()).rpc('my_record')); },
    async myAccount(entity) { try { return ok(await (await sb()).rpc('my_account', { p_entity: entity })); } catch { return null; } },
    async officer(entity, roles) {
      const c = await sb(); const q: OfficerQueues = {};
      const money = roles.some((r) => ['chair', 'secretary', 'treasurer', 'accounts_committee'].includes(r));
      if (money) q.payments_waiting = ok(await c.rpc('officer_payments_waiting', { p_entity: entity }));
      if (roles.some((r) => r === 'supervisor' || r === 'accounts_committee'))
        q.work_waiting = ok(await c.rpc('officer_work_waiting', { p_entity: entity }));
      if (roles.includes('accounts_committee')) q.questions = ok(await c.rpc('officer_questions', { p_entity: entity }));
      if (roles.some((r) => r === 'treasurer' || r === 'ledger_keeper'))
        q.suggestions = ok(await c.rpc('officer_suggestions', { p_entity: entity }));
      return q;
    },
    async record(entity, type, payload, priv = {}, fiscalYear, occurredOn, evidence) {
      return ok(await (await sb()).rpc('record_event', {
        p_entity: entity, p_type: type, p_payload: payload, p_private: priv, p_fiscal_year: fiscalYear ?? null,
        ...(occurredOn ? { p_occurred_on: occurredOn } : {}), ...(evidence?.length ? { p_evidence: evidence } : {}),
      }));
    },
    async officerWorkers(entity) { return ok(await (await sb()).rpc('officer_workers', { p_entity: entity })) as Row[]; },
    async keepPhoto(entity, kind, photo) {
      // the photo goes to our own server only (reader/server.mjs /photo), which keeps it under its SHA-256
      if (!READER) throw new Error('the photo service is not set up (VITE_READER_URL)');
      const c = await sb(); const { data } = await c.auth.getSession();
      const res = await fetch(`${READER}/photo?entity=${encodeURIComponent(entity)}&kind=${kind}`, {
        method: 'POST', body: photo,
        headers: { 'content-type': photo.type || 'image/jpeg', authorization: `Bearer ${data.session?.access_token ?? ''}` },
      });
      if (!res.ok) throw new Error((await res.text()) || res.statusText);
      return res.json();
    },
    async officerPayees(entity) { return ok(await (await sb()).rpc('officer_payees', { p_entity: entity })) as Row[]; },
    async readBill(entity, file) {
      // the reader runs on our own server; the photo goes nowhere else
      if (!READER) throw new Error('the reader is not set up (VITE_READER_URL)');
      const c = await sb(); const { data } = await c.auth.getSession();
      const res = await fetch(`${READER}/read?entity=${encodeURIComponent(entity)}&kind=bill`, {
        method: 'POST', body: file,
        headers: { 'content-type': file.type || 'image/jpeg', authorization: `Bearer ${data.session?.access_token ?? ''}` },
      });
      if (!res.ok) throw new Error((await res.text()) || res.statusText);
      return res.json();
    },
    async confirmSuggestion(_entity, reading, type, payload, occurredOn, fiscalYear) {
      return ok(await (await sb()).rpc('confirm_suggestion', {
        p_suggestion: reading.suggestion_id, p_type: type, p_payload: payload, p_occurred_on: occurredOn, p_fiscal_year: fiscalYear,
      }));
    },
    async rejectSuggestion(reading, reason) {
      ok(await (await sb()).rpc('reject_suggestion', { p_suggestion: reading.suggestion_id, p_reason: reason }));
    },
  };
}
const READER = import.meta.env.VITE_READER_URL as string | undefined;

const URL_ = import.meta.env.VITE_SUPABASE_URL, KEY = import.meta.env.VITE_SUPABASE_ANON_KEY;
export const source: Source = !__PREVIEW__ && URL_ && KEY ? liveSource(URL_, KEY) : sampleSource();
