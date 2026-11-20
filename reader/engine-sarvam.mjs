// The reading engine: Sarvam Vision (Sarvam AI, India), Document AI "parse". A document model built for
// Indian scripts, Nepali included (ne-IN); a third company next to Anthropic and Google, so its mistakes
// are its own. Same contract as the other engines: readings as lines of text, checked by parse.mjs.
// Price checked 2026-11-20: Rs 0.50 a page (plus GST), paid from prepaid Sarvam credit.
//
// This sends the photo to an outside service (Sarvam's servers, India).
// Settings: SARVAM_API_KEY (required), CHAUTARI_SARVAM_CONTENT (printed | handwritten | mixed, default mixed).
// CHAUTARI_READINGS_CACHE replays readings made elsewhere: {"<file name>": {"sarvam-vision": [lines]}}.
import { createReadStream } from 'node:fs';
import { readFile } from 'node:fs/promises';
import { basename } from 'node:path';
import { SarvamAIClient } from 'sarvamai';

export const name = 'sarvam';
export const ID = 'sarvam-vision';
export const CONTENT = process.env.CHAUTARI_SARVAM_CONTENT || 'mixed';
export const usage = [];
export async function version() { return `sarvam-vision (doc-ai parse, ne-IN, ${CONTENT})`; }

let cache = null;
async function cached(file) {
  if (!process.env.CHAUTARI_READINGS_CACHE) return null;
  cache ??= JSON.parse(await readFile(process.env.CHAUTARI_READINGS_CACHE, 'utf8'));
  return cache[basename(file)]?.[ID] ?? null;
}

const DONE = new Set(['completed', 'partially_completed', 'failed', 'rejected']);

export async function readOne(file, content = CONTENT) {
  const hit = await cached(file);
  if (hit) return hit;
  if (!process.env.SARVAM_API_KEY) throw new Error('SARVAM_API_KEY is not set');
  const client = new SarvamAIClient({ apiSubscriptionKey: process.env.SARVAM_API_KEY });
  const job = await client.docAi.parse({ file: [createReadStream(file)], language: 'ne-IN', content_type: content });
  let st;
  do {
    await new Promise((r) => setTimeout(r, 2000)); // Sarvam asks for at least 2 s between polls
    st = await client.docAi.getStatus(job.job_id);
  } while (!DONE.has(String(st.status).toLowerCase()));
  if (!['completed', 'partially_completed'].includes(String(st.status).toLowerCase())) throw new Error(`sarvam: job ${st.status}`);
  const res = await client.docAi.getResults(job.job_id);
  const pages = res.documents?.flatMap((d) => d.pages ?? []) ?? [];
  usage.push({ model: ID, input_tokens: 0, output_tokens: 0, usd: 0.006 * pages.length }); // Rs 0.50 a page
  return pages
    .flatMap((p) => [...(p.blocks ?? [])].sort((a, b) => (a.reading_order ?? 0) - (b.reading_order ?? 0)))
    .flatMap((b) => String(b.text ?? '').split('\n'))
    .map((l) => l.trim())
    .filter(Boolean);
}

export async function readLines(file) {
  return [{ id: ID, lines: await readOne(file) }];
}
