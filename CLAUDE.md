# चौतारी (Chautari) — instructions for Claude

Read this first. Last updated 18 Nov 2026 (BS २०८३ मंसिर २).

## What it is
A phone-first, Nepali-language, transparent ledger for Chauthe (Kakani-3): the Thumki Danda Gairikharka community forest user group (CFUG), Kakani multipurpose cooperative (MPC) and Chauthe Guthi. It keeps money, work hours, decisions and nature's account (springs, ponds, seedlings) in one place. Formerly "Wu Wei OS"; always call it चौतारी / Chautari.

The plain-Nepali explainer for villagers is "चौतारी — हाम्रो साझा खाता" in Google Drive (Kakani-3 → Chautari folder). Keep the app consistent with it.

## Status
- `demo/index.html`: single-file demo with fictional data for the CFUG meeting, 25–30 Nov 2026. Not the real app.
- Real build starts only after the assembly (भेला) approves, and follows its decisions: who keeps the records, whether per-person hours are public, the limit for spending outside the budget, the 7–9 person working group, how members without phones are included.

## Core rules (do not break)
1. **Append-only, hash-chained ledger ("माला")**. Nothing is edited or deleted; mistakes are fixed by a new correction entry and the old one stays visible. Any member can verify the chain from their phone.
2. **The app records; it never pays or decides.** Entries wait as "बाँकी" until the assembly-chosen record keeper presses "पुष्टि". Money moves only through the cooperative's bank account. Get Nepali legal advice (Cooperatives Act, privacy law) before investment or withdrawal features handle real money.
3. **Three privacy circles**: everyone sees group totals; a member sees their own entries (like a passbook); only the person sees their ID. What else is public is decided by the assembly, not by the code.
4. **The app suggests, the assembly decides** rule changes, by consent.
5. **Nepali first**: Nepali UI, Nepali digits, Bikram Sambat dates. English as a switch later; all strings from one translation file.
6. **Cheap phones, weak internet**: light pages, offline-first where possible. Members without phones get printed statements and a helper.
7. **No real member data in this repository**, ever. Sample data is always fictional and labelled नमुना.

## Cooperative facts the app must reflect
- Every member holds exactly one Rs 100 share; no cash dividend.
- Member money is an investment (लगानी) at a fixed 10% a year (current reference rate, fixed for each agreement's term). Up to Rs 1 lakh can be withdrawn with 3 months' notice; above that is fixed-term (3–5 years).
- The MPC never lends.
- Every work hour is paid equally (Rs 100/hour minimum); 30% of net profit goes to active members by equal hours.
- In anything villagers see, say "लगानीकर्ता" (investors), never "दाता" (donors).
- CFUG: 635 members, 121 households; 6 ponds dug at the top of the site.

## Planned stack (not built yet)
Hosting on ZenTrust's Azure credits; SMS via Aakash SMS; code in the zentrust-inc GitHub org. First real features: member register, digital parma (work hours), notices, Guthi fund, living map, nature's account.

## How we work
- Gated phases: agree the scope, build, then the owner reviews. Small pull requests; the owner merges.
- Source documents (bylaws, assembly minutes, the explainer) are the ground truth. Don't invent rules.
- Test in a phone-sized headless browser before opening a PR.
