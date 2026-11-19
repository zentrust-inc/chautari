-- Chautari — 0008: fix found while building the app (11 Nov 2026)
--
-- The "every entry balances" check is a deferred constraint trigger. It fires at commit,
-- outside record_event()'s security-definer context, so it ran as the app's logged-in
-- role, which may not read ww.postings. Result: every money-moving entry sent from the
-- app (income, banking, releasing a payment, shares, loans) failed with
-- "permission denied for table postings". The earlier tests ran as the database owner
-- and did not see it; tests/30_api_roles.sql now writes as the app does.
alter function ww.postings_balanced() security definer set search_path = '';
