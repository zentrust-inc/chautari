-- Chautari — cooperative (MPC) tests. Runs after 10_rules.sql in the same database,
-- reusing its ward, people and helpers. People are fictional.

create function t.mev(p_type text, p_payload jsonb, p_private jsonb default '{}', p_fy text default '2083/84',
                      p_evidence jsonb default '[]', p_on date default '2026-11-04')
returns jsonb language sql as $$
  select public.record_event('kakani-mpc', p_type, p_payload, p_private, p_on, p_fy, p_evidence)
$$;
create function t.u(prefix text, n int) returns uuid language sql immutable as $$
  select (prefix || '-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid $$;

select t.as_server();
insert into ww.entities (id, ward_id, kind, name_np, name_en, source_doc) values
 ('kakani-mpc', 'kakani-3', 'mpc', 'ककनी बहुउद्देश्यीय सहकारी संस्था लिमिटेड', 'Kakani Multipurpose Cooperative Ltd.',
  'Draft MPC bylaws v4 (Kartik 2083)');

-- the cooperative's own board (roles are per body)
select t.mev('role.assigned', jsonb_build_object('person_id', t.p(4), 'role', 'secretary', 'decision_ref', 'प्रारम्भिक साधारण सभा निर्णय नं. १'), '{}', null);
select t.as_person(4);
select t.mev('role.assigned', jsonb_build_object('person_id', t.p(n), 'role', r, 'decision_ref', 'प्रारम्भिक साधारण सभा निर्णय नं. १'), '{}', null)
from (values (1,'chair'),(3,'treasurer'),(7,'ledger_keeper'),(5,'supervisor'),(6,'accounts_committee')) v(n, r);
select t.ok('CFUG offices give no power in the MPC',
  not ww.has_role('kakani-mpc', t.p(2), array['treasurer']) and ww.has_role('kakani-mpc', t.p(3), array['treasurer']));

-- ---------------------------------------------------------------------------
-- Members (s.15–21)
-- ---------------------------------------------------------------------------
select t.as_person(1);
select t.rejects('membership belongs to the cooperative, not the CFUG',
  $$select t.ev('member.admitted', '{"member_no": 1, "decision_ref": "x"}', '{"person_id": "bbbbbbbb-0000-0000-0000-000000000009", "self_declaration": true}', null)$$,
  'belongs to the cooperative');
select t.as_person(4);
select t.rejects('a member signs the self-declaration',
  $$select t.mev('member.admitted', '{"member_no": 1, "decision_ref": "सञ्चालक समिति निर्णय नं. २"}', '{"person_id": "bbbbbbbb-0000-0000-0000-000000000009"}', null)$$,
  'self-declaration');
select t.mev('member.admitted', jsonb_build_object('member_no', n, 'decision_ref', 'सञ्चालक समिति निर्णय नं. २'),
             jsonb_build_object('person_id', t.p(n), 'self_declaration', true), null)
from generate_series(1, 9) n;
select t.rejects('no one is admitted twice',
  $$select t.mev('member.admitted', '{"member_no": 20, "decision_ref": "x"}', '{"person_id": "bbbbbbbb-0000-0000-0000-000000000009", "self_declaration": true}', null)$$,
  'already a member');

-- ---------------------------------------------------------------------------
-- Shares (bylaws v4.15 s.7): every member holds exactly one share of Rs 100
-- ---------------------------------------------------------------------------
select t.as_person(7);   -- ledger keeper
select t.rejects('the amount matches the share price',
  $$select t.mev('shares.purchased', '{"kitta": 1, "amount": 90, "method": "cash", "receipt_no": "श-१"}', '{"person_id": "bbbbbbbb-0000-0000-0000-000000000009"}')$$,
  'cost Rs 100');
select t.rejects('nobody holds more than one share',
  $$select t.mev('shares.purchased', '{"kitta": 2, "amount": 200, "method": "cash", "receipt_no": "श-१"}', '{"person_id": "bbbbbbbb-0000-0000-0000-000000000009"}')$$,
  'exactly 1 share');
select t.mev('shares.purchased', jsonb_build_object('kitta', 1, 'amount', 100, 'method', 'cash', 'receipt_no', 'श-' || n),
             jsonb_build_object('person_id', t.p(n)))
from generate_series(1, 9) n;
select t.rejects('a second share is refused later too',
  $$select t.mev('shares.purchased', '{"kitta": 1, "amount": 100, "method": "cash", "receipt_no": "श-x"}', '{"person_id": "bbbbbbbb-0000-0000-0000-000000000009"}')$$,
  'make a project loan');
select t.ok('shares held are counted from the record', ww.shares_held('kakani-mpc', t.p(9)) = 1
            and ww.share_capital('kakani-mpc') = 900);

-- ---------------------------------------------------------------------------
-- Project loans (s.8) — the cooperative never lends and takes no savings (s.4)
-- ---------------------------------------------------------------------------
select t.ok('there is no deposit or savings entry at all', not exists (
  select 1 from ww.event_types where type ~ '(deposit|saving)'));
select t.as_person(3);   -- MPC treasurer
select t.rejects('a loan from others above 10% is refused, banks included',
  $$select t.mev('loan.received', '{"loan_id": "10000000-0000-0000-0000-000000000001", "lender_kind": "bank", "lender_name": "Some bank", "amount": 100000, "rate_pct": 12, "term_months": 36, "decision_ref": "x", "method": "bank", "assembly_approved": true}')$$,
  'above 10%');
select t.mev('loan.received', '{"loan_id": "10000000-0000-0000-0000-000000000001", "lender_kind": "organisation", "lender_name": "ZenTrust",
             "amount": 200000, "rate_pct": 4, "term_months": 60, "decision_ref": "साधारण सभा निर्णय नं. ५", "method": "bank"}', '{}', '2083/84', '[]', '2026-08-01');
select t.rejects('every member''s project loan earns the same rate',
  $$select t.mev('loan.received', '{"loan_id": "10000000-0000-0000-0000-000000000002", "lender_kind": "member", "amount": 20000, "rate_pct": 6, "decision_ref": "x", "method": "bank"}', '{"person_id": "bbbbbbbb-0000-0000-0000-000000000004"}')$$,
  'same rate');
select t.rejects('a project loan above Rs 1 lakh has a fixed 3–5 year term',
  $$select t.mev('loan.received', '{"loan_id": "10000000-0000-0000-0000-000000000002", "lender_kind": "member", "amount": 150000, "rate_pct": 10, "term_months": 24, "decision_ref": "x", "method": "bank"}', '{"person_id": "bbbbbbbb-0000-0000-0000-000000000004"}')$$,
  '36 to 60 months');
select t.mev('loan.received', '{"loan_id": "10000000-0000-0000-0000-000000000002", "lender_kind": "member", "amount": 150000,
             "rate_pct": 10, "term_months": 36, "decision_ref": "साधारण सभा निर्णय नं. ६", "method": "bank"}',
             jsonb_build_object('person_id', t.p(4)), '2083/84', '[]', '2026-08-01');
