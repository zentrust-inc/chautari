// readDocument(file): a photo in, a suggestion out. The suggestion is data for a person to check.
import { createHash } from 'node:crypto';
import { readFile, stat } from 'node:fs/promises';
import { extname } from 'node:path';
import * as tesseract from './engine-tesseract.mjs';
import * as claude from './engine-claude.mjs';

// Which engine reads: CHAUTARI_READER=claude (two Claude models, outside service, needs ANTHROPIC_API_KEY)
// or tesseract (default, on our own server).
export const DEFAULT_ENGINE = process.env.CHAUTARI_READER === 'claude' ? claude : tesseract;
import { parseBill, parseCashbook, mergePasses, mergeCashbookPasses } from './parse.mjs';

export const READER_VERSION = '0.1.0';

export async function sha256File(file) {
  return createHash('sha256').update(await readFile(file)).digest('hex');
}

/** @param kind 'bill' | 'cashbook' (the person says which when they photograph it) */
export async function readDocument(file, { kind = 'bill', engine = DEFAULT_ENGINE, today } = {}) {
  const sha = await sha256File(file);
  const { size } = await stat(file);
  const readings = await engine.readLines(file);
  const doc = { sha256: sha, bytes: size, ext: extname(file).slice(1).toLowerCase() || 'jpg', kind };
  const reader = { name: `chautari-reader/${READER_VERSION}`, engine: engine.name, engine_version: await engine.version(), passes: readings.map((r) => r.id) };
  if (kind === 'cashbook') {
    const rows = mergeCashbookPasses(readings.map((r) => parseCashbook(r.lines)));
    return { doc, reader, kind: 'cashbook', rows };
  }
  const parsed = readings.map((r) => parseBill(r.lines));
  const merged = mergePasses(parsed, { today });
  return { doc, reader, kind: 'bill', ...merged, text: readings[0]?.lines ?? [] };
}
