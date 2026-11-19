import { signal, computed } from '@preact/signals';
import { source, type Pub, type Person } from './data/source';
import { verify, type WardReport } from './lib/chain';

export const pub = signal<Pub | null>(null);
export const loadError = signal<string | null>(null);
export const me = signal<Person | null>(null);
export const chainReport = signal<WardReport[] | null>(null);
export const route = signal<string>(location.hash.slice(1) || 'home');

window.addEventListener('hashchange', () => { route.value = location.hash.slice(1) || 'home'; window.scrollTo(0, 0); });
export const go = (r: string) => { location.hash = r === 'home' ? '' : r; if (r === 'home') route.value = 'home'; };

export const CFUG = 'thumki-cfug';
export const MPC = 'kakani-mpc';

export async function loadAll() {
  loadError.value = null;
  try {
    pub.value = await source.load();
    me.value = await source.me();
  } catch (e: any) { loadError.value = e?.message ?? String(e); }
}

export async function checkChain() {
  chainReport.value = null;
  chainReport.value = await verify(await source.chain());
}

export const byEntity = <T extends Record<string, any>>(rows: T[] | undefined, entity: string) =>
  (rows ?? []).filter((r) => r.entity_id === entity);

export const myRoles = computed(() => me.value?.roles ?? []);
export const officerRoles = computed(() =>
  myRoles.value.filter((r) => ['chair', 'secretary', 'treasurer', 'accounts_committee', 'supervisor'].includes(r.role)));
