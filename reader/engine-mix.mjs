// Several outside readers at once: each reading must come from a different model, and parse.mjs
// ticks a figure only when at least two readings agree and the sums fit.
// CHAUTARI_MIX lists the readers (default: claude-sonnet-5-5,gemini-3.8-flash: two companies, about USD 0.015 a page).
import * as claude from './engine-claude.mjs';
import * as gemini from './engine-gemini.mjs';

export const name = 'mix';
export const READERS = (process.env.CHAUTARI_MIX || 'claude-sonnet-5-5,gemini-3.8-flash').split(',').map((s) => s.trim()).filter(Boolean);
export const usage = { get all() { return [...claude.usage, ...gemini.usage]; } };
export async function version() { return `mix (${READERS.join(' + ')})`; }

export async function readLines(file) {
  const cl = READERS.filter((m) => m.startsWith('claude'));
  const gm = READERS.filter((m) => m.startsWith('gemini'));
  const parts = await Promise.all([
    cl.length ? claude.readLines(file, { models: cl }) : [],
    ...gm.map(async (m) => [{ id: m, lines: await gemini.readOne(file, m) }]),
  ]);
  return parts.flat();
}
