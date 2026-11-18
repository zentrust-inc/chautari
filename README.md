# चौतारी (Chautari)

**हाम्रो साझा खाता** — a phone-first, Nepali-language, transparent ledger for the Chauthe (Kakani-3) community forest user group, Kakani multipurpose cooperative and Chauthe Guthi: money, work hours, decisions, and nature's account.

## Status

**Demo only.** `demo/index.html` is a single self-contained page with fictional sample data, built for the CFUG meeting (25–30 Nov 2026). No real village records are stored anywhere. A pilot starts only if the assembly (भेला) approves.

## What the demo shows

- Five sections: पैसा · काम र पालो · पानी र प्रकृति · निर्णय · मेरो खाता
- Bikram Sambat dates and Nepali digits
- Entries go to "पुष्टि हुन बाँकी" until the assembly-chosen record keeper confirms them; the app records, it never pays or registers anything by itself
- Append-only, hash-chained ledger ("माला"): the 🔗 जाँच button verifies the chain in the browser (SHA-256); a sample button quietly changes one bill so everyone can see the chain break
- Corrections are new entries; the old entry stays visible
- Three privacy circles via "म को हुँ?": the public sees totals, a member sees her own entries, only she sees her ID; whether per-person work hours are public is left to the assembly
- A rule suggestion (the app suggests; the assembly decides by consent) and a sample SMS notice

## Run it

Open `demo/index.html` in any browser. No build step, no server, no network needed after loading.

## After the meeting (not started)

Real build per the assembly's decisions: Azure hosting (ZenTrust credits), Aakash SMS, member data only in the database and never in this repository. Chautari records the cooperative's money; the money itself moves through the cooperative's bank account. Legal review of the Cooperatives Act and privacy law before any investment features go live.
