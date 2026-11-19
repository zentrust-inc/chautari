#!/usr/bin/env python3
"""
Makes the HARD sample set: hand-written cash-book pages and faded thermal receipts.

These are the two kinds of paper the reader is most likely to get wrong, so they are kept apart from
the ordinary samples (samples/bills/, scored in READER-REPORT.md) and scored on their own in
samples/HARD-REPORT.md. Everything is fictional and carries the "नमूना · SAMPLE" mark and footer.

Hand-writing is simulated with the Kalam and Yatra One Devanagari hand-lettering fonts (SIL OFL,
samples/fonts/), word by word with wobble, slant, size and ink-pressure changes, on ruled notebook
paper with hand-drawn column lines. Real hand-writing varies far more than a font can; treat the
scores on these pages as an UPPER bound for real cash books.

Faded thermal paper is simulated on top of the ordinary thermal layout: the ink loses most of its
darkness, unevenly along the roll, with print-head dropouts (white streaks) and dotty speckle.

Run:  python3 samples/make_hard_samples.py    (deterministic)
"""
import json, os, random
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

import make_samples as ms  # reuse the shop data helpers, thermal layout, stamp, footer and photograph()

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "hard")
os.makedirs(OUT, exist_ok=True)
rng = random.Random(20831203)
np_rng = np.random.default_rng(20831203)
ms.rng.seed(20831203)  # photograph() draws from make_samples' rng; pin it for this set

FONTS = os.path.join(HERE, "fonts")
KALAM = os.path.join(FONTS, "Kalam-Regular.ttf")
KALAM_L = os.path.join(FONTS, "Kalam-Light.ttf")
YATRA = os.path.join(FONTS, "YatraOne-Regular.ttf")

def hfont(path, size):
    return ImageFont.truetype(path, size, layout_engine=ImageFont.Layout.RAQM)

# --------------------------------------------------------------------------------------------
# hand-written cash-book pages
# --------------------------------------------------------------------------------------------
HAND_PAGES = [
 dict(id="hcb01", quality="phone", font=KALAM, dev=True, ink=(22, 38, 140), date_style="padded", suffix="/-", commas=True,
      title="नगद किताब", rows=[
        ("2083/08/03", "अघिल्लो बाँकी", 31250, 0),
        ("2083/08/04", "सदस्यता शुल्क", 300, 0),
        ("2083/08/06", "कोदालो, बेल्चा", 0, 2450),
        ("2083/08/09", "बिरुवा ढुवानी", 0, 1800),
        ("2083/08/11", "दाउरा बिक्री", 6500, 0),
        ("2083/08/14", "भेला खाजा", 0, 925),
        ("2083/08/17", "नर्सरी पोलिथिन", 0, 3360),
      ]),
 dict(id="hcb02", quality="phone", font=KALAM, dev=False, ink=(30, 30, 40), date_style="short", suffix="", commas=False,
      title="नगद किताब", rows=[
        ("2083/08/18", "अघिल्लो बाँकी", 28215, 0),
        ("2083/08/19", "घाँस बिक्री", 1200, 0),
        ("2083/08/21", "तार किला", 0, 7340),
        ("2083/08/22", "चिया पानी", 0, 480),
        ("2083/08/25", "सदस्यता शुल्क", 200, 0),
        ("2083/08/27", "ज्याला", 0, 4500),
      ]),
 dict(id="hcb03", quality="poor", font=YATRA, dev=True, ink=(25, 45, 150), date_style="dash", suffix="/-", commas=True,
      title="नगद किताब", rows=[
        ("2083/08/28", "अघिल्लो बाँकी", 17375, 0),
        ("2083/08/29", "काठ बिक्री", 15000, 0),
        ("2083/09/01", "सिमेन्ट २ बोरा", 0, 2040),
        ("2083/09/02", "मिस्त्री ज्याला", 0, 3000),
        ("2083/09/04", "छपाई", 0, 650),
        ("2083/09/06", "चन्दा", 2500, 0),
      ]),
 dict(id="hcb04", quality="phone", font=KALAM_L, dev=True, ink=(95, 95, 110), date_style="short", suffix="", commas=False,
      title="नगद किताब (पेन्सिल)", rows=[
        ("2083/09/07", "अघिल्लो बाँकी", 29235, 0),
        ("2083/09/08", "बीउ खरिद", 0, 1275),
        ("2083/09/10", "सदस्यता शुल्क", 100, 0),
        ("2083/09/12", "ढुवानी भाडा", 0, 2200),
        ("2083/09/15", "बिरुवा बिक्री", 3600, 0),
      ]),
]

