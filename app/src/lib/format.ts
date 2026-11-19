import NepaliDate from 'nepali-date-converter';
import { lang } from './i18n';

const NP_DIGITS = '०१२३४५६७८९';
export const digits = (s: string | number) =>
  lang.value === 'np' ? String(s).replace(/[0-9]/g, (d) => NP_DIGITS[+d]) : String(s);

// 2,16,700 — Nepali grouping (lakh, crore)
export function num(n: number | string | null | undefined, frac = 0): string {
  const v = Number(n ?? 0);
  const s = v.toLocaleString('en-IN', { minimumFractionDigits: frac, maximumFractionDigits: frac });
  return digits(s);
}
export const rs = (n: number | string | null | undefined) => (lang.value === 'np' ? 'रु ' : 'Rs ') + num(n);
export const hours = (n: number | string) => {
  const v = Number(n);
  return num(v, Number.isInteger(v) ? 0 : 1) + (lang.value === 'np' ? ' घण्टा' : ' h');
};
export const pct = (n: number) => num(Math.round(n)) + '%';

const toBS = (iso: string) => {
  const [y, m, d] = iso.slice(0, 10).split('-').map(Number);
  return new NepaliDate(new Date(y, m - 1, d));
};
// "२५ कार्तिक २०८३" / "25 Kartik 2083"
export const bsDate = (iso: string | null | undefined) =>
  iso ? toBS(iso).format('DD MMMM YYYY', lang.value === 'np' ? 'np' : 'en') : '';
export const bsMonth = (iso: string) => toBS(iso).format('MMMM YYYY', lang.value === 'np' ? 'np' : 'en');
export const bsShort = (iso: string) => toBS(iso).format('DD MMMM', lang.value === 'np' ? 'np' : 'en');

// Nepal's fiscal year starts on 1 Shrawan: 2083/84 runs from Shrawan 2083 to Asar 2084
export function fiscalYear(d = new Date()): string {
  const n = new NepaliDate(d);
  const y = n.getMonth() >= 3 ? n.getYear() : n.getYear() - 1;
  return `${y}/${String((y + 1) % 100).padStart(2, '0')}`;
}
export const todayBS = () => bsDate(new Date().toISOString());

export function sum<T>(rows: T[], f: (r: T) => number) {
  return rows.reduce((a, r) => a + (Number(f(r)) || 0), 0);
}

// The database groups some totals by calendar (AD) month; show that month as its BS dates.
export function monthRange(iso: string) {
  const [y, m] = iso.slice(0, 7).split('-').map(Number);
  const last = new Date(Date.UTC(y, m, 0)).toISOString().slice(0, 10);
  return `${bsShort(iso)} – ${bsShort(last)}`;
}
