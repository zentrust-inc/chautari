#!/usr/bin/env python3
"""
Makes the SAMPLE bills and cash-book pages used to build and test the document reader.

Everything here is invented: shops, PAN numbers, bill numbers, people and amounts are fictional.
Each image carries a diagonal "नमूना · SAMPLE" mark and a footer band, so none of them can be
mistaken for a real bill or filed as one. samples/truth.json holds what each image really says,
so the reader can be scored. Real Chauthe bills replace these when they arrive.

Run:  python3 samples/make_samples.py        (deterministic: same seed, same images)
Needs: Pillow with Raqm (Devanagari shaping), numpy, FreeSans/FreeSerif fonts.
"""
import json, math, os, random
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageChops
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "bills")
os.makedirs(OUT, exist_ok=True)
rng = random.Random(20831119)
np_rng = np.random.default_rng(20831119)

SANS = "/usr/share/fonts/truetype/freefont/FreeSans.ttf"
SANSB = "/usr/share/fonts/truetype/freefont/FreeSansBold.ttf"
SERIF = "/usr/share/fonts/truetype/freefont/FreeSerif.ttf"
SERIFB = "/usr/share/fonts/truetype/freefont/FreeSerifBold.ttf"
_fc = {}
def font(path, size):
    k = (path, size)
    if k not in _fc:
        _fc[k] = ImageFont.truetype(path, size, layout_engine=ImageFont.Layout.RAQM)
    return _fc[k]

DEV = str.maketrans("0123456789", "०१२३४५६७८९")

def lakh(n, decimals=0):
    """Indian/Nepali digit grouping: 1,10,740.00"""
    s = f"{abs(n):.{decimals}f}"
    ip, _, fp = s.partition(".")
    if len(ip) > 3:
        head, tail = ip[:-3], ip[-3:]
        parts = []
        while len(head) > 2:
            parts.insert(0, head[-2:]); head = head[:-2]
        if head: parts.insert(0, head)
        ip = ",".join(parts + [tail])
    return ip + ("." + fp if fp else "")

def num(n, dev, decimals=0):
    s = ("-" if n < 0 else "") + lakh(n, decimals)  # a cash book that went below zero shows the minus
    return s.translate(DEV) if dev else s

def digits(s, dev):
    return str(s).translate(DEV) if dev else str(s)

