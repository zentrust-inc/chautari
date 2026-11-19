// The reading engine: Google Cloud Vision, DOCUMENT_TEXT_DETECTION (handwriting and print, Devanagari
// and Latin). A conventional OCR service from a different company than Claude, so its mistakes are not
// Claude's mistakes. The first 1,000 pages a month are free on our billing account (then USD 1.50 per
// 1,000), checked 2026-11-19. Same contract as the other engines: readings as lines of text.
//
// This sends the photo to an outside service (decided by Dr. Shrestha, 2026-11-19).
// Settings: VISION_API_KEY (a key limited to the Cloud Vision API). CHAUTARI_READINGS_CACHE replays
// readings made elsewhere: {"<file name>": {"vision": [lines]} or {"vision-words": [[text, [[x,y]x4]], ...]}}.
import { readFile } from 'node:fs/promises';
import { basename } from 'node:path';

export const name = 'vision';
export const usage = [];
export async function version() { return 'google-cloud-vision DOCUMENT_TEXT_DETECTION'; }

// Words (text + 4 corners) into lines of a table: straighten the page by the words' own slant, put words
// whose middles sit at the same height on one line, two spaces where a column gap is, and join a figure
// the service split in two (२ ९,१०० -> २९,१००). Kept free of imports so the same code can run in a browser.
export function visionLines(words) {
  const W = words.map(([t, v]) => {
    const [a, b, c, d] = v.map(([x, y]) => ({ x: x || 0, y: y || 0 }));
    return { t, a, b, c, d, w: Math.hypot(b.x - a.x, b.y - a.y), h: Math.hypot(d.x - a.x, d.y - a.y) };
  }).filter((w) => w.t);
  if (!W.length) return [];
  // the page's slant: median angle of the top edges of the longer words
  const angs = W.filter((w) => w.w > w.h).map((w) => Math.atan2(w.b.y - w.a.y, w.b.x - w.a.x)).sort((p, q) => p - q);
  const th = angs.length ? angs[Math.floor(angs.length / 2)] : 0;
  const cos = Math.cos(th), sin = Math.sin(th);
  const rot = (p) => ({ x: p.x * cos + p.y * sin, y: -p.x * sin + p.y * cos });
  for (const w of W) {
    const pts = [w.a, w.b, w.c, w.d].map(rot);
    const ys = pts.map((p) => p.y), xs = pts.map((p) => p.x);
    w.y0 = Math.min(...ys); w.y1 = Math.max(...ys); w.ym = (w.y0 + w.y1) / 2; w.x0 = Math.min(...xs); w.x1 = Math.max(...xs);
    w.hh = w.y1 - w.y0;
  }
  // typical text height; much taller words (a slanted watermark) would join rows together, so they go
  const hs = W.map((w) => w.hh).sort((p, q) => p - q);
  const H = hs[Math.floor(hs.length / 2)] || 1;
  const T = W.filter((w) => w.hh <= 2.2 * H).sort((p, q) => p.ym - q.ym);
  const rows = [];
  for (const w of T) {
    let best = null, dist = Infinity;
    for (const r of rows) { const dd = Math.abs(r.ym - w.ym); if (dd <= 0.55 * H && dd < dist) { best = r; dist = dd; } }
    if (best) { best.w.push(w); best.ym = best.w.reduce((s, x) => s + x.ym, 0) / best.w.length; }
    else rows.push({ ym: w.ym, h: H, w: [w] });
  }
  rows.sort((p, q) => p.ym - q.ym);
  const num = /^[0-9०-९][0-9०-९,./-]*$/;
  return rows.map((r) => {
    r.w.sort((p, q) => p.x0 - q.x0);
    let out = '', prev = null;
    for (const w of r.w) {
      if (prev) {
        const gap = w.x0 - prev.x1;
        const glue = gap < r.h * 0.45 && ((num.test(prev.t) && num.test(w.t)) || /^[,/.:)-]/.test(w.t) || /[(/,-]$/.test(prev.t));
        out += glue ? '' : gap > r.h * 1.2 ? '  ' : ' ';
      }
      out += w.t; prev = w;
    }
    return out;
  });
}

let cache = null;
async function cachedWords(file) {
  if (!process.env.CHAUTARI_READINGS_CACHE) return null;
  cache ??= JSON.parse(await readFile(process.env.CHAUTARI_READINGS_CACHE, 'utf8'));
  return cache[basename(file)]?.['vision-words'] ?? null;
}

export async function readWords(file) {
  const hit = await cachedWords(file);
  if (hit) return hit;
  const key = process.env.VISION_API_KEY;
  if (!key) throw new Error('VISION_API_KEY is not set');
  const content = (await readFile(file)).toString('base64');
  const body = { requests: [{ image: { content }, features: [{ type: 'DOCUMENT_TEXT_DETECTION' }], imageContext: { languageHints: ['ne', 'hi', 'en'] } }] };
  for (let attempt = 0; ; attempt++) {
    const res = await fetch('https://vision.googleapis.com/v1/images:annotate', { method: 'POST', headers: { 'x-goog-api-key': key, 'content-type': 'application/json' }, body: JSON.stringify(body) });
    if (res.ok) {
      const resp = (await res.json()).responses?.[0] ?? {};
      if (resp.error) throw new Error(`vision: ${resp.error.message}`);
      usage.push({ model: 'vision-document-text', input_tokens: 0, output_tokens: 0, usd: 0.0015 }); // after the free 1,000 a month
      const words = [];
      for (const p of resp.fullTextAnnotation?.pages ?? []) for (const bl of p.blocks) for (const pa of bl.paragraphs) for (const w of pa.words)
        words.push([w.symbols.map((s) => s.text).join(''), w.boundingBox.vertices.map((q) => [q.x || 0, q.y || 0])]);
      return words;
    }
    if ((res.status === 429 || res.status >= 500) && attempt < 3) { await new Promise((r) => setTimeout(r, 3000 * (attempt + 1))); continue; }
    throw new Error(`vision: HTTP ${res.status} ${(await res.text()).slice(0, 200)}`);
  }
}

export async function readLines(file) {
  if (process.env.CHAUTARI_READINGS_CACHE) {
    cache ??= JSON.parse(await readFile(process.env.CHAUTARI_READINGS_CACHE, 'utf8'));
    const lines = cache[basename(file)]?.vision;
    if (lines) return [{ id: 'vision', lines }];
  }
  return [{ id: 'vision', lines: visionLines(await readWords(file)) }];
}
