# चौतारी (Chautari)

**हाम्रो साझा खाता** — a phone-first, Nepali-language, transparent ledger for the Thumki Danda Gairikharka community forest user group (CFUG), the Kakani Multipurpose Cooperative and the Chauthe Guthi in Chauthe (Kakani-3), Nuwakot. It records money, work hours, decisions and nature's account. It records; it never pays, lends or registers anything by itself.

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
seed/demo.sql          sample activity with fictional people (never load into the real database)
tests/                 the rules as tests (run.sh)
scripts/               chain verifier, sample snapshot export, demo page builder
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

- **B:** field forms (work, receipts, readings), the importer, and the document reader: AI reads bills and suggests entries on our own server; a person confirms every entry.
- **C:** offline queue for writes in the app.
- **D:** printed vouchers, cash book and the annual report to the Division Forest Office; nightly public export with OpenTimestamps.
- **E:** deploy on our own server (ZenTrust's Azure credits), keys held by two officers. Legal review of the Cooperatives Act and privacy law before members' project loans go live.
