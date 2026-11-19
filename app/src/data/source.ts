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
export interface OfficerQueues { payments_waiting?: Row[]; work_waiting?: Row[]; questions?: Row[] }

export class DemoWrite extends Error {
  constructor(public entry: { entity: string; type: string; payload: Row; private?: Row }) { super('sample mode'); }
}

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
  record(entity: string, type: string, payload: Row, priv?: Row, fiscalYear?: string): Promise<Row>;
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
    async record(entity, type, payload, priv) { throw new DemoWrite({ entity, type, payload, private: priv }); },
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
      return q;
    },
    async record(entity, type, payload, priv = {}, fiscalYear) {
      return ok(await (await sb()).rpc('record_event', {
        p_entity: entity, p_type: type, p_payload: payload, p_private: priv, p_fiscal_year: fiscalYear ?? null,
      }));
    },
  };
}

const URL_ = import.meta.env.VITE_SUPABASE_URL, KEY = import.meta.env.VITE_SUPABASE_ANON_KEY;
export const source: Source = !__PREVIEW__ && URL_ && KEY ? liveSource(URL_, KEY) : sampleSource();
