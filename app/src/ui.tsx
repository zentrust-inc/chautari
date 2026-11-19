import type { ComponentChildren } from 'preact';
import { t, type Key } from './lib/i18n';
import { digits, num } from './lib/format';
import { go } from './state';

export function Screen({ title, back = true, children }: { title: string; back?: boolean; children: ComponentChildren }) {
  return (
    <main class="screen">
      {back && <button class="back" onClick={() => go('home')}>← {t('back')}</button>}
      <h1 class="screen-title">{title}</h1>
      {children}
    </main>
  );
}

export function Section({ title, note, children }: { title: string; note?: string; children: ComponentChildren }) {
  return (
    <section class="section">
      <h2>{title}</h2>
      {note && <p class="note">{note}</p>}
      {children}
    </section>
  );
}

export function Stat({ label, value, sub }: { label: string; value: string; sub?: string }) {
  return (
    <div class="stat">
      <span class="stat-label">{label}</span>
      <span class="stat-value">{value}</span>
      {sub && <span class="stat-sub">{sub}</span>}
    </div>
  );
}

export const Pill = ({ tone = 'neutral', children }: { tone?: 'good' | 'warn' | 'bad' | 'neutral' | 'water'; children: ComponentChildren }) =>
  <span class={`pill pill-${tone}`}>{children}</span>;

// a meter: how much of a budget or a requirement is used
export function Meter({ value, max, tone = 'accent', mark }: { value: number; max: number; tone?: string; mark?: number }) {
  const w = max > 0 ? Math.min(100, (value / max) * 100) : 0;
  return (
    <div class="meter" role="img" aria-label={`${Math.round(w)}%`}>
      <div class={`meter-fill meter-${tone}`} style={{ width: `${w}%` }} />
      {mark != null && max > 0 && <div class="meter-mark" style={{ left: `${Math.min(100, (mark / max) * 100)}%` }} />}
    </div>
  );
}

// a small line chart drawn to one scale; labels name values the data reaches
export function LineChart({ points, unit, tone = 'water' }: { points: { x: string; y: number; label: string }[]; unit: string; tone?: string }) {
  if (points.length < 2) return null;
  const W = 320, H = 140, L = 34, R = 10, T = 12, B = 26;
  const ys = points.map((p) => p.y);
  const lo = Math.floor(Math.min(...ys)), hi = Math.ceil(Math.max(...ys));
  const span = Math.max(hi - lo, 1);
  const x = (i: number) => L + (i * (W - L - R)) / (points.length - 1);
  const y = (v: number) => T + (1 - (v - lo) / span) * (H - T - B);
  const d = points.map((p, i) => `${i ? 'L' : 'M'}${x(i).toFixed(1)},${y(p.y).toFixed(1)}`).join(' ');
  const area = `${d} L${x(points.length - 1).toFixed(1)},${H - B} L${L},${H - B} Z`;
  const last = points[points.length - 1];
  const ticks = [lo, (lo + hi) / 2, hi];
  return (
    <svg class={`chart chart-${tone}`} viewBox={`0 0 ${W} ${H}`} role="img" aria-label={`${unit}`}>
      {ticks.map((v) => (
        <g key={v}>
          <line x1={L} x2={W - R} y1={y(v)} y2={y(v)} class="grid" />
          <text x={L - 6} y={y(v) + 4} text-anchor="end" class="tick">{num(v, Number.isInteger(v) ? 0 : 1)}</text>
        </g>
      ))}
      <path d={area} class="area" />
      <path d={d} class="line" fill="none" />
      {points.map((p, i) => <circle key={i} cx={x(i)} cy={y(p.y)} r={i === points.length - 1 ? 4.5 : 2.5} class={i === points.length - 1 ? 'dot-end' : 'dot'} />)}
      <text x={L} y={H - 6} class="tick">{points[0].label}</text>
      <text x={W - R} y={H - 6} text-anchor="end" class="tick">{last.label}</text>
    </svg>
  );
}

export function Empty({ k }: { k: Key }) { return <p class="empty">{t(k)}</p>; }
export const N = ({ v }: { v: string | number }) => <>{digits(v)}</>;

// simple glyphs for the four tiles, drawn rather than emoji
export const Glyph = ({ name }: { name: 'money' | 'work' | 'nature' | 'decisions' | 'coop' }) => {
  const p: Record<string, string> = {
    money: 'M4 7h16v10H4z M12 9.5a2.5 2.5 0 1 0 0 5a2.5 2.5 0 1 0 0-5 M7 7v10 M17 7v10',
    work: 'M5 20l7-7 M10 11l3-3 4 4-3 3z M14 4c3 0 6 3 6 6',
    nature: 'M12 3c-4 5-6 8-6 11a6 6 0 0 0 12 0c0-3-2-6-6-11z M9 15c0 2 1.3 3 3 3',
    decisions: 'M6 5h12v10H9l-3 3z M9 9h6 M9 12h4',
    coop: 'M8 11a3 3 0 1 0 0-6a3 3 0 1 0 0 6 M16 11a3 3 0 1 0 0-6a3 3 0 1 0 0 6 M3 19c0-3 2.5-5 5-5s5 2 5 5 M11 19c0-3 2.5-5 5-5s5 2 5 5',
  };
  return <svg class="glyph" viewBox="0 0 24 24" aria-hidden="true"><path d={p[name]} /></svg>;
};
