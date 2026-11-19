// पठाउन बाँकी — entries kept on the phone until there is signal.
//
// The field forms (work hours, spring and rain readings) never need signal. Each entry, with its photos,
// is kept in the phone's own storage (IndexedDB) with an id of its own, and sent when the phone is online:
// first the photos to our own server, then the entry through public.record_event_once. If the answer is
// lost on the way back, sending again returns the entry already recorded, never a second one.
//
// What can happen to an entry:
//   sent     the database recorded it (entry number), it leaves the phone
//   waiting  no signal, or the server did not answer: it stays and is sent later, by itself
//   problem  the database refused it under a rule (e.g. more than 12 hours that day): it stays, with the
//            reason, until the person removes it and records it again correctly
// An entry is sent only in the name of the person who made it; if someone else signs in on the same
// phone, it waits for its maker.
import { signal, computed } from '@preact/signals';
import { source, DemoWrite, NetworkError, type Evidence } from '../data/source';

type Row = Record<string, any>;
export interface OutItem {
  ref: string; by: string; entity: string; type: string; payload: Row; priv: Row; fy: string; on: string;
  photos: { kind: 'before' | 'after'; blob: Blob }[]; evidence?: Evidence[];
  label: string; created: number; state: 'waiting' | 'problem'; error?: string; tries: number;
}
export type Outcome = { sent: number } | { waiting: true } | { problem: string } | { demo: Row };

export const outbox = signal<OutItem[]>([]);
export const lastSent = signal<{ label: string; outcome: Outcome; at: number }[]>([]);
export const waitingCount = computed(() => outbox.value.length);

// ---------------------------------------------------------------------------
// storage: IndexedDB (keeps photos as they are); if the browser refuses it, memory for this visit
// ---------------------------------------------------------------------------
const DB = 'chautari-outbox', STORE = 'items';
let mem: Map<string, OutItem> | null = null;
let dbp: Promise<IDBDatabase> | null = null;
const db = () => (dbp ??= new Promise<IDBDatabase>((ok, bad) => {
  const r = indexedDB.open(DB, 1);
  r.onupgradeneeded = () => r.result.createObjectStore(STORE, { keyPath: 'ref' });
  r.onsuccess = () => ok(r.result); r.onerror = () => bad(r.error);
}));
async function tx<T>(mode: IDBTransactionMode, f: (s: IDBObjectStore) => IDBRequest<T>): Promise<T> {
  const d = await db();
  return new Promise<T>((ok, bad) => { const q = f(d.transaction(STORE, mode).objectStore(STORE)); q.onsuccess = () => ok(q.result); q.onerror = () => bad(q.error); });
}
async function all(): Promise<OutItem[]> {
  if (mem) return [...mem.values()];
  try { return await tx<OutItem[]>('readonly', (s) => s.getAll()); } catch { mem = new Map(); return []; }
}
async function put(i: OutItem) {
  if (!mem) { try { await tx('readwrite', (s) => s.put(i)); return; } catch { mem = new Map(); } }
  mem.set(i.ref, i);
}
async function del(ref: string) {
  if (!mem) { try { await tx('readwrite', (s) => s.delete(ref)); return; } catch { mem = new Map(); } }
  mem.delete(ref);
}
const refresh = async () => { outbox.value = (await all()).sort((a, b) => a.created - b.created); };

// a random id; older phones may lack crypto.randomUUID
export function newId(): string {
  if (typeof crypto.randomUUID === 'function') return crypto.randomUUID();
  const b = crypto.getRandomValues(new Uint8Array(16));
  b[6] = (b[6] & 0x0f) | 0x40; b[8] = (b[8] & 0x3f) | 0x80;
  const h = [...b].map((x) => x.toString(16).padStart(2, '0')).join('');
  return `${h.slice(0, 8)}-${h.slice(8, 12)}-${h.slice(12, 16)}-${h.slice(16, 20)}-${h.slice(20)}`;
}

// ---------------------------------------------------------------------------
// sending
// ---------------------------------------------------------------------------
async function sendOne(i: OutItem): Promise<Outcome> {
  try {
    if (i.photos.length && !(i.evidence?.length === i.photos.length)) {
      const ev: Evidence[] = [];
      for (const p of i.photos) ev.push(await source.keepPhoto(i.entity, p.kind, p.blob));
      i.evidence = ev; await put(i);   // photos kept on the server; not sent again
    }
    const r = await source.recordOnce(i.ref, i.entity, i.type, i.payload, i.priv, i.fy, i.on, i.evidence ?? []);
    await del(i.ref);
    return { sent: r.seq };
  } catch (e) {
    if (e instanceof DemoWrite) { await del(i.ref); return { demo: e.entry }; }
    if (e instanceof NetworkError) { i.tries++; await put(i); return { waiting: true }; }
    i.state = 'problem'; i.error = (e as Error).message; await put(i);
    return { problem: i.error };
  }
}

let running: Promise<void> | null = null;
/** send everything that is waiting and belongs to the person signed in now */
export function flush(me: string | undefined): Promise<void> {
  return (running ??= (async () => {
    try {
      for (const i of await all()) {
        if (i.state !== 'waiting' || i.by !== me) continue;
        if (typeof navigator !== 'undefined' && navigator.onLine === false) break;
        const out = await sendOne(i);
        if (!('waiting' in out)) lastSent.value = [{ label: i.label, outcome: out, at: Date.now() }, ...lastSent.value].slice(0, 10);
        else break;   // no signal after all: try the rest later
      }
    } finally { running = null; await refresh(); }
  })());
}

/** keep an entry on the phone, then try to send it at once; the form shows what happened */
export async function submit(me: string, entity: string, type: string, payload: Row, priv: Row, fy: string, on: string,
  photos: OutItem['photos'], label: string): Promise<Outcome> {
  const item: OutItem = { ref: newId(), by: me, entity, type, payload, priv, fy, on, photos, label, created: Date.now(), state: 'waiting', tries: 0 };
  await put(item);
  if (running) await running;
  let out: Outcome = { waiting: true };
  if (navigator.onLine !== false) out = await sendOne(item);
  // refused at once: the form is still filled in, so the person fixes it there; nothing stays on the phone
  if ('problem' in out) await del(item.ref);
  await refresh();
  if ('sent' in out || 'demo' in out) lastSent.value = [{ label, outcome: out, at: Date.now() }, ...lastSent.value].slice(0, 10);
  return out;
}

/** the person removes an entry the database refused (or one they no longer want sent) */
export async function remove(ref: string) { await del(ref); await refresh(); }

/** after a refused entry is fixed elsewhere, or to try a waiting one again now */
export async function retry(ref: string, me: string | undefined) {
  const i = (await all()).find((x) => x.ref === ref);
  if (i && i.state === 'problem') { i.state = 'waiting'; i.error = undefined; await put(i); }
  await flush(me);
}

export async function start(me: () => string | undefined) {
  await refresh();
  const go = () => { if (outbox.value.some((i) => i.state === 'waiting')) flush(me()); };
  window.addEventListener('online', go);
  document.addEventListener('visibilitychange', () => { if (document.visibilityState === 'visible') go(); });
  setInterval(go, 60_000);
  go();
}
