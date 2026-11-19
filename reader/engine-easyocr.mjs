// Second reading engine: EasyOCR (Devanagari + English models), on our own server, no outside service.
// Same contract as engine-tesseract.mjs: several readings of one photo so parse.mjs can ask whether they agree.
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const run = promisify(execFile);
const here = dirname(fileURLToPath(import.meta.url));
export const name = 'easyocr';
export const LANG = process.env.CHAUTARI_EASYOCR_LANGS || 'ne,en';
export const PASSES = [
  { id: 'plain', prep: [] },
  { id: 'gray-200', prep: ['-auto-orient', '-colorspace', 'Gray', '-resize', '200%', '-normalize'] },
];
export async function version() {
  try { const { stdout } = await run('python3', ['-c', 'import easyocr;print(easyocr.__version__)']); return `easyocr ${stdout.trim()}`; } catch { return 'easyocr (not found)'; }
}
export async function readLines(file, { passes = PASSES } = {}) {
  const dir = await mkdtemp(join(tmpdir(), 'chautari-easy-'));
  try {
    const inputs = await Promise.all(passes.map(async (p, i) => {
      if (!p.prep.length) return file;
      const out = join(dir, `p${i}.png`); await run('convert', [file, ...p.prep, out], { maxBuffer: 1 << 26 }); return out;
    }));
    const { stdout } = await run('python3', ['-I', join(here, 'easyocr_lines.py'), ...inputs], { maxBuffer: 1 << 26, timeout: 900000 });
    const got = JSON.parse(stdout);
    return passes.map((p, i) => ({ id: p.id, lines: got[inputs[i]] || [] }));
  } finally { await rm(dir, { recursive: true, force: true }); }
}