def hand_date(dt, style, dev):
    y, m, d = dt.split("/")
    if style == "short":
        s = f"{y}/{int(m)}/{int(d)}"
    elif style == "dash":
        s = f"{y}-{m}-{d}"
    else:
        s = dt
    return ms.digits(s, dev)

def hand_amount(n, dev, commas, suffix):
    s = ms.lakh(n) if commas else str(n)
    return (s.translate(ms.DEV) if dev else s) + suffix

def write_hand(img, x, y, text, path, size, ink, align="left", max_w=None):
    """Write text word by word, each word with its own wobble, slant, size and ink pressure."""
    words = text.split(" ")
    rend = []
    for wd in words:
        sz = int(size * rng.uniform(0.92, 1.08))
        f = hfont(path, sz)
        tmp = ImageDraw.Draw(Image.new("L", (1, 1)))
        l, t, r, b = tmp.textbbox((0, 0), wd, font=f)
        pad = sz // 2
        layer = Image.new("L", (r - l + 2 * pad, b - t + 2 * pad), 0)
        ImageDraw.Draw(layer).text((pad - l, pad - t), wd, font=f, fill=255)
        if rng.random() < 0.35:  # heavier pressure
            layer = layer.filter(ImageFilter.MaxFilter(3))
        shear = rng.uniform(-0.18, 0.08)
        w0, h0 = layer.size
        layer = layer.transform((w0 + int(abs(shear) * h0), h0), Image.AFFINE,
                                (1, shear, -abs(shear) * h0 if shear < 0 else 0, 0, 1, 0), resample=Image.BICUBIC)
        layer = layer.rotate(rng.uniform(-3.0, 3.0), resample=Image.BICUBIC, expand=True)
        rend.append((layer, pad))
    gap = int(size * 0.32)
    total = sum(l.size[0] - 2 * p for l, p in rend) + gap * (len(rend) - 1)
    cx = x - total if align == "right" else x
    for layer, pad in rend:
        a = np.asarray(layer).astype(np.float32) / 255.0
        a *= rng.uniform(0.75, 1.0)  # ink pressure for this word
        alpha = Image.fromarray((a * 255).astype(np.uint8))
        ink_img = Image.new("RGB", layer.size, tuple(int(c + rng.uniform(-8, 8)) for c in ink))
        img.paste(ink_img, (int(cx - pad), int(y - pad + rng.uniform(-4, 4))), alpha)
        cx += layer.size[0] - 2 * pad + gap + rng.uniform(-3, 5)

def wobbly_line(d, x0, y0, x1, y1, fill, width=2, steps=24):
    pts = []
    for i in range(steps + 1):
        t = i / steps
        pts.append((x0 + (x1 - x0) * t + rng.uniform(-1.5, 1.5), y0 + (y1 - y0) * t + rng.uniform(-1.5, 1.5)))
    d.line(pts, fill=fill, width=width, joint="curve")

