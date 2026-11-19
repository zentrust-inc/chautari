// The reading engine: Tesseract on our own server, no outside service.
// It returns several readings of the same photo (different clean-ups and layouts) so that
// parse.mjs can ask whether they agree. Swap this file to change the engine; nothing else knows about it.
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const run = promisify(execFile);
export const name = 'tesseract';

// the clean-ups, each paired with a page-layout mode
export const PASSES = [
  { id: 'plain', prep: [], psm: 6 },
  { id: 'gray-250', prep: ['-auto-orient', '-colorspace', 'Gray', '-resize', '250%', '-normalize'], psm: 6 },
  { id: 'levels-300', prep: ['-auto-orient', '-colorspace', 'Gray', '-resize', '300%', '-level', '20%,80%', '-sharpen', '0x2'], psm: 6 },
  { id: 'deskew-local', prep: ['-auto-orient', '-colorspace', 'Gray', '-resize', '180%', '-deskew', '40%', '-normalize', '-lat', '40x40-6%'], psm: 4 },
];

export async function version() {
  try { const { stderr, stdout } = await run('tesseract', ['--version']); return (stdout || stderr).split('\n')[0].trim(); } catch { return 'tesseract (not found)'; }
}

export async function readLines(file, { lang = 'hin+eng', passes = PASSES } = {}) {
  const dir = await mkdtemp(join(tmpdir(), 'chautari-read-'));
  try {
    const results = await Promise.all(passes.map(async (p, i) => {
      let input = file;
      if (p.prep.length) {
        input = join(dir, `p${i}.png`);
        await run('convert', [file, ...p.prep, input], { maxBuffer: 1 << 26 });
      }
      const { stdout } = await run('tesseract', [input, '-', '-l', lang, '--psm', String(p.psm)], { maxBuffer: 1 << 26, timeout: 120000 });
      return { id: p.id, lines: stdout.split('\n').map((l) => l.trim()).filter(Boolean) };
    }));
    return results;
  } finally { await rm(dir, { recursive: true, force: true }); }
}
