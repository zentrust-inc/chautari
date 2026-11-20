// Several outside readers at once: each reading must come from a different model, and parse.mjs
// ticks a figure only when at least two readings agree and the sums fit.
// CHAUTARI_MIX lists the readers (default: claude-opus-5-5,vision = Claude + Google Cloud Vision, two companies,
// about USD 0.019 a page; Vision's first 1,000 pages a month are free). Also possible: gemini-3.8-flash, claude-sonnet-5-5,
// sarvam (Sarvam Vision, Rs 0.50 a page).
import * as claude from './engine-claude.mjs';
import * as gemini from './engine-gemini.mjs';
import * as vision from './engine-vision.mjs';
import * as sarvam from './engine-sarvam.mjs';

export const name = 'mix';
export const READERS = (process.env.CHAUTARI_MIX || 'claude-opus-5-5,vision').split(',').map((s) => s.trim()).filter(Boolean);
export const usage = { get all() { return [...claude.usage, ...gemini.usage, ...vision.usage, ...sarvam.usage]; } };
export async function version() { return `mix (${READERS.join(' + ')})`; }

export async function readLines(file) {
  const cl = READERS.filter((m) => m.startsWith('claude'));
  const gm = READERS.filter((m) => m.startsWith('gemini'));
  const parts = await Promise.all([
    cl.length ? claude.readLines(file, { models: cl }) : [],
    ...gm.map(async (m) => [{ id: m, lines: await gemini.readOne(file, m) }]),
    READERS.includes('vision') ? vision.readLines(file) : [],
    READERS.includes('sarvam') ? sarvam.readLines(file) : [],
  ]);
  return parts.flat();
}