select t.rejects('a member lender''s name stays private',
  $$select t.mev('loan.received', '{"loan_id": "10000000-0000-0000-0000-000000000003", "lender_kind": "member", "lender_name": "Tek", "amount": 20000, "rate_pct": 10, "decision_ref": "x", "method": "bank"}', '{"person_id": "bbbbbbbb-0000-0000-0000-000000000009"}')$$,
  'private part');
select t.mev('loan.received', '{"loan_id": "10000000-0000-0000-0000-000000000003", "lender_kind": "member", "amount": 30000,
             "rate_pct": 10, "decision_ref": "साधारण सभा निर्णय नं. ६", "method": "bank"}',
             jsonb_build_object('person_id', t.p(9)), '2083/84', '[]', '2026-08-01');
select t.ok('up to Rs 1 lakh a project loan is withdrawable on notice; above it the term is fixed',
  (select withdrawal from public.loan_register where loan_id = t.u('10000000', 3)) = 'notice'
  and (select withdrawal from public.loan_register where loan_id = t.u('10000000', 2)) = 'fixed');
select t.rejects('interest cannot pass the agreed rate',
  $$select t.mev('loan.repaid', '{"loan_id": "10000000-0000-0000-0000-000000000003", "principal": 5000, "interest": 1500, "method": "bank"}')$$,
  'at most Rs');
