# Hard samples: Claude (multimodal) and EasyOCR vs Tesseract — 2026-11-19

Same 8 fictional pages as `samples/HARD-REPORT.md` (4 hand-written cash books, 4 faded thermal receipts).

| reader | runs where | faded receipts (28 fields) | cash books (120 cells) |
|---|---|---|---|
| Tesseract nep+hin+eng (current) | own server | 1 field read | 3 of 24 rows found |
| EasyOCR `ne+en` (open source, CPU) | own server | 3 of 4 receipts mostly right; the faintest one (fth04) unreadable | good on 2 pages, garbled on the Latin-digit page and the blurred page (not scored cell by cell) |
| Claude (multimodal), read before seeing the answers | outside service | **28 / 28 right** (2 marked unsure, both right) | **110 / 120 right** |

The 10 cash-book errors are all ५↔६ in one handwriting style (hcb01 rows 7; hcb03 every balance).
**They passed the arithmetic check**: a digit misread the same way in the amount and the running balance
still adds up. Sums alone cannot catch this.

EasyOCR read exactly those cells right (३,३६०; २९,५१५). So the design is two independent readers:
a figure gets a tick only when both agree and the sums fit; otherwise "check this". A named person still confirms every entry.

Files: `claude-readings.json` (Claude's readings), `easyocr.json` (EasyOCR raw output). Both are
on fictional samples; real village handwriting will be harder.
