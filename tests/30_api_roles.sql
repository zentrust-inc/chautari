-- Chautari — writes made the way the app makes them: as the logged-in `authenticated`
-- role, through public.record_event(), including the balance check that runs at commit.
grant usage on schema t to authenticated;
grant execute on all functions in schema t to authenticated;
grant insert, select on t.results to authenticated;
grant usage on sequence t.results_n_seq to authenticated;

create table t.before as select max(seq) as seq from ww.events;

begin;
set local role authenticated;
select t.as_person(4);   -- ledger keeper, as in 10_rules
select t.ev('income.recorded', '{"amount": 300, "account_code": "IN-2.03", "method": "cash", "receipt_no": "api-1", "memo_np": "दाउरा बिक्री"}');
commit;                  -- the deferred "debits equal credits" check fires here, as the app's role

select t.ok('the app can record money that moves (balance check runs at commit as the app''s role)',
  (select count(*) from ww.postings where event_seq = (select seq from t.before) + 1) >= 2);

set role authenticated;
select t.rejects('the app role still cannot write to the books directly',
  $$insert into ww.postings (ward_id, entity_id, event_seq, fiscal_year, occurred_on, account_code, debit, credit)
    values ('kakani-3', 'thumki-cfug', 1, '2083/84', '2026-11-01', 'BS-CASH', 1, 0)$$, 'permission denied');
select t.as_person(9);
select t.rejects('a plain member still cannot record income through the app',
  $$select t.ev('income.recorded', '{"amount": 100, "account_code": "IN-5.03", "method": "cash", "receipt_no": "x"}')$$, 'only treasurer');
reset role;
select t.ok('the ward chain still verifies after app-style writes', (select ok from ww.verify_chain('kakani-3')));