select t.mev('loan.repaid', '{"loan_id": "10000000-0000-0000-0000-000000000003", "principal": 5000, "interest": 750, "method": "bank"}');
select t.ok('the loan register shows what is owed', (select outstanding from public.loan_register where loan_id = t.u('10000000', 3)) = 25000);
select t.ok('a member lender is unnamed in public', (select lender_name from public.loan_register where loan_id = t.u('10000000', 3)) is null
            and (select lender_name from public.loan_register where loan_id = t.u('10000000', 1)) = 'ZenTrust');

-- notice to withdraw, given by the member in the app (s.8(2), s.9(3))
select t.as_person(4);
select t.rejects('only the lender can give notice',
  $$select t.mev('loan.notice_given', '{"loan_id": "10000000-0000-0000-0000-000000000003"}', '{}', null, '[]', '2026-11-05')$$,
  'only the member who made the loan');
select t.rejects('a fixed-term project loan cannot be called early',
  $$select t.mev('loan.notice_given', '{"loan_id": "10000000-0000-0000-0000-000000000002"}', '{}', null, '[]', '2026-11-05')$$,
  'fixed term');
select t.as_person(9);
select t.mev('loan.notice_given', '{"loan_id": "10000000-0000-0000-0000-000000000003"}', '{}', null, '[]', '2026-11-05');
select t.ok('the register shows the notice and the date it falls due (3 months)',
  (select repay_due_on from public.loan_register where loan_id = t.u('10000000', 3)) = '2026-11-05'::date + 90
  and (select notice_amount from public.loan_register where loan_id = t.u('10000000', 3)) = 25000);
select t.rejects('notice is given once until it is repaid',
  $$select t.mev('loan.notice_given', '{"loan_id": "10000000-0000-0000-0000-000000000003"}', '{}', null, '[]', '2026-11-06')$$,
  'already given');
select t.as_person(3);   -- back to the treasurer

-- ---------------------------------------------------------------------------
-- Grants (s.65–69) and enterprises (s.85–86)
-- ---------------------------------------------------------------------------
select t.mev('grant.received', '{"grant_id": "20000000-0000-0000-0000-000000000001", "donor": "ZenTrust", "purpose_np": "CNC मेसिन",
             "amount": 100000, "agreement_ref": "अनुदान सम्झौता २०८३-०१"}');
select t.as_person(4);
select t.mev('enterprise.approved', '{"enterprise_id": "30000000-0000-0000-0000-000000000001", "name_np": "खोटो संकलन र बिक्री",
             "plan_ref": "साधारण सभा २०८३/०७ निर्णय नं. ३ (उद्यम योजना)"}', '{}', null);
select t.mev('budget.approved', '{"line_id": "40000000-0000-0000-0000-000000000001", "account_code": "EX-WAGES", "amount": 100000,
             "title_np": "खोटो संकलन ज्याला", "decision_ref": "साधारण सभा निर्णय नं. ४"}');
select t.mev('budget.approved', '{"line_id": "40000000-0000-0000-0000-000000000002", "account_code": "EX-MATERIALS", "amount": 150000,
             "title_np": "कच्चा पदार्थ र मेसिन", "decision_ref": "साधारण सभा निर्णय नं. ४"}');

