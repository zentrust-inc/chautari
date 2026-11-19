-- Chautari — rule tests. Each block states the rule it checks.
-- People here are fictional. Run with tests/run.sh.

create schema t;
create table t.results (n serial, name text, ok boolean, detail text);

create function t.ok(p_name text, p_cond boolean, p_detail text default null) returns void
language plpgsql as $$
begin
  insert into t.results (name, ok, detail) values (p_name, coalesce(p_cond, false), p_detail);
  if not coalesce(p_cond, false) then raise exception 'FAILED: % %', p_name, coalesce(p_detail, ''); end if;
end $$;

-- the statement must fail, and the error must mention p_needle
create function t.rejects(p_name text, p_sql text, p_needle text) returns void
language plpgsql as $$
declare msg text;
begin
  begin
    execute p_sql;
    msg := null;
  exception when others then
    msg := sqlerrm;
  end;
  perform t.ok(p_name, msg is not null and msg ilike '%' || p_needle || '%',
               coalesce('got: ' || msg, 'it was accepted'));
end $$;

create function t.as_person(n int) returns void language sql as $$
  select set_config('request.jwt.claim.sub', 'cccccccc-0000-0000-0000-' || lpad(n::text, 12, '0'), false)
$$;
create function t.as_server() returns void language sql as $$
  select set_config('request.jwt.claim.sub', '', false)
