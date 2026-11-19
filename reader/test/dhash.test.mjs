import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { dhash, distance } from '../dhash.mjs';

const S = join(dirname(fileURLToPath(import.meta.url)), '../../samples/bills');

test('the same picture forwarded, cropped or recompressed stays within 5 bits; different sample bills do not', async () => {
  const d = mkdtempSync(join(tmpdir(), 'dh-'));
  for (const b of ['hw01', 'jcb01', 'fuel01']) {
    const again = join(d, `${b}.jpg`);
    execFileSync('convert', [join(S, `${b}.jpg`), '-resize', '50%', '-crop', '95%x95%+10+10', '-quality', '55', again]);
    assert.ok(distance(await dhash(join(S, `${b}.jpg`)), await dhash(again)) <= 5, b);
  }
  const hs = await Promise.all(['hw01', 'hw02', 'jcb01', 'fuel01', 'nur01', 'tea01'].map((b) => dhash(join(S, `${b}.jpg`))));
  for (let i = 0; i < hs.length; i++) for (let j = i + 1; j < hs.length; j++) assert.ok(distance(hs[i], hs[j]) > 5);
});