# --------------------------------------------------------------------------------------------
# The documents (all fictional). amounts in rupees.
# kind: expense | income | cashbook. account: the CFUG expense head a person would likely pick.
# --------------------------------------------------------------------------------------------
BILLS = [
 dict(id="hw01", layout="invoice", dev=True, quality="clean", kind="expense", account="EX-2.01",
      vendor="नमूना हार्डवेयर तथा निर्माण सामग्री", vendor_en="Namuna Hardware & Construction Materials",
      addr="नुवाकोट बजार, नुवाकोट", pan="100200301", bill_no="0417", date_bs="2083/07/05", date_ad="2026-10-22",
      items=[("GI तार नं. १२ (बन्डल)", 4, 3200), ("किला (केजी)", 5, 180), ("कटर ब्लेड (थान)", 6, 95)],
      vat=0.13, method="cash", note="वन संरक्षण — घेराबार"),
 dict(id="nur01", layout="thermal", dev=True, quality="phone", kind="expense", account="EX-2.02",
      vendor="नमूना कृषि नर्सरी तथा बीउ केन्द्र", vendor_en="Namuna Agro Nursery",
      addr="तारकेश्वर–४, नुवाकोट", pan="100200302", bill_no="2291", date_bs="2083/07/09", date_ad="2026-10-26",
      items=[("लप्सी बिरुवा", 50, 80), ("ऐसेलु बिरुवा", 40, 60), ("टिमुर बिरुवा", 30, 50)],
      vat=0.0, method="cash", note="कृषि उपज — VAT छैन"),
 dict(id="tea01", layout="memo", dev=True, quality="phone", kind="expense", account="EX-1.02",
      vendor="नमूना चिया पसल", vendor_en="Namuna Tea Shop",
      addr="चौतारा, काकानी", pan=None, bill_no="११", date_bs="2083/07/12", date_ad="2026-10-29",
      items=[("चिया (कप)", 15, 20), ("समोसा (थान)", 15, 30)],
      vat=0.0, method="cash", note="भेला"),
 dict(id="stat01", layout="thermal", dev=False, quality="clean", kind="expense", account="EX-1.04",
      vendor="Sample Stationers & Printing", vendor_en="Sample Stationers & Printing",
      addr="Trishuli Bazaar, Nuwakot", pan="100200304", bill_no="8836", date_bs="2083/07/15", date_ad="2026-11-01",
      items=[("A4 paper (ream)", 2, 650), ("Register (pc)", 3, 220), ("Notice printing (copy)", 50, 12)],
      vat=0.13, method="cash", note=""),
 dict(id="fuel01", layout="thermal", dev=False, quality="phone", kind="expense", account="EX-1.08",
      vendor="Sample Petroleum Pump", vendor_en="Sample Petroleum Pump",
      addr="Kakani, Nuwakot", pan="100200305", bill_no="55102", date_bs="2083/07/18", date_ad="2026-11-04",
      items=[("Petrol (litre)", 6.5, 188)],
      vat=0.0, method="cash", note="", decimals=2),
 dict(id="jcb01", layout="invoice", dev=True, quality="clean", kind="expense", account="EX-2.01",
      vendor="नमूना भारी मेसिनरी सेवा", vendor_en="Namuna Heavy Machinery Service",
      addr="विदुर, नुवाकोट", pan="100200306", bill_no="0093", date_bs="2083/07/21", date_ad="2026-11-07",
      items=[("JCB भाडा (घण्टा)", 28, 3500)],
      vat=0.13, method="bank", note="माटो संरक्षण — खाल्डा/पैनी", decimals=2),
 dict(id="hall01", layout="memo", dev=True, quality="clean", kind="expense", account="EX-1.03",
      vendor="नमूना सभा हल", vendor_en="Namuna Meeting Hall",
      addr="काकानी–३", pan=None, bill_no="४०", date_bs="2083/07/24", date_ad="2026-11-10",
      items=[("हल भाडा (दिन)", 2, 3000)],
      vat=0.0, method="cash", note="तालिम"),
 dict(id="tool01", layout="thermal", dev=False, quality="clean", kind="expense", account="EX-1.06",
      vendor="Sample Tools & Rental", vendor_en="Sample Tools & Rental",
      addr="Bidur, Nuwakot", pan="100200308", bill_no="1204", date_bs="2083/07/27", date_ad="2026-11-13",
      items=[("Chainsaw rent (day)", 2, 1500), ("Bar oil (bottle)", 1, 450)],
      vat=0.13, method="cash", note="", decimals=2),
 dict(id="hw02", layout="invoice", dev=True, quality="poor", kind="expense", account="EX-2.01",
      vendor="नमूना हार्डवेयर तथा निर्माण सामग्री", vendor_en="Namuna Hardware & Construction Materials",
      addr="नुवाकोट बजार, नुवाकोट", pan="100200301", bill_no="0431", date_bs="2083/08/01", date_ad="2026-11-17",
      items=[("सिमेन्ट बोरा", 20, 1020), ("बालुवा (ट्रिप)", 1, 8500), ("रड नं. १० (केजी)", 40, 118)],
      vat=0.13, method="cash", note="चेक ड्याम", decimals=2),
 dict(id="nur02", layout="thermal", dev=True, quality="poor", kind="expense", account="EX-2.02",
      vendor="नमूना कृषि नर्सरी तथा बीउ केन्द्र", vendor_en="Namuna Agro Nursery",
      addr="तारकेश्वर–४, नुवाकोट", pan="100200302", bill_no="2310", date_bs="2083/08/02", date_ad="2026-11-18",
      items=[("नेपाली ओखर बिरुवा", 25, 150), ("प्लास्टिक ट्रे (थान)", 10, 120)],
      vat=0.0, method="cash", note=""),
 dict(id="rec01", layout="memo", dev=True, quality="phone", kind="income", account=None,
      vendor="थुम्की डाँडा सामुदायिक वन उपभोक्ता समूह", vendor_en="Thumki Danda CFUG (our own receipt)",
      addr="चौतारी, काकानी–३", pan=None, bill_no="१८", date_bs="2083/07/03", date_ad="2026-10-20",
      items=[("उपभोक्ता सदस्यता शुल्क", 1, 100)],
      vat=0.0, method="cash", note="नमूना रसिद — हामीले दिएको", received_from="नमूना सदस्य"),
]

