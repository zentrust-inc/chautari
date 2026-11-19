# EasyOCR helper for engine-easyocr.mjs: image paths in, one JSON list of text lines per image out.
# Runs on our own server (models downloaded once from EasyOCR's GitHub releases; no outside service at read time).
import sys, json, os
os.environ.setdefault('OMP_NUM_THREADS', '2')
import easyocr
langs = os.environ.get('CHAUTARI_EASYOCR_LANGS', 'ne,en').split(',')
r = easyocr.Reader(langs, gpu=False, verbose=False)
def lines(path):
    res = r.readtext(path, paragraph=False, width_ths=0.7, mag_ratio=1.5)
    boxes = []
    for (pts, text, conf) in res:
        ys = [p[1] for p in pts]; xs = [p[0] for p in pts]
        boxes.append((sum(ys) / 4, min(ys), max(ys), min(xs), text))
    boxes.sort()
    out, cur, cur_mid, cur_h = [], [], None, None
    for b in boxes:
        h = b[2] - b[1]
        if cur and abs(b[0] - cur_mid) <= 0.55 * max(cur_h, h):
            cur.append(b)
        else:
            if cur: out.append(cur)
            cur, cur_mid, cur_h = [b], b[0], h
    if cur: out.append(cur)
    return [' '.join(x[4] for x in sorted(l, key=lambda x: x[3])) for l in out]
print(json.dumps({p: lines(p) for p in sys.argv[1:]}, ensure_ascii=False))