select t.as_person(7);
select t.rejects('income is tagged only to an approved enterprise',
  $$select t.mev('income.recorded', '{"amount": 1000, "account_code": "IN-SALES", "method": "bank", "receipt_no": "ब-x", "enterprise_id": "30000000-0000-0000-0000-000000000009"}')$$,
  'unknown enterprise');
select t.mev('income.recorded', '{"amount": 60000, "account_code": "IN-SALES", "method": "bank", "receipt_no": "ब-१",
             "memo_np": "खोटो बिक्री, ५ टन", "enterprise_id": "30000000-0000-0000-0000-000000000001"}');

select t.mev('payee.registered', '{"payee_id": "50000000-0000-0000-0000-000000000001", "kind": "shop", "name": "बिदुर मेसिनरी"}');
select t.mev('payee.registered', '{"payee_id": "50000000-0000-0000-0000-000000000002", "kind": "person"}', jsonb_build_object('person_id', t.p(9)), null);
select t.mev('payee.registered', '{"payee_id": "50000000-0000-0000-0000-000000000003", "kind": "organisation",
             "name": "थुम्की डाँडा गैरीखर्क सामुदायिक वन उपभोक्ता समूह", "entity_ref": "thumki-cfug"}');

select t.rejects('spending cannot pass what is left of a grant',
  $$select t.mev('expense.recorded', '{"expense_id": "60000000-0000-0000-0000-000000000009", "amount": 120000, "account_code": "EX-MATERIALS", "payee_id": "50000000-0000-0000-0000-000000000001", "method": "bank", "budget_line_id": "40000000-0000-0000-0000-000000000002", "grant_id": "20000000-0000-0000-0000-000000000001", "memo_np": "CNC"}', '{}', '2083/84', '[{"sha256":"c1"}]')$$,
  'only Rs 100000 left');
select t.mev('expense.recorded', '{"expense_id": "60000000-0000-0000-0000-000000000001", "amount": 90000, "account_code": "EX-MATERIALS",
             "payee_id": "50000000-0000-0000-0000-000000000001", "method": "bank", "budget_line_id": "40000000-0000-0000-0000-000000000002",
             "grant_id": "20000000-0000-0000-0000-000000000001", "memo_np": "CNC मेसिन"}', '{}', '2083/84', '[{"sha256":"c2"}]');
select t.as_person(3); select t.mev('payment.approved', '{"expense_id": "60000000-0000-0000-0000-000000000001", "as_role": "treasurer"}');
select t.as_person(1); select t.mev('payment.approved', '{"expense_id": "60000000-0000-0000-0000-000000000001", "as_role": "chair"}');
select t.as_person(3); select t.mev('payment.released', '{"expense_id": "60000000-0000-0000-0000-000000000001"}');
select t.ok('grant money is spent from the restricted fund, not from surplus',
  (select used from public.grant_register) = 90000 and ww.balance('kakani-mpc', 'LI-RESTRICTED') = -10000
  and ww.net_surplus('kakani-mpc', '2083/84') = 60000 - 750);

-- ---------------------------------------------------------------------------
-- Equal pay (s.53)
-- ---------------------------------------------------------------------------
select t.as_person(7);
select t.mev('work.logged', jsonb_build_object('work_id', t.u('70000000', n), 'project', 'खोटो', 'task_np', 'खोटो संकलन', 'hours', h, 'paid', true),
             jsonb_build_object('person_id', t.p(w)), '2083/84', t.wph('resin ' || n), ('2026-10-' || (10 + n))::date)
from (values (1, 9, 6), (2, 9, 5), (3, 2, 6)) v(n, w, h);
select t.as_person(5);
select t.mev('work.approved', jsonb_build_object('work_id', t.u('70000000', n)), '{}', null) from generate_series(1, 3) n;
select t.as_person(7);
select t.rejects('wages in the MPC are paid only against approved work',
  $$select t.mev('expense.recorded', '{"expense_id": "60000000-0000-0000-0000-000000000002", "amount": 1100, "account_code": "EX-WAGES", "payee_id": "50000000-0000-0000-0000-000000000002", "method": "bank", "budget_line_id": "40000000-0000-0000-0000-000000000001", "memo_np": "ज्याला"}', '{}', '2083/84', '[{"sha256":"x"}]')$$,
  'approved work entries');