CASHBOOKS = [
 dict(id="cb01", dev=True, quality="phone", title="नगद किताब (नमूना)", entity="थुम्की डाँडा सामुदायिक वन उपभोक्ता समूह",
      rows=[ # date_bs, particulars, receipts, payments
        ("2083/06/28", "अघिल्लो बाँकी", 24300, 0),
        ("2083/07/03", "सदस्यता शुल्क", 100, 0),
        ("2083/07/05", "तार, किला खरिद", 0, 16125),
        ("2083/07/09", "बिरुवा खरिद", 0, 7900),
        ("2083/07/12", "भेला चिया खाजा", 0, 750),
        ("2083/07/15", "कागज र छपाई", 0, 2893),
        ("2083/07/20", "काठ बिक्री", 12000, 0),
        ("2083/07/24", "हल भाडा", 0, 6000),
      ]),
 dict(id="cb02", dev=False, quality="clean", title="Cash Book (sample)", entity="Sample CFUG",
      rows=[
        ("2083/07/27", "Opening balance", 18250, 0),
        ("2083/07/28", "Chainsaw rent", 0, 3899),
        ("2083/07/29", "Timber sale", 20000, 0),
        ("2083/08/01", "Cement, sand, rod", 0, 37991),
        ("2083/08/02", "Membership fee", 300, 0),
        ("2083/08/02", "Saplings", 0, 4950),
      ]),
]

# --------------------------------------------------------------------------------------------
# computing amounts
# --------------------------------------------------------------------------------------------
def totals(b):
    lines = []
    for name, q, rate in b["items"]:
        lines.append(dict(name=name, qty=q, rate=rate, amount=round(q * rate, 2)))
    sub = round(sum(l["amount"] for l in lines), 2)
    vat = round(sub * b["vat"], 2)
    total = round(sub + vat, 2)
    return lines, sub, vat, total

# --------------------------------------------------------------------------------------------
# drawing the paper
# --------------------------------------------------------------------------------------------
INK = (28, 28, 34)
MARK = (205, 205, 210)

