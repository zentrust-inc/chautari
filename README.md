# चौतारी (Chautari)

**हाम्रो साझा खाता** — a phone-first, Nepali-language, transparent ledger for the Thumki Danda Gairikharka community forest user group (CFUG), the Kakani Multipurpose Cooperative and the Chauthe Guthi in Chauthe (Kakani-3), Nuwakot. It records money, work hours, decisions and nature's account. It records; it never pays, lends or registers anything by itself.
**Chautari is not software for managing villagers. It is infrastructure that helps a village manage itself.**
This repository is the single home of the code, the database, the tests and the one demo.

## Status

**Demo only.** `demo/index.html` runs on fictional sample people (`seed/demo.sql`). No real village records are stored anywhere. A pilot starts only if the assembly (भेला) approves.

- **Rulebooks:** CFUG constitution (विधान २०८२), its operational plan and the CFUG financial procedure directive; for the cooperative, draft bylaws **v4.15** (मंसिर २०८३). The newest bylaws version always wins.
- **Plan and status log:** Google Drive › Kakani-3 › Chautari.
- **Licence:** AGPL-3.0. Every ward that copies it keeps its improvements open.

## The demo

Open `demo/index.html` in any browser. No build step and no server; the page works offline (with the phone's own Devanagari font).

- Home: four tiles — हाम्रो पैसा, हाम्रो काम, हाम्रो पानी र प्रकृति, हाम्रो निर्णय — and recent payments
- Money: bank and cash, income and spending by head, budget lines, the Forest Act spending shares, every payment, "ask about this"
- Work: fair turns by house number; project hours hidden below 5 people
- Water and nature: spring-flow charts and rainfall
- Decisions: what needs attention, questions and answers, office holders, every rule with its source
- Cooperative (sample until registration): one share of Rs 100 per member, members' project loans (परियोजना ऋण) at one rate, grants, enterprise earnings per hour, the year-end split
- मेरो (pick a sample person): own record, and मेरो खाता with the project loan and the "give notice" button
- काम बाँकी (officers): sign and release payments, approve hours, answer questions; in the demo each button shows the exact entry it would add
- जाँच: the phone re-checks every fingerprint in the record; "change one figure" shows the chain break
- बिलको फोटोबाट हिसाब (treasurer, ledger keeper): photograph a bill; the AI reads it and suggests the entry; the person compares it with the photo and confirms in their own name. The sample has three fictional bills with what the reader really read from them, mistakes included
- पानी र वर्षा नाप (nature guardian, ledger keeper): record a spring's flow or the rain gauge
- काम र घण्टा लेख्ने (ledger keeper, supervisor): pick the worker by name or house number, the project and task, the hours, paid or voluntary, and a before and an after photo; it waits for a supervisor's approval. "Another person, same work" keeps the work, hours and photos for the next worker
- No signal: work hours and water/rain readings are kept on the phone (with their photos) and sent by themselves when there is signal; an ↑ number at the top and "पठाउन बाँकी" in काम बाँकी show what is waiting (`app/src/lib/outbox.ts`)
- मद्दत (कसरी चलाउने?): a step-by-step guide to every function, in Nepali and English, each topic with a button that opens its screen (`app/src/screens/Guide.tsx`; update it whenever a function changes)

To rebuild it after a change: `cd app && npm install && npm run build:preview` (writes `demo/index.html`).

## What is here

```
supabase/migrations/   the database: every rule lives here, so no screen or login can get around it
  …0100  insert-only events, one SHA-256 chain per ward
  …0200  households, people, offices, rules, who may record what
  …0300  the CFUG's books in the directive's format, payment rules
  …0400  work hours, fair turns, parma, springs, questions
  …0500  privacy circles and the one door the app writes through
  …0600  the cooperative: members, shares, loans, grants, enterprises, equal pay, year-end split
  …0700  मेरो खाता and the cooperative's public views
  …0800  fix: the balance check works when the app writes
  …0900  the cooperative follows draft bylaws v4.15
  …1000  the document reader's suggestions and a person's confirmation
  …1100  the work-hours form: the worker list for officers; work needs a before and an after photo (by SHA-256)
  …1200  record_event_once: an entry kept on a phone is recorded once, however often it is sent
seed/demo.sql          sample activity with fictional people (never load into the real database)
tests/                 the rules as tests (run.sh)
reader/                the document reader (Tesseract on our own server): photo in, suggested entry out
samples/               SAMPLE bills and cash-book pages (fictional, stamped नमूना), their truth, and the reader's score
scripts/               chain verifier, sample snapshot export, demo page builder, demo bill readings
app/                   the Nepali-first phone app (Vite + Preact PWA)
demo/index.html        the demo, built from app/
```

## How it works

**Everything is an event.** A receipt, a signature, an hour of work, a spring reading, a rule change: each is one row in `ww.events`. Rows are never updated or deleted, not even by the database owner. A mistake is fixed with a `correction` event; both stay visible.

**The chain.** Each event's fingerprint covers its content and the previous fingerprint, so changing any old entry breaks every later link. Anyone can check the whole chain from the public export without seeing names:

```
node scripts/verify-chain.mjs export.json --head <published head>
```

**Rules in the database:**

| Rule | Source |
| --- | --- |
| A CFUG payment needs the treasurer plus the chair or secretary, two different people, at least one a woman | Constitution s.15 |
| Whoever recorded an expense cannot approve it; nobody approves a payment to themselves or their household | Financial procedure; bylaws v4.15 s.10(3) |
| Cash receipts above Rs 10,000 come through the bank; cash in hand above Rs 5,000 or held over 7 days is flagged | Directive s.9; constitution s.13, s.15 |
| Spending stays within its approved budget line | Constitution s.8, s.15 |
| Payments only to registered payees; expenses need a receipt photo or are marked estimated, capped at 5% | Plan |
| Supervisors never approve their own or their household's hours | Plan |
| Work hours: at most 12 a person a day; a before and an after photo unless a supervisor records them; the worker's name stays private (the public sees hours by house number) | Plan |
| The cooperative takes no savings, never lends; one share of Rs 100 per member; members from 16 | Bylaws v4.15 s.4, s.6, s.7 |
| Members' project loans all earn one rate (now 10%); up to Rs 1 lakh back with interest on 3 months' notice given in चौतारी; above Rs 1 lakh a fixed 3–5 years; loans from others at most 10% | Bylaws v4.15 s.8 |
| Grants are spent only on their purpose and never counted as surplus | Bylaws v4.15 s.15 |
| One hourly rate for everyone, paid only against approved hours, each hour once | Bylaws v4.15 s.13 |
| After the audit: reserve and promotion funds first, then 40% community / 30% protected capital return fund by hours worked / 30% capital, technology and training | Bylaws v4.15 s.14 |

Each limit is a rule with a default (`ww.rule_defaults`); the assembly changes one with a `rule.set` event and its decision reference, with no code change.

**Privacy circles.** The world reads `public.*` views (totals, never people). A member calls `public.my_record()` and `public.my_account()` for their own records only. Officers call `public.officer_*()` while they hold the office. Every write goes through `public.record_event()`.

## Run the tests

Needs PostgreSQL 16 and Node 20.

```
PGHOST=/path/to/socket PGPORT=5432 tests/run.sh
```

## The app (`app/`)

Vite + Preact, Mukta font, Bikram Sambat dates, Nepali digits, English toggle. With `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` set (see `app/.env.example`) it reads and writes the real database, with sign-in by SMS code; without them it runs on `app/src/data/sample-snapshot.json`, exported from the sample database through the same public API (`npm run snapshot`).

Measured 11 Nov 2026: first load 263 KB compressed (budget 300 KB); the home screen in 2.4 s on simulated 3G with a 4× slower CPU.

## Next

Field capture happens in this app, not in ODK (decided 2026-11-19): the forms already exist here, ledger keepers learn one tool, and no importer is needed.

- **B:** duplicate-bill and price-list checks in the reader; test the reader on 50 real bills.
- **C:** done for the field forms (work hours, readings): kept on the phone and sent once when there is signal. Bill reading, signing and approving stay online-only, because they are done against the latest figures.
- **D:** printed vouchers, cash book and the annual report to the Division Forest Office; nightly public export with OpenTimestamps.
- **E:** deploy on our own server (ZenTrust's Azure credits), keys held by two officers. Legal review of the Cooperatives Act and privacy law before members' project loans go live.

## The document reader

A photo of a bill becomes a **suggestion**, never an entry. A named treasurer or ledger keeper checks it against the photo and confirms it in their own name (`public.confirm_suggestion`), and the entry then goes through every normal rule. The confirmed event says, in public, `ai_read: {reader, suggestion, changed}`: that the reader read it, and which fields the person corrected. The photo stays on our server; the chain carries its SHA-256. `public.reader_record` shows everyone how often the reader was right (counts only).

How the reader decides what to tick: it reads each photo four ways (different clean-ups) and marks a figure ✓ only when the readings agree **and** an independent check fits: sub-total + 13% VAT = total, or the item lines add up to the total, or (in a cash book) the running balance closes. Identifiers (bill no., PAN, shop) need every reading to agree. Everything else is ! for the person.

```
cd reader && npm install
node cli.mjs photo.jpg                 # one reading as JSON (add --cashbook for a cash-book page)
node eval.mjs                          # score against samples/truth.json -> samples/READER-REPORT.md
node --test test/*.test.mjs            # the reader's checks
SUPABASE_URL=… SUPABASE_SERVICE_KEY=… DOCS_DIR=/srv/chautari/documents node server.mjs   # the service the app calls (bills: POST /read; work photos: POST /photo)
```

Needs `tesseract` (with `hin` and `eng`) and ImageMagick `convert` on the server. The app finds the service through `VITE_READER_URL`.

**Measured so far on SAMPLE bills only** (`samples/READER-REPORT.md`): no figure marked ✓ was wrong; totals were ticked on 7 of 11 bills; cash-book tables read poorly (most rows go to the person). Real Chauthe bills will read worse until it is tuned on them. Old cash-book rows are read and checked, but how history enters the record is not decided yet (see the status log).