select t.rejects('wages are exactly the equal rate times the hours',
  $$select t.mev('expense.recorded', '{"expense_id": "60000000-0000-0000-0000-000000000002", "amount": 1500, "account_code": "EX-WAGES", "payee_id": "50000000-0000-0000-0000-000000000002", "method": "bank", "budget_line_id": "40000000-0000-0000-0000-000000000001", "memo_np": "ज्याला", "work_ids": ["70000000-0000-0000-0000-000000000001", "70000000-0000-0000-0000-000000000002"]}')$$,
  'is Rs 1100');
select t.rejects('nobody is paid for someone else''s hours',
  $$select t.mev('expense.recorded', '{"expense_id": "60000000-0000-0000-0000-000000000002", "amount": 600, "account_code": "EX-WAGES", "payee_id": "50000000-0000-0000-0000-000000000002", "method": "bank", "budget_line_id": "40000000-0000-0000-0000-000000000001", "memo_np": "ज्याला", "work_ids": ["70000000-0000-0000-0000-000000000003"]}')$$,
  'someone else');
select t.mev('expense.recorded', '{"expense_id": "60000000-0000-0000-0000-000000000002", "amount": 1100, "account_code": "EX-WAGES",
             "payee_id": "50000000-0000-0000-0000-000000000002", "method": "bank", "budget_line_id": "40000000-0000-0000-0000-000000000001",
             "enterprise_id": "30000000-0000-0000-0000-000000000001", "memo_np": "खोटो संकलन ज्याला: कात्तिक",
             "work_ids": ["70000000-0000-0000-0000-000000000001", "70000000-0000-0000-0000-000000000002"]}');
select t.rejects('hours are paid only once',
  $$select t.mev('expense.recorded', '{"expense_id": "60000000-0000-0000-0000-000000000003", "amount": 600, "account_code": "EX-WAGES", "payee_id": "50000000-0000-0000-0000-000000000002", "method": "bank", "budget_line_id": "40000000-0000-0000-0000-000000000001", "memo_np": "ज्याला", "work_ids": ["70000000-0000-0000-0000-000000000001"]}')$$,
  'already paid');
select t.as_person(3); select t.mev('payment.approved', '{"expense_id": "60000000-0000-0000-0000-000000000002", "as_role": "treasurer"}');
select t.as_person(1); select t.mev('payment.approved', '{"expense_id": "60000000-0000-0000-0000-000000000002", "as_role": "chair"}');
select t.as_person(3); select t.mev('payment.released', '{"expense_id": "60000000-0000-0000-0000-000000000002"}');
select t.ok('enterprise results show earnings per hour',
  (select earnings_per_hour from public.enterprise_results) = round((1100 + 60000 - 1100) / 11.0, 2));

select t.as_person(6);
select t.rejects('paid hours cannot be quietly un-approved',
  $$select t.mev('correction', jsonb_build_object('corrects_seq', (select seq from ww.events where type = 'work.approved' and payload->>'work_id' = '70000000-0000-0000-0000-000000000001'), 'reason_np', 'x'), '{}', null)$$,
  'only treasurer');
select t.as_person(5);
select t.rejects('paid hours cannot be quietly un-approved (by the supervisor either)',
  $$select t.mev('correction', jsonb_build_object('corrects_seq', (select seq from ww.events where type = 'work.approved' and payload->>'work_id' = '70000000-0000-0000-0000-000000000001'), 'reason_np', 'x'), '{}', null)$$,
  'already paid');