def stamp(img, text_np="नमूना · SAMPLE", size=None):
    """big diagonal mark + the label the paper can never lose"""
    w, h = img.size
    size = size or max(46, w // 9)
    layer = Image.new("RGBA", (w * 2, h * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    f = font(SANSB, size)
    tw = d.textlength(text_np, font=f)
    d.text((w - tw / 2, h - size / 2), text_np, font=f, fill=MARK + (150,))
    layer = layer.rotate(28, resample=Image.BICUBIC)
    layer = layer.crop((w // 2, h // 2, w // 2 + w, h // 2 + h))
    base = img.convert("RGBA"); base.alpha_composite(layer)
    return base.convert("RGB")

def footer(d, w, y, dev):
    t = "नमूना बिल — काल्पनिक, वास्तविक होइन · SAMPLE — fictional, not a real bill"
    size = 20
    while d.textlength(t, font=font(SANSB, size)) > w - 24 and size > 11:
        size -= 1
    d.rectangle([0, y, w, y + 36], fill=(238, 238, 240))
    d.text((w / 2, y + 18), t, font=font(SANSB, size), fill=(90, 90, 100), anchor="mm")
    return y + 36

def right(d, x, y, s, f, fill=INK):
    d.text((x, y), s, font=f, fill=fill, anchor="ra")

def render_invoice(b):
    dev = b["dev"]; dec = b.get("decimals", 0)
    lines, sub, vat, total = totals(b)
    W = 1000; H = 520 + 54 * len(lines) + (50 if vat else 0) + 190
    img = Image.new("RGB", (W, H), (252, 251, 246)); d = ImageDraw.Draw(img)
    d.rectangle([14, 14, W - 14, H - 56], outline=INK, width=3)
    d.text((W / 2, 56), b["vendor"], font=font(SERIFB, 44), fill=INK, anchor="mm")
    d.text((W / 2, 100), b["addr"], font=font(SANS, 26), fill=INK, anchor="mm")
    if b["pan"]:
        d.text((W / 2, 134), ("करदाता दर्ता नं. (PAN): " if dev else "PAN: ") + digits(b["pan"], dev), font=font(SANS, 26), fill=INK, anchor="mm")
    d.line([30, 160, W - 30, 160], fill=INK, width=2)
    d.text((W / 2, 192), "कर बिजक / बिल" if dev else "TAX INVOICE", font=font(SANSB, 32), fill=INK, anchor="mm")
    d.text((44, 226), ("बिल नं.: " if dev else "Bill No.: ") + digits(b["bill_no"], dev), font=font(SANS, 28), fill=INK)
    right(d, W - 44, 226, ("मिति: " if dev else "Date: ") + digits(b["date_bs"], dev), font(SANS, 28))
    d.text((44, 266), ("ग्राहक: चौतारी / थुम्की डाँडा CFUG" if dev else "Customer: Chautari / Thumki Danda CFUG"), font=font(SANS, 26), fill=INK)
    y = 316
    cols = [44, 90, 640, 740, 870]  # sn, name, qty, rate, amount(right)
    d.rectangle([30, y, W - 30, y + 46], fill=(232, 232, 236))
    hdr = ("क्र.", "विवरण", "परिमाण", "दर", "रकम") if dev else ("SN", "Description", "Qty", "Rate", "Amount")
    d.text((cols[0], y + 8), hdr[0], font=font(SANSB, 24), fill=INK)
    d.text((cols[1], y + 8), hdr[1], font=font(SANSB, 24), fill=INK)
    right(d, cols[2] + 70, y + 8, hdr[2], font(SANSB, 24)); right(d, cols[3] + 90, y + 8, hdr[3], font(SANSB, 24)); right(d, W - 44, y + 8, hdr[4], font(SANSB, 24))
    y += 52
    for i, l in enumerate(lines, 1):
        d.text((cols[0] + 10, y + 6), digits(i, dev), font=font(SANS, 26), fill=INK)
        d.text((cols[1], y + 6), l["name"], font=font(SANS, 26), fill=INK)
        qs = num(l["qty"], dev, 1 if l["qty"] % 1 else 0)
        right(d, cols[2] + 70, y + 6, qs, font(SANS, 26)); right(d, cols[3] + 90, y + 6, num(l["rate"], dev, dec), font(SANS, 26)); right(d, W - 44, y + 6, num(l["amount"], dev, dec), font(SANS, 26))
        d.line([30, y + 48, W - 30, y + 48], fill=(190, 190, 195), width=1)
        y += 54
    y += 10
    def tot(label, val, bold=False):
        nonlocal y
        f = font(SANSB if bold else SANS, 28 if bold else 26)
        right(d, 700, y, label, f); right(d, W - 44, y, num(val, dev, 2 if dec or val % 1 else 0), f); y += 44
    tot("उप-जम्मा:" if dev else "Sub-total:", sub)
    if vat: tot(("मू.अ.कर (१३%):" if dev else "VAT (13%):"), vat)
    d.line([560, y - 4, W - 30, y - 4], fill=INK, width=2)
    tot("कुल जम्मा:" if dev else "Grand Total:", total, bold=True)
    d.text((44, y - 40), ("भुक्तानी: " + ("नगद" if b["method"] == "cash" else "बैंक")) if dev else ("Payment: " + ("Cash" if b["method"] == "cash" else "Bank")), font=font(SANS, 24), fill=INK)
    footer(d, W, H - 36, dev)
    return stamp(img)

def render_thermal(b):
    dev = b["dev"]; dec = b.get("decimals", 0)
    lines, sub, vat, total = totals(b)
    W = 520; H = 440 + 74 * len(lines) + (46 if vat else 0) + 120
    img = Image.new("RGB", (W, H), (250, 250, 247)); d = ImageDraw.Draw(img)
    y = 24
    d.text((W / 2, y + 16), b["vendor"], font=font(SANSB, 30), fill=INK, anchor="mm"); y += 52
    d.text((W / 2, y), b["addr"], font=font(SANS, 22), fill=INK, anchor="mm"); y += 30
    if b["pan"]:
        d.text((W / 2, y), ("PAN: " + digits(b["pan"], dev)), font=font(SANS, 22), fill=INK, anchor="mm"); y += 30
    d.text((W / 2, y + 6), "- - - - - - - - - - - - - - - - - - - - - -", font=font(SANS, 20), fill=INK, anchor="mm"); y += 30
    d.text((20, y), ("बिल नं. " if dev else "Bill No: ") + digits(b["bill_no"], dev), font=font(SANS, 24), fill=INK); y += 34
    d.text((20, y), ("मिति " if dev else "Date: ") + digits(b["date_bs"], dev), font=font(SANS, 24), fill=INK); y += 40
    d.text((W / 2, y), "- - - - - - - - - - - - - - - - - - - - - -", font=font(SANS, 20), fill=INK, anchor="mm"); y += 30
    for l in lines:
        d.text((20, y), l["name"], font=font(SANS, 24), fill=INK); y += 32
        qs = num(l["qty"], dev, 1 if l["qty"] % 1 else 0)
        d.text((40, y), f"{qs} × {num(l['rate'], dev, dec)}", font=font(SANS, 23), fill=INK)
        right(d, W - 20, y, num(l["amount"], dev, dec), font(SANS, 24)); y += 42
    d.text((W / 2, y), "- - - - - - - - - - - - - - - - - - - - - -", font=font(SANS, 20), fill=INK, anchor="mm"); y += 30
    def tot(label, val, bold=False):
        nonlocal y
        f = font(SANSB if bold else SANS, 28 if bold else 24)
        d.text((20, y), label, font=f, fill=INK); right(d, W - 20, y, num(val, dev, 2 if dec or val % 1 else 0), f); y += 42
    tot("उप-जम्मा" if dev else "Sub-total", sub)
    if vat: tot("VAT 13%", vat)
    tot("जम्मा" if dev else "TOTAL", total, bold=True)
    d.text((W / 2, y + 8), ("धन्यवाद, फेरि आउनुहोला" if dev else "Thank you, visit again"), font=font(SANS, 22), fill=INK, anchor="mm"); y += 44
    footer(d, W, y + 4, dev)
    return stamp(img.crop((0, 0, W, y + 44)))

def render_memo(b):
    """a plain cash memo (कच्चा बिल): no tax, uneven, a little hand-written looking"""
    dev = b["dev"]
    lines, sub, vat, total = totals(b)
    W = 760; H = 420 + 62 * len(lines) + 150
    img = Image.new("RGB", (W, H), (248, 246, 236)); d = ImageDraw.Draw(img)
    for yy in range(150, H - 160, 40):
        d.line([20, yy, W - 20, yy], fill=(210, 214, 226), width=1)
    d.text((W / 2, 46), b["vendor"], font=font(SERIFB, 40), fill=(20, 20, 70), anchor="mm")
    d.text((W / 2, 88), b["addr"], font=font(SERIF, 26), fill=(20, 20, 70), anchor="mm")
    d.text((40, 130), "नगद रसिद / बिल" if dev else "Cash Memo", font=font(SERIFB, 28), fill=(20, 20, 70))
    # hand-ish: per-glyph jitter in blue-black ink
    def hand(x, y, s, size=30, fill=(18, 24, 92)):
        # jitter per word, never per glyph: Devanagari marks must stay with their letters
        f = font(SERIF, size)
        for i, wd in enumerate(s.split(" ")):
            d.text((x, y + rng.randint(-2, 2)), wd, font=f, fill=fill)
            x += d.textlength(wd + " ", font=f) + rng.uniform(-1, 2)
        return x
    hand(40, 176, ("नं. " if dev else "No. ") + digits(b["bill_no"], dev), 30)
    hand(W - 330, 176, ("मिति: " if dev else "Date: ") + digits(b["date_bs"], dev), 30)
    if b["kind"] == "income" and b.get("received_from"):
        hand(40, 222, "श्री " + b["received_from"] + " बाट", 30)
        y = 272
    else:
        y = 232
    for l in lines:
        hand(44, y, l["name"], 30)
        qs = num(l["qty"], dev, 1 if l["qty"] % 1 else 0)
        hand(W - 360, y, f"{qs} × {num(l['rate'], dev)}", 28)
        right(d, W - 44, y, num(l["amount"], dev), font(SERIF, 30), fill=(18, 24, 92)); y += 62
    d.line([W - 320, y, W - 30, y], fill=(20, 20, 70), width=2)
    hand(W - 520, y + 10, "जम्मा रु." if dev else "Total Rs.", 32)
    right(d, W - 44, y + 10, num(total, dev), font(SERIFB, 34), fill=(18, 24, 92)); y += 70
    footer(d, W, y + 20, dev)
    return stamp(img.crop((0, 0, W, y + 60)))

def render_cashbook(cb):
    dev = cb["dev"]
    rows = cb["rows"]
    W = 1100; H = 330 + 64 * len(rows) + 180
    img = Image.new("RGB", (W, H), (246, 243, 232)); d = ImageDraw.Draw(img)
    d.text((W / 2, 50), cb["title"], font=font(SERIFB, 42), fill=(30, 30, 80), anchor="mm")
    d.text((W / 2, 98), cb["entity"], font=font(SERIF, 28), fill=(30, 30, 80), anchor="mm")
    cols = [30, 200, 610, 750, 890]
    y = 150
    d.rectangle([20, y, W - 20, y + 56], outline=(30, 30, 80), width=2, fill=(228, 226, 214))
    hdr = ("मिति", "विवरण", "आम्दानी", "खर्च", "बाँकी") if dev else ("Date", "Particulars", "Receipts", "Payments", "Balance")
    d.text((cols[0] + 6, y + 12), hdr[0], font=font(SERIFB, 28), fill=(30, 30, 80))
    d.text((cols[1] + 6, y + 12), hdr[1], font=font(SERIFB, 28), fill=(30, 30, 80))
    for i in (2, 3, 4):
        right(d, cols[i] + 130, y + 12, hdr[i], font(SERIFB, 28), fill=(30, 30, 80))
    y += 56
    bal = 0; truth_rows = []
    for (dt, part, rec, pay) in rows:
        bal += rec - pay
        d.rectangle([20, y, W - 20, y + 64], outline=(120, 120, 150), width=1)
        for cx in cols[1:]:
            d.line([cx, y, cx, y + 64], fill=(120, 120, 150), width=1)
        f = font(SERIF, 28)
        d.text((cols[0] + 6, y + 16), digits(dt, dev), font=f, fill=(18, 24, 92))
        d.text((cols[1] + 8, y + 16), part, font=f, fill=(18, 24, 92))
        if rec: right(d, cols[2] + 130, y + 16, num(rec, dev), f, fill=(18, 24, 92))
        if pay: right(d, cols[3] + 130, y + 16, num(pay, dev), f, fill=(18, 24, 92))
        right(d, cols[4] + 130, y + 16, num(bal, dev), f, fill=(18, 24, 92))
        truth_rows.append(dict(date_bs=dt, particulars=part, receipt=rec, payment=pay, balance=bal))
        y += 64
    y += 30
    footer(d, W, y, dev)
    return stamp(img.crop((0, 0, W, y + 36)), size=90), truth_rows

# --------------------------------------------------------------------------------------------
# making it look like a phone photo
# --------------------------------------------------------------------------------------------
QUALITY = {
    "clean": dict(rot=0.4, persp=0.004, blur=0.6, noise=2.0, shade=0.06, jpeg=88, bg=(96, 84, 70), long=1800),
    "phone": dict(rot=2.2, persp=0.02, blur=1.0, noise=5.0, shade=0.20, jpeg=74, bg=(88, 78, 66), long=1400),
    "poor":  dict(rot=4.5, persp=0.05, blur=1.6, noise=10.0, shade=0.38, jpeg=55, bg=(70, 62, 55), long=1000),
}

def photograph(img, q):
    p = QUALITY[q]
    # work on a large sheet, then shrink to the camera's size, as a real photo would be
    w, h = img.size
    up = 2000 / max(w, h)
    if up > 1:
        img = img.resize((int(w * up), int(h * up)), Image.LANCZOS)
    w, h = img.size
    pad = int(0.08 * max(w, h))
    canvas = Image.new("RGB", (w + 2 * pad, h + 2 * pad), p["bg"])
    canvas.paste(img, (pad, pad))
    ang = rng.uniform(-p["rot"], p["rot"])
    canvas = canvas.rotate(ang, resample=Image.BICUBIC, expand=True, fillcolor=p["bg"])
    cw, ch = canvas.size
    k = p["persp"]
    dx1, dx2 = rng.uniform(-k, k) * cw, rng.uniform(-k, k) * cw
    dy1, dy2 = rng.uniform(-k, k) * ch, rng.uniform(-k, k) * ch
    coeffs_src = [(dx1, dy1), (cw - dx2, dy2), (cw + dx1, ch - dy1), (-dx2, ch + dy2)]
    quad = (coeffs_src[0][0], coeffs_src[0][1], coeffs_src[3][0], coeffs_src[3][1],
            coeffs_src[2][0], coeffs_src[2][1], coeffs_src[1][0], coeffs_src[1][1])
    canvas = canvas.transform((cw, ch), Image.QUAD, quad, resample=Image.BICUBIC, fillcolor=p["bg"])
    s = p["long"] / max(cw, ch)
    canvas = canvas.resize((int(cw * s), int(ch * s)), Image.LANCZOS)
    cw, ch = canvas.size
    a = np.asarray(canvas).astype(np.float32)
    # uneven light: a soft gradient plus one shadow band
    yy, xx = np.mgrid[0:ch, 0:cw]
    gx, gy = rng.uniform(-1, 1), rng.uniform(-1, 1)
    light = 1 - p["shade"] * (0.5 + 0.5 * (gx * (xx / cw - 0.5) + gy * (yy / ch - 0.5)) * 2)
    cx = rng.uniform(0.2, 0.8) * cw
    light *= 1 - p["shade"] * 0.8 * np.exp(-((xx - cx) / (0.12 * cw)) ** 2) * (yy / ch)
    a *= light[..., None]
    a += np_rng.normal(0, p["noise"], a.shape)
    out = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))
    out = out.filter(ImageFilter.GaussianBlur(p["blur"]))
    return out, p["jpeg"]

# --------------------------------------------------------------------------------------------
def main():
    truth = {"_note": "SAMPLE data. Everything here is fictional; see samples/README.md.", "bills": [], "cashbooks": []}
    for b in BILLS:
        lines, sub, vat, total = totals(b)
        r = dict(invoice=render_invoice, thermal=render_thermal, memo=render_memo)[b["layout"]](b)
        photo, jq = photograph(r, b["quality"])
        path = os.path.join(OUT, b["id"] + ".jpg")
        photo.save(path, "JPEG", quality=jq, optimize=True)
        truth["bills"].append(dict(
            file=f"bills/{b['id']}.jpg", id=b["id"], kind=b["kind"], layout=b["layout"], quality=b["quality"],
            digits="devanagari" if b["dev"] else "latin", vendor=b["vendor"], vendor_en=b["vendor_en"], pan=b["pan"],
            bill_no=b["bill_no"], date_bs=b["date_bs"], date_ad=b["date_ad"],
            items=[dict(name=l["name"], qty=l["qty"], rate=l["rate"], amount=l["amount"]) for l in lines],
            subtotal=sub, vat=vat, total=total, method=b["method"], suggested_account=b["account"], note=b["note"]))
        print(f"{b['id']:8s} {b['layout']:8s} {b['quality']:6s} total {total:>10,.2f}  {os.path.getsize(path)//1024} KB")
    for cb in CASHBOOKS:
        r, rows = render_cashbook(cb)
        photo, jq = photograph(r, cb["quality"])
        path = os.path.join(OUT, cb["id"] + ".jpg")
        photo.save(path, "JPEG", quality=jq, optimize=True)
        truth["cashbooks"].append(dict(file=f"bills/{cb['id']}.jpg", id=cb["id"], quality=cb["quality"],
                                       digits="devanagari" if cb["dev"] else "latin", rows=rows))
        print(f"{cb['id']:8s} cashbook {cb['quality']:6s} {len(rows)} rows  {os.path.getsize(path)//1024} KB")
    with open(os.path.join(HERE, "truth.json"), "w", encoding="utf-8") as f:
        json.dump(truth, f, ensure_ascii=False, indent=1)

if __name__ == "__main__":
    main()
