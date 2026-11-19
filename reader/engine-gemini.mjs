// The reading engine: Gemini (Google's multimodal model) reads the photo. Same contract as the
// other engines: readings as lines of text, checked by parse.mjs. Used as an independent reader
// next to Claude, so that two different companies' models must agree before a figure gets a tick.
//
// This sends the photo to an outside service (decided by Dr. Shrestha, 2026-11-19). On Google's
// free tier Google may use the data to improve its products: use a paid-tier key for real bills.
// Settings: GEMINI_API_KEY (required), CHAUTARI_GEMINI_MODEL (default gemini-3.8-flash).
// CHAUTARI_READINGS_CACHE (a JSON file {"<file name>": {"<model>": [lines]}}) replays readings made
// elsewhere, for scoring without calling the service again.
import { readFile } from 'node:fs/promises';
import { basename, extname } from 'node:path';
import { PROMPT } from './engine-claude.mjs';

export const name = 'gemini';
export const MODEL = process.env.CHAUTARI_GEMINI_MODEL || 'gemini-3.8-flash';
// USD per million tokens [input, output], introductory list price checked 2026-11-19 (cost report only)
export const PRICES = { 'gemini-3.8-flash': [0.75, 3.75] };
export const usage = [];

export async function version() { return `gemini (${MODEL})`; }

const media = (file) => ({ '.png': 'image/png', '.webp': 'image/webp' }[extname(file).toLowerCase()] || 'image/jpeg');
let cache = null;
async function cached(file, model) {
  if (!process.env.CHAUTARI_READINGS_CACHE) return null;
  cache ??= JSON.parse(await readFile(process.env.CHAUTARI_READINGS_CACHE, 'utf8'));
  return cache[basename(file)]?.[model] ?? null;
}

export async function readOne(file, model = MODEL) {
  const hit = await cached(file, model);
  if (hit) return hit;
  const key = process.env.GEMINI_API_KEY;
  if (!key) throw new Error('GEMINI_API_KEY is not set');
  const data = (await readFile(file)).toString('base64');
  const body = { contents: [{ parts: [{ inline_data: { mime_type: media(file), data } }, { text: PROMPT }] }], generationConfig: { temperature: 0 } };
  for (let attempt = 0; ; attempt++) {
    const res = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
      { method: 'POST', headers: { 'x-goog-api-key': key, 'content-type': 'application/json' }, body: JSON.stringify(body) });
    if (res.ok) {
      const j = await res.json();
      const u = j.usageMetadata ?? {};
      const [pi, po] = PRICES[model] ?? [0, 0];
      const out = (u.candidatesTokenCount ?? 0) + (u.thoughtsTokenCount ?? 0);
      usage.push({ model, input_tokens: u.promptTokenCount ?? 0, output_tokens: out, usd: ((u.promptTokenCount ?? 0) * pi + out * po) / 1e6 });
      const text = (j.candidates?.[0]?.content?.parts ?? []).map((p) => p.text ?? '').join('\n');
      return text.split('\n').map((l) => l.trim()).filter(Boolean);
    }
    if ((res.status === 429 || res.status >= 500) && attempt < 5) { await new Promise((r) => setTimeout(r, 5000 * (attempt + 1))); continue; }
    throw new Error(`gemini ${model}: HTTP ${res.status} ${(await res.text()).slice(0, 200)}`);
  }
}

export async function readLines(file) {
  return [{ id: MODEL, lines: await readOne(file) }];
}
