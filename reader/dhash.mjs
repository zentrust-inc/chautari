// A picture fingerprint for "another photo of the same bill": 64 bits that change little when the same
// bill is photographed again (light, small tilt, recompression) and a lot between different bills.
// Difference hash: shrink to 9×8 grey, compare each pixel with its right neighbour.
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
const run = promisify(execFile);

export async function dhash(path) {
  const { stdout } = await run('convert', [path, '-auto-orient', '-colorspace', 'Gray', '-resize', '9x8!', '-depth', '8', 'gray:-'],
    { encoding: 'buffer', maxBuffer: 1 << 16 });
  if (stdout.length !== 72) throw new Error('dhash: unexpected image data');
  let bits = 0n;
  for (let y = 0; y < 8; y++) for (let x = 0; x < 8; x++) bits = (bits << 1n) | (stdout[y * 9 + x] > stdout[y * 9 + x + 1] ? 1n : 0n);
  return bits.toString(16).padStart(16, '0');
}

export const distance = (a, b) => { let v = BigInt('0x' + a) ^ BigInt('0x' + b), n = 0; while (v) { n += Number(v & 1n); v >>= 1n; } return n; };