-- ---------------------------------------------------------------------------
-- A payment between the bodies lands in both books
-- ---------------------------------------------------------------------------
select t.as_person(7);
select t.rejects('a payment to the CFUG names its income head',
  $$select t.mev('expense.recorded', '{"expense_id": "60000000-0000-0000-0000-000000000004", "amount": 8600, "account_code": "EX-MATERIALS", "payee_id": "50000000-0000-0000-0000-000000000003", "method": "bank", "budget_line_id": "40000000-0000-0000-0000-000000000002", "memo_np": "खोटो खरिद"}', '{}', '2083/84', '[{"sha256":"r"}]')$$,
  'counter_income_code');
select t.mev('expense.recorded', '{"expense_id": "60000000-0000-0000-0000-000000000004", "amount": 8600, "account_code": "EX-MATERIALS",
             "payee_id": "50000000-0000-0000-0000-000000000003", "method": "bank", "budget_line_id": "40000000-0000-0000-0000-000000000002",
             "counter_income_code": "IN-2.06", "enterprise_id": "30000000-0000-0000-0000-000000000001",
             "memo_np": "सामुदायिक वनबाट खोटो खरिद: ७१७ किलो × रु १२"}', '{}', '2083/84', '[{"sha256":"r"}]');
select t.as_person(3); select t.mev('payment.approved', '{"expense_id": "60000000-0000-0000-0000-000000000004", "as_role": "treasurer"}');
select t.as_person(1); select t.mev('payment.approved', '{"expense_id": "60000000-0000-0000-0000-000000000004", "as_role": "chair"}');
select ww.balance('thumki-cfug', 'BS-BANK') as cfug_bank_before \gset
select t.as_person(3); select t.mev('payment.released', '{"expense_id": "60000000-0000-0000-0000-000000000004"}');
select t.ok('the CFUG''s books receive the same payment',
  ww.balance('thumki-cfug', 'BS-BANK') = :cfug_bank_before + 8600
  and exists (select 1 from ww.postings p join ww.events ev on ev.ward_id = p.ward_id and ev.seq = p.event_seq
               where p.entity_id = 'thumki-cfug' and p.account_code = 'IN-2.06' and ev.entity_id = 'kakani-mpc'));
select t.ok('both bodies'' books balance', not exists (
  select 1 from ww.postings group by event_seq, entity_id having sum(debit) <> sum(credit)));

-- ---------------------------------------------------------------------------
-- Year end (s.72–74)
-- ---------------------------------------------------------------------------
select t.as_person(4);
select t.mev('rule.set', '{"key": "active_min_hours", "value": 5, "decision_ref": "परीक्षण: सक्रिय सदस्यको सीमा"}', '{}', null);
select ww.net_surplus('kakani-mpc', '2083/84') as net \gset
select t.ok('net surplus counts sales less wages, materials and interest, not the grant',
  :net = 60000 - 750 - 1100 - 8600);
select t.rejects('the year is closed only with the audit reference',
  $$select t.mev('surplus.allocated', '{"decision_ref": "साधारण सभा"}')$$, 'audit_ref');
select t.mev('surplus.allocated', '{"decision_ref": "वार्षिक साधारण सभा २०८४/०३ निर्णय नं. २", "audit_ref": "लेखापरीक्षण प्रतिवेदन २०८३/८४"}');
select t.ok('the reserve gets 25% and the promotion fund 0.5% of the rest',
  (select reserve from public.surplus_allocations) = round(:net * 0.25, 2)
  and (select promotion from public.surplus_allocations) = round((:net - round(:net * 0.25, 2)) * 0.005, 2));
select t.ok('then 40 / 30 / 30, and every rupee is accounted for',
  (select community from public.surplus_allocations) = round(((select net - reserve - promotion from public.surplus_allocations)) * 0.40, 2)
  and (select reserve + promotion + community + member + capital = net from public.surplus_allocations));
