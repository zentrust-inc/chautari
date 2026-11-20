# Hard samples: Sarvam Vision — 2026-11-20

Same 8 fictional pages as `samples/HARD-REPORT.md` (4 faded thermal receipts, 4 hand-written cash books in
hand-lettering fonts). Sarvam Vision 2.1 (Document AI "parse", `ne-IN`, content type `mixed`), Rs 0.50 a page.
Readings: `sarvam-readings.json`. Real village handwriting will be harder; this is a first look, not proof.

## Sarvam alone, before any check (figures compared with `hard-truth.json`)

| page | result |
|---|---|
| fth01, fth03 | every figure right |
| fth02 | every figure right except one rate (photocopy 3.00 read as 5.00); 40 × 5 ≠ 120, so the item sum check catches it |
| fth04 (faintest, 28%) | bill number, date and the first item right; second amount, sub-total, VAT and total **left out** (fails safe) |
| hcb01 | 21 / 21 figures right, including ३,३६० and २९,५१५ that both Claude models misread |
| hcb02 (Latin digits) | 18 / 18 right |
| hcb03 | amounts 6 / 6 right; month ०९ read as ०१ on 4 dates; one balance २९,१८५ read as २१,१८५; one balance not read |
| hcb04 (pencil) | 15 / 15 right |

Cash books: **66 of 72 figures right** (dates, amounts, balances), 5 wrong, 1 missing. Words in the particulars
have small slips (अघिल्लो → अधिल्लो, ढुवानी → दुवानी, बेल्चा → बेल्या); they never get a tick anyway.

**Its mistakes are not Claude's mistakes.** Claude confused ५/६ and 9/3; Sarvam confused ९/१, in a different
handwriting style. Two readers that fail differently is what the "two must agree" rule needs.

## Warning: never use content type `printed`

With `printed`, on fth04 Sarvam did not transcribe the receipt: it wrote a Nepali paragraph describing it,
with amounts it made up (Rs 2,200, Rs 290, Rs 286). With `mixed` it left those figures out. The engine now
refuses `printed` (`reader/engine-sarvam.mjs`).

## Pair score: Sarvam + Google Cloud Vision (`CHAUTARI_MIX=sarvam,vision`, Vision readings from `vision-readings.json`)

| pair | read but WRONG | cash-book rows ticked |
|---|---|---|
| Claude Opus + Vision (19 Nov, status log) | 0 | 11 of 24 |
| **Sarvam + Vision** | **0** | 5 of 24 |

On the receipts, Sarvam + Vision ticked both totals and sub-totals it could (fth01, fth03) and every bill
number, PAN and vendor; fth02's total went to "check" because of the misread rate.

Zero wrong ticks, but fewer ticks: on hand-writing, Vision is the weak half, so Sarvam's right readings
often have no second reading to agree with. The pairs still to score are **Sarvam + Claude Opus** and
**Sarvam + Gemini**; they need the Claude and Gemini keys, which live on our own server.