def render_hand_cashbook(pg):
    dev, ink, fp = pg["dev"], pg["ink"], pg["font"]
    rows = pg["rows"]
    W = 1150; RH = 74; H = 260 + RH * (len(rows) + 1) + 140
    img = Image.new("RGB", (W, H), (247, 245, 236)); d = ImageDraw.Draw(img)
    for yy in range(70, H - 60, 37):  # printed notebook rules
        d.line([0, yy, W, yy], fill=(176, 196, 222), width=1)
    d.line([88, 0, 88, H - 60], fill=(222, 140, 140), width=2)  # red margin
    write_hand(img, W / 2 - 160, 40, pg["title"], fp, 50, ink)
    write_hand(img, 110, 112, "थुम्की डाँडा सा.व.उ.स. (नमूना)", fp, 34, ink)
    cols = [100, 300, 640, 800, 960, W - 30]
    y = 180
    wobbly_line(d, 95, y, W - 30, y, ink, 2)
    hdr = ("मिति", "विवरण", "आम्दानी", "खर्च", "बाँकी")
    for i, h in enumerate(hdr):
        write_hand(img, cols[i] + 10, y + 14, h, fp, 34, ink)
    y += RH
    wobbly_line(d, 95, y, W - 30, y, ink, 2)
    for cx in cols[1:-1]:
        wobbly_line(d, cx, 180, cx + rng.uniform(-6, 6), 180 + RH * (len(rows) + 1), ink, 2)
    bal = 0; truth = []
    for dt, part, rec, pay in rows:
        bal += rec - pay
        sz = 36
        write_hand(img, cols[0] + 6, y + 18, hand_date(dt, pg["date_style"], dev), fp, sz - 4, ink)
        write_hand(img, cols[1] + 10, y + 18, part, fp, sz, ink)
        if rec: write_hand(img, cols[3] - 14, y + 18, hand_amount(rec, dev, pg["commas"], pg["suffix"]), fp, sz, ink, align="right")
        if pay: write_hand(img, cols[4] - 14, y + 18, hand_amount(pay, dev, pg["commas"], pg["suffix"]), fp, sz, ink, align="right")
        write_hand(img, cols[5] - 14, y + 18, hand_amount(bal, dev, pg["commas"], ""), fp, sz, ink, align="right")
        truth.append(dict(date_bs=dt, particulars=part, receipt=rec, payment=pay, balance=bal))
        y += RH
    wobbly_line(d, 95, y, W - 30, y, ink, 2)
    y += 40
    ms.footer(d, W, y, True)
    return ms.stamp(img.crop((0, 0, W, y + 36)), size=90), truth

# --------------------------------------------------------------------------------------------
# faded thermal receipts
# --------------------------------------------------------------------------------------------
FADED = [
 # fade: share of the ink's darkness that is left (1 = fresh print). streaks: dead print-head columns.
 dict(id="fth01", fade=0.55, streaks=2, quality="phone", layout="thermal", dev=False, kind="expense", account="EX-1.08",
      vendor="Sample Petroleum Pump", vendor_en="Sample Petroleum Pump",
      addr="Kakani, Nuwakot", pan="100200305", bill_no="55977", date_bs="2083/08/12", date_ad="2026-11-28",
      items=[("Diesel (litre)", 12.0, 172)], vat=0.0, method="cash", note="", decimals=2),
 dict(id="fth02", fade=0.40, streaks=3, quality="phone", layout="thermal", dev=False, kind="expense", account="EX-1.04",
      vendor="Sample Stationers & Printing", vendor_en="Sample Stationers & Printing",
      addr="Trishuli Bazaar, Nuwakot", pan="100200304", bill_no="9120", date_bs="2083/08/16", date_ad="2026-12-02",
      items=[("Register (pc)", 2, 220), ("Pen (box)", 1, 300), ("Photocopy (page)", 40, 3)], vat=0.13, method="cash", note="", decimals=2),
 dict(id="fth03", fade=0.45, streaks=2, quality="phone", layout="thermal", dev=True, kind="expense", account="EX-2.02",
      vendor="नमूना कृषि नर्सरी तथा बीउ केन्द्र", vendor_en="Namuna Agro Nursery",
      addr="तारकेश्वर–४, नुवाकोट", pan="100200302", bill_no="2388", date_bs="2083/08/20", date_ad="2026-12-06",
      items=[("कफी बिरुवा", 40, 45), ("अम्रिसो बिरुवा", 60, 15)], vat=0.0, method="cash", note=""),
 dict(id="fth04", fade=0.28, streaks=4, quality="poor", layout="thermal", dev=False, kind="expense", account="EX-1.06",
      vendor="Sample Tools & Rental", vendor_en="Sample Tools & Rental",
      addr="Bidur, Nuwakot", pan="100200308", bill_no="1377", date_bs="2083/08/24", date_ad="2026-12-10",
      items=[("Chainsaw rent (day)", 1, 1500), ("Chain file (pc)", 2, 350)], vat=0.13, method="cash", note="", decimals=2),
]