select t.ok('member benefit is shared by recorded work hours',
  (select amount from ww.member_benefits where person_id = t.p(9))
  = floor(round((select net - reserve - promotion from public.surplus_allocations) * 0.30, 2) * 11 / 17));
select t.ok('Tek (11 hours) gets more than Hari (6 hours)',
  (select amount from ww.member_benefits where person_id = t.p(9)) > (select amount from ww.member_benefits where person_id = t.p(2)));
select t.ok('closing leaves the reports intact', (select sum(amount) from public.income_and_spending
  where entity_id = 'kakani-mpc' and account_code = 'IN-SALES') = 60000);
select t.rejects('a year is allocated once',
  $$select t.mev('surplus.allocated', '{"decision_ref": "x", "audit_ref": "y"}')$$, 'already allocated');

select t.as_person(3);
select t.mev('benefit.paid', jsonb_build_object('benefit_year', '2083/84', 'method', 'bank'), jsonb_build_object('person_id', t.p(9)));
select t.rejects('a benefit is paid once',
  $$select t.mev('benefit.paid', '{"benefit_year": "2083/84", "method": "bank"}', '{"person_id": "bbbbbbbb-0000-0000-0000-000000000009"}')$$,
  'already paid');
select t.as_person(1);
select t.rejects('nobody pays their own benefit',
  $$select t.mev('benefit.paid', '{"benefit_year": "2083/84", "method": "bank"}', '{"person_id": "bbbbbbbb-0000-0000-0000-000000000001"}')$$,
  'no member benefit');

-- ---------------------------------------------------------------------------
-- My account (मेरो खाता)
-- ---------------------------------------------------------------------------
select t.as_person(9);   -- Tek: member, one share, project loan on notice, worker
select public.my_account('kakani-mpc') as a \gset
select t.ok('my account shows my shares', (public.my_account('kakani-mpc')->'shares'->>'value')::numeric = 100);
select t.ok('my account shows what the cooperative owes me',
  (public.my_account('kakani-mpc')->>'loans_outstanding')::numeric = 25000
  and (public.my_account('kakani-mpc')->>'my_money')::numeric = 100 + 25000);
select t.ok('my statement lists shares, wages, loan and benefit', (
  select array_agg(distinct s->>'kind' order by s->>'kind') from jsonb_array_elements(public.my_account('kakani-mpc')->'statement') s)
  = array['benefit', 'loan_given', 'loan_notice', 'loan_repaid', 'shares_bought', 'wages']);
select t.ok('my account never shows other members', position('Hari' in public.my_account('kakani-mpc')::text) = 0
  and position('Mina' in public.my_account('kakani-mpc')::text) = 0);
select t.as_person(2);
select t.ok('wages due show approved hours not yet paid', (public.my_account('kakani-mpc')->'work'->>'wages_due')::numeric = 600);
select t.rejects('a member cannot read the share register', $$select * from public.officer_share_register('kakani-mpc')$$, 'this view is for');
select t.as_person(6);
select t.ok('the accounts committee sees the share register', (select count(*) from public.officer_share_register('kakani-mpc')) = 9);

-- corrections recompute holdings
select t.as_person(3);
select t.mev('correction', jsonb_build_object('corrects_seq',
  (select seq from ww.events where type = 'shares.purchased' and payload->>'receipt_no' = 'श-3'), 'reason_np', 'दोहोरो प्रविष्टि'), '{}', '2083/84');
select t.ok('a corrected share purchase no longer counts', ww.shares_held('kakani-mpc', t.p(3)) = 0);

-- public circle
select t.as_server();
set role anon;
select t.ok('the public sees the cooperative in totals', (select members from public.mpc_summary) = 9
  and (select share_capital from public.mpc_summary) = 800);
select t.rejects('the public cannot open a member''s account', $$select public.my_account('kakani-mpc')$$, 'permission denied');
reset role;
select t.ok('the whole ward chain verifies', (select ok from ww.verify_chain('kakani-3')));
