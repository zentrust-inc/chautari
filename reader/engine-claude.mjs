// The reading engine: Claude (a multimodal model, Anthropic's API) reads the photo.
// Same shape as engine-tesseract.mjs: several independent readings of one photo, as lines of text,
// so parse.mjs checks the sums and asks whether the readings agree. Each reading is a different
// Claude model, so one model's habit (for example ५ read as ६) is less likely to repeat in the other.
//
// This sends the photo to an outside service (decided by Dr. Shrestha, 2026-11-19).
// Settings (environment): ANTHROPIC_API_KEY (required), CHAUTARI_VLM_MODELS (comma list,
// default claude-sonnet-5-5,claude-opus-5-5).
import { readFile } from 'node:fs/promises';
import { extname } from 'node:path';

export const name = 'claude';
const API = 'https://api.anthropic.com/v1/messages';
export const MODELS = (process.env.CHAUTARI_VLM_MODELS || 'claude-sonnet-5-5,claude-opus-5-5').split(',').map((s) => s.trim()).filter(Boolean);

// USD per million tokens [input, output], list prices checked 2026-11-19; only used for the cost report.
export const PRICES = { 'claude-sonnet-5-5': [2, 10], 'claude-opus-5-5': [4, 20], 'claude-haiku-5-5': [0.1, 0.5] };
export const usage = []; // {model, input_tokens, output_tokens, usd}

export async function version() { return `claude (${MODELS.join(' + ')})`; }

export const PROMPT = `Transcribe this photo of a Nepali bill, receipt or cash-book page, line by line, top to bottom.
Rules:
- Copy exactly what is written. Keep Devanagari digits as Devanagari (१२३) and Latin digits as Latin (123). Do not translate, correct or complete anything.
- One output line per printed or written line. For a table row (cash book or bill item), put the whole row on one line, cells in order left to right, separated by two spaces. Leave an empty cell out.
- Keep commas, slashes, "/-" and minus signs in numbers as written.
- If a character is unclear, write your best reading of it and nothing else (no notes, no question marks).
- Skip the "SAMPLE / नमूना" watermark and the footer line about the sample.
Output only the transcription, no preface.`;

const media = (file) => ({ '.png': 'image/png', '.webp': 'image/webp', '.gif': 'image/gif' }[extname(file).toLowerCase()] || 'image/jpeg');

async function readOne(model, b64, type, key) {
  const body = { model, max_tokens: 2000, messages: [{ role: 'user', content: [
    { type: 'image', source: { type: 'base64', media_type: type, data: b64 } },
    { type: 'text', text: PROMPT } ] }] };
  for (let attempt = 0; ; attempt++) {
    const res = await fetch(API, { method: 'POST', headers: { 'x-api-key': key, 'anthropic-version': '2023-06-01', 'content-type': 'application/json' }, body: JSON.stringify(body) });
    if (res.ok) {
      const j = await res.json();
      const [pi, po] = PRICES[model] ?? [0, 0];
      const u = j.usage ?? {};
      usage.push({ model, input_tokens: u.input_tokens ?? 0, output_tokens: u.output_tokens ?? 0, usd: ((u.input_tokens ?? 0) * pi + (u.output_tokens ?? 0) * po) / 1e6 });
      const text = (j.content ?? []).filter((c) => c.type === 'text').map((c) => c.text).join('\n');
      return text.split('\n').map((l) => l.trim()).filter(Boolean);
    }
    if ((res.status === 429 || res.status >= 500) && attempt < 3) { await new Promise((r) => setTimeout(r, 2000 * (attempt + 1))); continue; }
    throw new Error(`claude ${model}: HTTP ${res.status} ${(await res.text()).slice(0, 200)}`);
  }
}

export async function readLines(file, { models = MODELS } = {}) {
  const key = process.env.ANTHROPIC_API_KEY;
  if (!key) throw new Error('ANTHROPIC_API_KEY is not set');
  const b64 = (await readFile(file)).toString('base64');
  const type = media(file);
  return Promise.all(models.map(async (m) => ({ id: m, lines: await readOne(m, b64, type, key) })));
}