def fade_thermal(img, fade, streaks):
    a = np.asarray(img).astype(np.float32)
    h, w, _ = a.shape
    paper = np.array([244, 242, 233], np.float32)
    dark = np.clip((paper - a).mean(axis=2) / 220.0, 0, 1)  # 0 = paper, 1 = full ink
    yy, xx = np.mgrid[0:h, 0:w]
    # uneven along the roll and across it, plus soft blotches
    keep = fade * (1 + 0.35 * np.sin(yy / h * np.pi * rng.uniform(1, 2.5) + rng.uniform(0, 6)))
    keep *= 1 - 0.25 * (xx / w if rng.random() < 0.5 else 1 - xx / w)
    small = np_rng.uniform(0.6, 1.2, (max(h // 120, 2), max(w // 120, 2))).astype(np.float32)
    blot = np.asarray(Image.fromarray(small).resize((w, h), Image.BICUBIC))
    keep = np.clip(keep * blot, 0.08, 1)
    # dotty print: thermal dots drop out
    keep *= (np_rng.random((h, w)) > 0.18 * (1 - fade)).astype(np.float32)
    for _ in range(streaks):  # dead print-head columns
        x0 = rng.randint(30, w - 40); sw = rng.randint(2, 6)
        keep[:, x0:x0 + sw] *= rng.uniform(0.0, 0.2)
    ink = dark * keep
    out = paper[None, None, :] * (1 - ink[..., None]) + np.array([60, 60, 70], np.float32) * ink[..., None]
    out += np_rng.normal(0, 2.0, out.shape)
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.5))

# --------------------------------------------------------------------------------------------
def main():
    truth = {"_note": "HARD SAMPLE data: hand-written cash books and faded thermal receipts. Everything is fictional; see samples/README.md.",
             "bills": [], "cashbooks": []}
    for b in FADED:
        lines, sub, vat, total = ms.totals(b)
        clean = ms.render_thermal(b)
        photo, jq = ms.photograph(fade_thermal(clean, b["fade"], b["streaks"]), b["quality"])
        path = os.path.join(OUT, b["id"] + ".jpg")
        photo.save(path, "JPEG", quality=jq, optimize=True)
        truth["bills"].append(dict(
            file=f"hard/{b['id']}.jpg", id=b["id"], kind=b["kind"], layout=b["layout"], quality=f"{b['quality']}, faded {int(100 * b['fade'])}%",
            digits="devanagari" if b["dev"] else "latin", vendor=b["vendor"], vendor_en=b["vendor_en"], pan=b["pan"],
            bill_no=b["bill_no"], date_bs=b["date_bs"], date_ad=b["date_ad"],
            items=[dict(name=l["name"], qty=l["qty"], rate=l["rate"], amount=l["amount"]) for l in lines],
            subtotal=sub, vat=vat, total=total, method=b["method"], suggested_account=b["account"], note=b["note"]))
        print(f"{b['id']:7s} faded thermal  ink left {b['fade']:.0%}  total {total:>9,.2f}  {os.path.getsize(path)//1024} KB")
    for pg in HAND_PAGES:
        r, rows = render_hand_cashbook(pg)
        photo, jq = ms.photograph(r, pg["quality"])
        path = os.path.join(OUT, pg["id"] + ".jpg")
        photo.save(path, "JPEG", quality=jq, optimize=True)
        truth["cashbooks"].append(dict(file=f"hard/{pg['id']}.jpg", id=pg["id"],
                                       quality=f"{pg['quality']}, hand-written ({os.path.basename(pg['font']).split('-')[0]})",
                                       digits="devanagari" if pg["dev"] else "latin", rows=rows))
        print(f"{pg['id']:7s} hand cash book {pg['quality']:6s} {len(rows)} rows  {os.path.getsize(path)//1024} KB")
    with open(os.path.join(HERE, "hard-truth.json"), "w", encoding="utf-8") as f:
        json.dump(truth, f, ensure_ascii=False, indent=1)

if __name__ == "__main__":
    main()
