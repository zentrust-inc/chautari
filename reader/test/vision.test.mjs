import { test } from 'node:test';
import assert from 'node:assert/strict';
import { visionLines } from '../engine-vision.mjs';

// a word: text, left x, middle y, width, height, page slant (pixels down per pixel right)
const word = (t, x, y, w, h = 30, s = 0) => [t, [[x, y - h / 2 + x * s], [x + w, y - h / 2 + (x + w) * s], [x + w, y + h / 2 + (x + w) * s], [x, y + h / 2 + x * s]]];

test('vision: a tilted cash-book page comes out one table row per line', () => {
  const s = 0.06; // about 3.5 degrees: the far columns sit lower than one row height
  const lines = visionLines([
    word('२०८३/०८/०३', 100, 200, 180, 30, s), word('अघिल्लो', 320, 200, 110, 30, s), word('बाँकी', 440, 200, 70, 30, s),
    word('३१,२५०/-', 760, 200, 130, 30, s), word('३१,२५०', 1100, 200, 110, 30, s),
    word('२०८३/०८/०४', 100, 260, 180, 30, s), word('शुल्क', 320, 260, 80, 30, s), word('३००/-', 780, 260, 80, 30, s), word('३१,५५०', 1100, 260, 110, 30, s),
    word('SAMPLE', 500, 230, 400, 160, s), // a big slanted watermark must not glue rows together
  ]);
  assert.deepEqual(lines, ['२०८३/०८/०३  अघिल्लो बाँकी  ३१,२५०/-  ३१,२५०', '२०८३/०८/०४  शुल्क  ३००/-  ३१,५५०']);
});

test('vision: a figure split in two is joined', () => {
  const lines = visionLines([word('२', 100, 100, 20), word('९,१००', 125, 100, 80)]);
  assert.deepEqual(lines, ['२९,१००']);
});