$$;
create function t.hh(n int) returns uuid language sql immutable as $$
  select ('aaaaaaaa-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid $$;
create function t.p(n int) returns uuid language sql immutable as $$
  select ('bbbbbbbb-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid $$;

create function t.ev(p_type text, p_payload jsonb, p_private jsonb default '{}', p_fy text default '2083/84',
                     p_evidence jsonb default '[]', p_on date default '2026-11-01')
returns jsonb language sql as $$
  select public.record_event('thumki-cfug', p_type, p_payload, p_private, p_on, p_fy, p_evidence)
$$;
-- a before and an after photo, named by their SHA-256 (what the work-hours form attaches)
create function t.wph(tag text) returns jsonb language sql immutable as $$
  select jsonb_build_array(
    jsonb_build_object('sha256', encode(sha256(convert_to(tag || ' before', 'UTF8')), 'hex'), 'kind', 'before'),
    jsonb_build_object('sha256', encode(sha256(convert_to(tag || ' after', 'UTF8')), 'hex'), 'kind', 'after'))
$$;

-- ---------------------------------------------------------------------------
-- Setup: the ward, the CFUG, households and people (by a trusted server job)
-- ---------------------------------------------------------------------------
insert into ww.wards values ('kakani-3', 'ककनी गाउँपालिका वडा नं. ३ (चाउथे)', 'Kakani-3 (Chauthe)');
insert into ww.entities (id, ward_id, kind, name_np, name_en, source_doc) values
 ('thumki-cfug', 'kakani-3', 'cfug', 'थुम्की डाँडा गैरीखर्क सामुदायिक वन उपभोक्ता समूह',
  'Thumki Danda Gairikharka CFUG', 'विधान २०८२; कार्ययोजना २०८१/८२–२०९०/९१');

select t.as_server();
select t.ev('household.registered', jsonb_build_object('household_id', t.hh(n), 'house_no', n), '{}', null)
  from generate_series(1, 8) n;

select t.ev('person.registered', '{}', jsonb_build_object('person_id', t.p(n), 'display_name', name,
            'gender', g, 'household_id', t.hh(h)), null)
from (values (1,'Sita','f',1),(2,'Hari','m',2),(3,'Ram','m',3),(4,'Gita','f',4),(5,'Bikash','m',5),
             (6,'Kamala','f',6),(7,'Dil','m',2),(8,'Mina','f',5),(9,'Tek','m',7)) v(n, name, g, h);

-- logins (phone OTP) linked to people
update ww.persons set auth_user_id = ('cccccccc-0000-0000-0000-' || lpad(substr(id::text, 25)::int::text, 12, '0'))::uuid;

-- R: the first office holder may be appointed by a server job; after that only the secretary may
select t.ev('role.assigned', jsonb_build_object('person_id', t.p(1), 'role', 'secretary', 'decision_ref', 'साधारण सभा निर्णय नं. १'), '{}', null);
select t.rejects('only the first office holder can be appointed without a person',
  $$select t.ev('role.assigned', jsonb_build_object('person_id', t.p(2), 'role', 'treasurer'), '{}', null)$$,
  'secretary or admin');

select t.as_person(1);
select t.ev('role.assigned', jsonb_build_object('person_id', t.p(n), 'role', r, 'decision_ref', 'साधारण सभा निर्णय नं. १'), '{}', null)
from (values (2,'treasurer'),(3,'chair'),(4,'ledger_keeper'),(5,'supervisor'),(6,'accounts_committee')) v(n, r);
select t.ok('office holders are public', (select count(*) from public.office_holders) = 6);

select t.as_person(9);
select t.rejects('a member who is not secretary cannot appoint',
  $$select t.ev('role.assigned', jsonb_build_object('person_id', t.p(9), 'role', 'treasurer'), '{}', null)$$,
  'only secretary');

-- ---------------------------------------------------------------------------
-- History cannot change
-- ---------------------------------------------------------------------------
select t.as_server();
select t.rejects('events cannot be updated', $$update ww.events set payload = '{}' where seq = 1$$, 'not allowed');
select t.rejects('events cannot be deleted', $$delete from ww.events where seq = 1$$, 'not allowed');
select t.rejects('events cannot be truncated', $$truncate ww.events cascade$$, 'not allowed');
select t.rejects('unknown event types are rejected', $$select t.ev('money.vanished', '{}')$$, 'unknown event type');

-- ---------------------------------------------------------------------------
-- Income, cash and the bank (directive s.9, constitution s.13 and s.15)
-- ---------------------------------------------------------------------------
select t.as_person(2);   -- treasurer
select t.ev('balance.opened', '{"cash": 2000, "bank": 50000}');
select t.rejects('opening balances only once a year', $$select t.ev('balance.opened', '{"cash": 1, "bank": 0}')$$, 'already recorded');

select t.as_person(4);   -- ledger keeper
select t.ev('income.recorded', '{"amount": 5000, "account_code": "IN-2.03", "method": "cash", "receipt_no": "१०१", "memo_np": "दाउरा बिक्री"}');
select t.ok('a voucher number is given', (select (payload->>'voucher_no')::int from ww.events where type = 'income.recorded' order by seq desc limit 1) = 2);
select t.ok('cash in hand is opening + income', ww.balance('thumki-cfug', 'BS-CASH') = 7000);
select t.rejects('cash above Rs 10,000 must come through the bank',
  $$select t.ev('income.recorded', '{"amount": 15000, "account_code": "IN-2.06", "method": "cash", "receipt_no": "१०२"}')$$,
  'through the bank');
select t.ev('income.recorded', '{"amount": 120000, "account_code": "IN-3.03", "method": "bank", "receipt_no": "१०३", "memo_np": "ZenTrust अनुदान"}');
select t.rejects('a receipt number is required',
  $$select t.ev('income.recorded', '{"amount": 100, "account_code": "IN-5.03", "method": "cash"}')$$, 'receipt_no');
select t.rejects('opening-balance heads cannot be used as income',
  $$select t.ev('income.recorded', '{"amount": 100, "account_code": "IN-1.02", "method": "cash", "receipt_no": "x"}')$$, 'balance.opened');

select t.as_person(9);   -- plain member
select t.rejects('a member without a duty cannot record income',
  $$select t.ev('income.recorded', '{"amount": 100, "account_code": "IN-5.03", "method": "cash", "receipt_no": "x"}')$$, 'only treasurer');
select t.rejects('nobody can record in someone else''s name',
  $$insert into ww.events (ward_id, entity_id, type, payload, actor, occurred_on, fiscal_year)
    values ('kakani-3', 'thumki-cfug', 'income.recorded',
            '{"amount": 100, "account_code": "IN-5.03", "method": "cash", "receipt_no": "x"}', t.p(2), '2026-11-01', '2083/84')$$,
  'someone else');

select t.as_person(4);
select t.rejects('cannot bank more than the cash in hand', $$select t.ev('cash.banked', '{"amount": 9000, "bank_ref": "B1"}')$$, 'cash in hand');
select t.ev('cash.banked', '{"amount": 6000, "bank_ref": "जम्मा भौचर ५५"}');
select t.ok('banking moves cash to the bank', ww.balance('thumki-cfug', 'BS-CASH') = 1000
            and ww.balance('thumki-cfug', 'BS-BANK') = 176000);

-- every event balances
select t.ok('every entry balances', not exists (
  select 1 from ww.postings group by event_seq having sum(debit) <> sum(credit)));

-- ---------------------------------------------------------------------------
-- Budget lines and payees
-- ---------------------------------------------------------------------------
select t.as_person(1);   -- secretary records the assembly's budget
select t.ev('budget.approved', '{"line_id": "dddddddd-0000-0000-0000-000000000001", "account_code": "EX-2.02",
            "amount": 40000, "title_np": "नर्सरी सञ्चालन", "decision_ref": "साधारण सभा २०८३/०७/२५ निर्णय नं. ३"}');
select t.ev('budget.approved', '{"line_id": "dddddddd-0000-0000-0000-000000000002", "account_code": "EX-4.00",
            "amount": 30000, "title_np": "विपन्न घरधुरी बाख्रा", "decision_ref": "साधारण सभा २०८३/०७/२५ निर्णय नं. ४"}');
select t.rejects('a budget line needs its decision reference',
  $$select t.ev('budget.approved', '{"line_id": "dddddddd-0000-0000-0000-000000000009", "account_code": "EX-2.02", "amount": 1, "title_np": "x"}')$$,
  'decision_ref');

select t.as_person(4);
select t.ev('payee.registered', '{"payee_id": "eeeeeeee-0000-0000-0000-000000000001", "kind": "shop", "name": "ककनी कृषि पसल"}');
select t.ev('payee.registered', '{"payee_id": "eeeeeeee-0000-0000-0000-000000000002", "kind": "person"}',
            jsonb_build_object('person_id', t.p(7)), null);       -- Dil, same household as the treasurer
select t.ev('payee.registered', '{"payee_id": "eeeeeeee-0000-0000-0000-000000000003", "kind": "person"}',
            jsonb_build_object('person_id', t.p(9)), null);       -- Tek
select t.rejects('a person''s name never goes in the public part',
  $$select t.ev('payee.registered', '{"payee_id": "eeeeeeee-0000-0000-0000-000000000004", "kind": "person", "name": "Tek"}', '{"person_id": "bbbbbbbb-0000-0000-0000-000000000009"}', null)$$,
  'private part');

-- ---------------------------------------------------------------------------
-- Expenses and the signature rule (constitution s.15; bylaws v4 s.52)
-- ---------------------------------------------------------------------------
select t.rejects('an expense needs its receipt photo',
  $$select t.ev('expense.recorded', '{"expense_id": "ffffffff-0000-0000-0000-000000000001", "amount": 30000, "account_code": "EX-2.02",
     "payee_id": "eeeeeeee-0000-0000-0000-000000000001", "method": "bank", "budget_line_id": "dddddddd-0000-0000-0000-000000000001", "memo_np": "बिरुवा थैली"}')$$,
  'receipt photo');
select t.rejects('payments only to registered payees',
  $$select t.ev('expense.recorded', '{"expense_id": "ffffffff-0000-0000-0000-000000000001", "amount": 30000, "account_code": "EX-2.02",
     "payee_id": "eeeeeeee-0000-0000-0000-00000000ffff", "method": "bank", "memo_np": "x"}', '{}', '2083/84', '[{"sha256":"ab"}]')$$,
  'registered payee');
select t.ev('expense.recorded', '{"expense_id": "ffffffff-0000-0000-0000-000000000001", "amount": 30000, "account_code": "EX-2.02",
     "payee_id": "eeeeeeee-0000-0000-0000-000000000001", "method": "bank", "budget_line_id": "dddddddd-0000-0000-0000-000000000001",
     "memo_np": "बिरुवा थैली र मल"}', '{}', '2083/84', '[{"sha256": "9f2c", "kind": "receipt"}]');
select t.ok('recording is not paying: nothing in the books yet',
  not exists (select 1 from ww.postings where account_code = 'EX-2.02'));

select t.as_person(2);
select t.rejects('no release before signatures', $$select t.ev('payment.released', '{"expense_id": "ffffffff-0000-0000-0000-000000000001"}')$$, 'treasurer has not signed');
select t.ev('payment.approved', '{"expense_id": "ffffffff-0000-0000-0000-000000000001", "as_role": "treasurer"}');
select t.rejects('the treasurer alone is not enough', $$select t.ev('payment.released', '{"expense_id": "ffffffff-0000-0000-0000-000000000001"}')$$, 'chair or the secretary');
select t.rejects('the same person cannot sign twice', $$select t.ev('payment.approved', '{"expense_id": "ffffffff-0000-0000-0000-000000000001", "as_role": "treasurer"}')$$, 'already given');
select t.as_person(4);
select t.rejects('the ledger keeper cannot sign', $$select t.ev('payment.approved', '{"expense_id": "ffffffff-0000-0000-0000-000000000001", "as_role": "secretary"}')$$, 'only treasurer');
select t.as_person(3);
select t.rejects('you can only sign in an office you hold', $$select t.ev('payment.approved', '{"expense_id": "ffffffff-0000-0000-0000-000000000001", "as_role": "secretary"}')$$, 'do not hold');
select t.as_person(1);   -- secretary, a woman
select t.ev('payment.approved', '{"expense_id": "ffffffff-0000-0000-0000-000000000001", "as_role": "secretary"}');
select t.ev('payment.released', '{"expense_id": "ffffffff-0000-0000-0000-000000000001"}');
select t.ok('the payment is in the books', ww.balance('thumki-cfug', 'BS-BANK') = 146000
            and ww.balance('thumki-cfug', 'EX-2.02') = 30000);
select t.ok('budget left on the line', (select remaining from public.budget_status where line_id = 'dddddddd-0000-0000-0000-000000000001') = 10000);

-- over budget
select t.as_person(4);
select t.ev('expense.recorded', '{"expense_id": "ffffffff-0000-0000-0000-000000000002", "amount": 15000, "account_code": "EX-2.02",
     "payee_id": "eeeeeeee-0000-0000-0000-000000000001", "method": "bank", "budget_line_id": "dddddddd-0000-0000-0000-000000000001",
     "memo_np": "थप बिरुवा"}', '{}', '2083/84', '[{"sha256": "aa01"}]');
select t.as_person(2); select t.ev('payment.approved', '{"expense_id": "ffffffff-0000-0000-0000-000000000002", "as_role": "treasurer"}');
select t.as_person(1); select t.ev('payment.approved', '{"expense_id": "ffffffff-0000-0000-0000-000000000002", "as_role": "secretary"}');
select t.rejects('a payment cannot pass its budget line', $$select t.ev('payment.released', '{"expense_id": "ffffffff-0000-0000-0000-000000000002"}')$$, 'has only Rs 10000');

-- woman signer: treasurer (m) and chair (m) only — use the pro-poor line
select t.as_person(4);
select t.ev('expense.recorded', '{"expense_id": "ffffffff-0000-0000-0000-000000000003", "amount": 8000, "account_code": "EX-4.00",
     "payee_id": "eeeeeeee-0000-0000-0000-000000000003", "method": "bank", "budget_line_id": "dddddddd-0000-0000-0000-000000000002",
     "memo_np": "बाख्रा खरिद सहयोग"}', '{}', '2083/84', '[{"sha256": "aa02"}]');
select t.as_person(2); select t.ev('payment.approved', '{"expense_id": "ffffffff-0000-0000-0000-000000000003", "as_role": "treasurer"}');
select t.as_person(3); select t.ev('payment.approved', '{"expense_id": "ffffffff-0000-0000-0000-000000000003", "as_role": "chair"}');
select t.rejects('one of the signers must be a woman', $$select t.ev('payment.released', '{"expense_id": "ffffffff-0000-0000-0000-000000000003"}')$$, 'woman');

-- the recorder cannot approve; nobody approves a payment to their own household
select t.as_person(2);   -- treasurer records an unbudgeted expense to Dil (treasurer's household)
select t.ev('expense.recorded', '{"expense_id": "ffffffff-0000-0000-0000-000000000004", "amount": 2000, "account_code": "EX-2.01",
     "payee_id": "eeeeeeee-0000-0000-0000-000000000002", "method": "cash", "memo_np": "वन हेरालु ज्याला"}', '{}', '2083/84', '[{"sha256": "aa03"}]');
select t.rejects('the recorder cannot approve the payment',
  $$select t.ev('payment.approved', '{"expense_id": "ffffffff-0000-0000-0000-000000000004", "as_role": "treasurer"}')$$, 'recorded an expense');
select t.as_person(4);
select t.ev('expense.recorded', '{"expense_id": "ffffffff-0000-0000-0000-000000000005", "amount": 2000, "account_code": "EX-2.01",
     "payee_id": "eeeeeeee-0000-0000-0000-000000000002", "method": "cash", "memo_np": "वन हेरालु ज्याला"}', '{}', '2083/84', '[{"sha256": "aa04"}]');
select t.as_person(2);
select t.rejects('no approval of a payment to your own household',
  $$select t.ev('payment.approved', '{"expense_id": "ffffffff-0000-0000-0000-000000000005", "as_role": "treasurer"}')$$, 'own household');

-- unbudgeted spending limit
select t.as_person(4);
select t.rejects('unbudgeted spending above the limit needs the assembly',
  $$select t.ev('expense.recorded', '{"expense_id": "ffffffff-0000-0000-0000-000000000006", "amount": 30000, "account_code": "EX-3.02",
     "payee_id": "eeeeeeee-0000-0000-0000-000000000001", "method": "bank", "memo_np": "बाटो मर्मत"}', '{}', '2083/84', '[{"sha256": "aa05"}]')$$,
  'general assembly');

-- lost receipts: estimated spending is capped
select t.ev('expense.recorded', '{"expense_id": "ffffffff-0000-0000-0000-000000000007", "amount": 9000, "account_code": "EX-1.08",
     "payee_id": "eeeeeeee-0000-0000-0000-000000000001", "method": "bank", "estimated": true, "memo_np": "बिल हराएको: इन्धन"}');
select t.as_person(2); select t.ev('payment.approved', '{"expense_id": "ffffffff-0000-0000-0000-000000000007", "as_role": "treasurer"}');
select t.as_person(1); select t.ev('payment.approved', '{"expense_id": "ffffffff-0000-0000-0000-000000000007", "as_role": "secretary"}');
select t.rejects('estimated spending is capped', $$select t.ev('payment.released', '{"expense_id": "ffffffff-0000-0000-0000-000000000007"}')$$, 'estimated spending would pass');

-- ---------------------------------------------------------------------------
-- Corrections reverse, never erase
-- ---------------------------------------------------------------------------
select t.as_person(2);
select t.ev('correction', jsonb_build_object('corrects_seq',
  (select seq from ww.events where type = 'income.recorded' and payload->>'receipt_no' = '१०१'), 'reason_np', 'रकम गलत लेखियो'));
select t.ok('a correction reverses the original', ww.balance('thumki-cfug', 'IN-2.03') = 0
            and ww.balance('thumki-cfug', 'BS-CASH') = 1000 - 5000);
select t.ok('both entries stay in the log',
  (select count(*) from ww.events where type in ('income.recorded', 'correction')) = 3);
select t.rejects('an entry is corrected only once',
  $$select t.ev('correction', jsonb_build_object('corrects_seq', (select seq from ww.events where type = 'income.recorded' and payload->>'receipt_no' = '१०१'), 'reason_np', 'फेरि'))$$,
  'already corrected');

-- ---------------------------------------------------------------------------
-- Work hours and fair turns (bylaws v4 s.53–54)
-- ---------------------------------------------------------------------------
select t.as_person(4);
select t.ev('work.logged', jsonb_build_object('work_id', 'abababab-0000-0000-0000-00000000000' || n, 'project', 'pond-4',
            'task_np', 'पोखरी किनार बलियो पार्ने', 'hours', 6, 'paid', true, 'output_qty', 12, 'output_unit', 'मिटर'),
            jsonb_build_object('person_id', t.p(w)), null, t.wph('pond ' || n), '2026-11-02')
from (values (1, 9), (2, 8), (3, 2)) v(n, w);
select t.rejects('photos are required', $$select t.ev('work.logged', '{"work_id": "abababab-0000-0000-0000-000000000009", "project": "pond-4", "task_np": "x", "hours": 2, "paid": true}', '{"person_id": "bbbbbbbb-0000-0000-0000-000000000009"}', null)$$, 'photos');
select t.rejects('a before photo alone is not enough',
  $$select t.ev('work.logged', '{"work_id": "abababab-0000-0000-0000-000000000009", "project": "pond-4", "task_np": "x", "hours": 2, "paid": true}', '{"person_id": "bbbbbbbb-0000-0000-0000-000000000009"}', null, t.wph('z') - 1)$$, 'before/after');
select t.rejects('a photo must be named by its SHA-256',
  $$select t.ev('work.logged', '{"work_id": "abababab-0000-0000-0000-000000000009", "project": "pond-4", "task_np": "x", "hours": 2, "paid": true}', '{"person_id": "bbbbbbbb-0000-0000-0000-000000000009"}', null, '[{"sha256": "ph01", "kind": "before"}, {"sha256": "ph02", "kind": "after"}]')$$, 'before/after');
select t.rejects('no more than 12 hours a day',
  $$select t.ev('work.logged', '{"work_id": "abababab-0000-0000-0000-000000000008", "project": "pond-4", "task_np": "x", "hours": 7, "paid": true}', '{"person_id": "bbbbbbbb-0000-0000-0000-000000000009"}', null, t.wph('x'), '2026-11-02')$$,
  'more than 12 hours');

select t.as_person(5);   -- supervisor, household 5
select t.ev('work.approved', '{"work_id": "abababab-0000-0000-0000-000000000001"}');
select t.ev('work.approved', '{"work_id": "abababab-0000-0000-0000-000000000003"}');
select t.rejects('no approval of your own household''s hours', $$select t.ev('work.approved', '{"work_id": "abababab-0000-0000-0000-000000000002"}')$$, 'own household');
select t.as_person(4);
select t.ev('work.logged', '{"work_id": "abababab-0000-0000-0000-000000000004", "project": "pond-4", "task_np": "x", "hours": 3, "paid": false}',
            jsonb_build_object('person_id', t.p(5)), null, t.wph('y'), '2026-11-03');
select t.as_person(5);
select t.rejects('no approval of your own hours', $$select t.ev('work.approved', '{"work_id": "abababab-0000-0000-0000-000000000004"}')$$, 'own hours');

select t.ok('fair turns list paid hours per household number',
  (select paid_hours from public.fair_turns where house_no = 7) = 6
  and (select paid_hours from public.fair_turns where house_no = 2) = 6);
select t.ok('fair turns never show a name', not exists (
  select 1 from information_schema.columns where table_schema = 'public' and table_name = 'fair_turns'
     and column_name in ('display_name', 'person_id', 'household_id')));
select t.ok('project totals hide groups smaller than 5',
  (select too_few_to_show and hours is null from public.project_hours where project = 'pond-4'));

select t.as_person(1);
select t.rejects('a rule change needs its decision reference',
  $$select t.ev('rule.set', '{"key": "fair_turns_public", "value": false}', '{}', null)$$, 'decision_ref');
select t.ev('rule.set', '{"key": "fair_turns_public", "value": false, "decision_ref": "साधारण सभा निर्णय नं. ७"}', '{}', null);
select t.ok('the assembly can make fair turns private', (select count(*) from public.fair_turns) = 0);
select t.ev('rule.set', '{"key": "fair_turns_public", "value": true, "decision_ref": "साधारण सभा निर्णय नं. ८"}', '{}', null);

-- ---------------------------------------------------------------------------
-- Parma, nature, questions
-- ---------------------------------------------------------------------------
select t.as_person(4);
select t.ev('parma.exchanged', '{"days": 2, "task_np": "धान रोपाइँ"}',
            jsonb_build_object('helper_household_id', t.hh(7), 'helped_household_id', t.hh(3)), null);
select t.ev('reading.spring', '{"spring_id": "kalo-dhara", "litres_per_minute": 4.5, "method": "बाल्टी र घडी"}', '{}', null);
select t.ok('spring readings are public', (select value from public.nature_readings where site = 'kalo-dhara') = 4.5);

select t.as_person(9);
select t.ev('question.raised', jsonb_build_object('question_id', '12121212-0000-0000-0000-000000000001',
            'about_seq', (select seq from ww.events where type = 'payment.released' limit 1)),
            '{"text_np": "बिरुवा थैली किन यति महँगो?"}', null);
select t.ok('the public sees the question but not who asked',
  (select status from public.questions) = 'open'
  and not exists (select 1 from information_schema.columns where table_schema = 'public'
                   and table_name = 'questions' and column_name in ('asked_by', 'text_np')));
select t.rejects('only the accounts committee sees who asked', $$select * from public.officer_questions('thumki-cfug')$$, 'accounts_committee');
select t.as_person(6);
select t.ok('the accounts committee sees the question', (select asked_by from public.officer_questions('thumki-cfug')) = 'Tek');
select t.ev('question.closed', '{"question_id": "12121212-0000-0000-0000-000000000001", "outcome": "explained",
            "answer_np": "थैलीसँगै मल पनि किनिएको थियो; बिल हेर्न सकिन्छ।"}', '{}', null);
select t.ok('the answer is public', (select outcome from public.questions) = 'explained');

-- ---------------------------------------------------------------------------
-- A member sees their own record
-- ---------------------------------------------------------------------------
select t.as_person(9);
select t.ok('a member sees their own work and payments',
  jsonb_array_length(public.my_record()->'work') = 1 and (public.my_record()->'person'->>'house_no')::int = 7);
select t.ok('a member sees their household''s parma', (public.my_record()->'parma'->0->>'days_we_helped')::numeric = 2);
select t.rejects('a member cannot read the full vouchers', $$select * from public.officer_vouchers('thumki-cfug', '2083/84')$$, 'this view is for');

-- ---------------------------------------------------------------------------
-- The books in the directive's format
-- ---------------------------------------------------------------------------
select t.as_person(2);
select t.ok('vouchers are numbered without gaps',
  (select array_agg(distinct voucher_no order by voucher_no) from public.officer_vouchers('thumki-cfug', '2083/84'))
   = (select array_agg(n) from generate_series(1, (select max(voucher_no) from ww.postings)) n));
select t.ok('the cash book ends at cash in hand',
  (select balance from public.officer_cash_book('thumki-cfug', '2083/84') order by voucher_no desc limit 1) = ww.balance('thumki-cfug', 'BS-CASH'));
select t.ok('spending shares are tracked', (select forest_spent from public.spending_shares) = 30000);

-- ---------------------------------------------------------------------------
-- The chain
-- ---------------------------------------------------------------------------
select t.as_server();
select t.ok('the chain verifies', (select ok from ww.verify_chain('kakani-3')));
do $$
begin
  alter table ww.events disable trigger events_no_update;
  update ww.events set payload = jsonb_set(payload, '{amount}', '"50"') where type = 'income.recorded' and payload->>'receipt_no' = '१०३';
  perform t.ok('tampering is detected', (select not ok and reason = 'hash does not match content' from ww.verify_chain('kakani-3')));
  raise exception 'rollback';
exception when others then
  if sqlerrm <> 'rollback' then raise; end if;
end $$;
select t.ok('after rollback the chain verifies again', (select ok from ww.verify_chain('kakani-3')));

-- ---------------------------------------------------------------------------
-- The public circle cannot see the core
-- ---------------------------------------------------------------------------
grant usage on schema t to anon;
grant execute on all functions in schema t to anon;
grant insert on t.results to anon;
grant usage on sequence t.results_n_seq to anon;
set role anon;
select t.rejects('the public cannot read events directly', $$select * from ww.events$$, 'permission denied');
select t.rejects('the public cannot read people', $$select * from ww.persons$$, 'permission denied');
select t.rejects('the public cannot write', $$select t.ev('reading.rain', '{"gauge_id": "g1", "mm": 3}', '{}', null)$$, 'permission denied');
select t.rejects('the public cannot read members'' records', $$select public.my_record()$$, 'permission denied');
select t.ok('the public can read the chain export', (select count(*) from public.chain_export) > 30);
select t.ok('the export carries no names', not exists (
  select 1 from public.chain_export where payload_text ~ '(Sita|Hari|Ram|Gita|Bikash|Kamala|Dil|Mina|Tek)'));
select t.ok('the public sees money status', (select in_bank from public.money_status) = 146000);
reset role;

select format('%s checks passed', count(*)) as summary from t.results where ok;
