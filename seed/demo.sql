-- Chautari — demo data: three months of a CFUG's life, with fictional people.
-- For showing and testing screens only. Never load this into the real database.
-- Load after the migrations into an empty database: psql -f seed/demo.sql

create schema demo;
create function demo.hh(n int) returns uuid language sql immutable as $$
  select ('aaaaaaaa-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid $$;
create function demo.p(n int) returns uuid language sql immutable as $$
  select ('bbbbbbbb-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid $$;
create function demo.id(prefix text, n int) returns uuid language sql immutable as $$
  select (prefix || '-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid $$;
create function demo.as_person(n int) returns void language sql as $$
  select set_config('request.jwt.claim.sub', case when n = 0 then '' else 'cccccccc-0000-0000-0000-' || lpad(n::text, 12, '0') end, false)
$$;
create function demo.ev(p_type text, p_on date, p_payload jsonb, p_private jsonb default '{}',
                        p_evidence jsonb default '[]', p_fy text default '2083/84')
returns jsonb language sql as $$
  select public.record_event('thumki-cfug', p_type, p_payload, p_private, p_on, p_fy, p_evidence)
$$;
-- a before and an after photo of a piece of work (stand-ins: the hash of a tag, there is no real photo)
create function demo.work_photos(tag text) returns jsonb language sql immutable as $$
  select jsonb_build_array(
    jsonb_build_object('sha256', encode(sha256(convert_to(tag || ' before', 'UTF8')), 'hex'), 'kind', 'before'),
    jsonb_build_object('sha256', encode(sha256(convert_to(tag || ' after', 'UTF8')), 'hex'), 'kind', 'after'))
$$;

create function demo.photo(tag text) returns jsonb language sql immutable as $$
  select jsonb_build_array(jsonb_build_object('sha256', encode(sha256(convert_to(tag, 'UTF8')), 'hex'), 'kind', 'photo'))
$$;

insert into ww.wards values ('kakani-3', 'ककनी गाउँपालिका वडा नं. ३ (चाउथे)', 'Kakani-3 (Chauthe)');
insert into ww.entities (id, ward_id, kind, name_np, name_en, source_doc) values
 ('thumki-cfug', 'kakani-3', 'cfug', 'थुम्की डाँडा गैरीखर्क सामुदायिक वन उपभोक्ता समूह',
  'Thumki Danda Gairikharka CFUG', 'विधान २०८२; कार्ययोजना २०८१/८२–२०९०/९१');

-- households and people (server job)
select demo.as_person(0);
select demo.ev('household.registered', '2026-07-20', jsonb_build_object('household_id', demo.hh(n), 'house_no', n), '{}', '[]', null)
  from generate_series(1, 12) n;
select demo.ev('person.registered', '2026-07-20', '{}', jsonb_build_object('person_id', demo.p(n), 'display_name', name,
            'gender', g, 'household_id', demo.hh(h)), '[]', null)
from (values (1,'सीता','f',1),(2,'हरि','m',2),(3,'राम','m',3),(4,'गीता','f',4),(5,'विकास','m',5),
             (6,'कमला','f',6),(7,'दिल','m',7),(8,'मीना','f',8),(9,'टेक','m',9),(10,'सरिता','f',10),
             (11,'पासाङ','m',11),(12,'लक्ष्मी','f',12)) v(n, name, g, h);
update ww.persons set auth_user_id = ('cccccccc-0000-0000-0000-' || lpad(substr(id::text, 25)::int::text, 12, '0'))::uuid;

select demo.ev('role.assigned', '2026-07-20', jsonb_build_object('person_id', demo.p(1), 'role', 'secretary', 'decision_ref', 'साधारण सभा निर्णय नं. १'), '{}', '[]', null);
select demo.as_person(1);
select demo.ev('role.assigned', '2026-07-20', jsonb_build_object('person_id', demo.p(n), 'role', r, 'decision_ref', 'साधारण सभा निर्णय नं. १'), '{}', '[]', null)
from (values (2,'treasurer'),(3,'chair'),(4,'ledger_keeper'),(5,'supervisor'),(6,'accounts_committee'),(10,'nature_guardian')) v(n, r);

-- the assembly's budget for 2083/84 (secretary records it)
select demo.ev('budget.approved', '2026-07-25', jsonb_build_object('line_id', demo.id('dddddddd', n), 'account_code', code,
            'amount', amt, 'title_np', title, 'decision_ref', 'साधारण सभा २०८३/०४/०९ निर्णय नं. ' || n))
from (values (1,'EX-2.02',60000,'नर्सरी सञ्चालन र बिरुवा'),
             (2,'EX-2.01',45000,'पोखरी र खाल्डो मर्मत, वन हेरालु'),
             (3,'EX-4.00',50000,'विपन्न घरधुरी: बाख्रा र मौरी'),
             (4,'EX-1.02',8000,'बैठक र साधारण सभा'),
             (5,'EX-1.08',6000,'लेखा परीक्षण शुल्क')) v(n, code, amt, title);

-- opening balances, income, banking (treasurer and ledger keeper)
select demo.as_person(2);
select demo.ev('balance.opened', '2026-07-20', '{"cash": 3200, "bank": 84500}');
select demo.as_person(4);
select demo.ev('payee.registered', '2026-07-21', jsonb_build_object('payee_id', demo.id('eeeeeeee', n), 'kind', k, 'name', nm))
from (values (1,'shop','ककनी कृषि तथा बिउ पसल'),(2,'contractor','नुवाकोट ढुङ्गा तथा बालुवा आपूर्ति'),
             (3,'organisation','लेखा परीक्षक कार्यालय, बिदुर'),(4,'shop','चाउथे किराना पसल')) v(n, k, nm);
select demo.ev('payee.registered', '2026-07-21', jsonb_build_object('payee_id', demo.id('eeeeeeee', 10 + n), 'kind', 'person'),
            jsonb_build_object('person_id', demo.p(n)))
from (values (7),(8),(9),(11),(12)) v(n);

-- expenses, signatures and payments
create function demo.pay(n int, d date, line int, code text, payee int, amt numeric, m text, memo text,
                         s2 int, s2role text, released boolean default true, est boolean default false)
returns void language plpgsql as $$
begin
  perform demo.as_person(4);
  perform demo.ev('expense.recorded', d, jsonb_build_object('expense_id', demo.id('ffffffff', n), 'amount', amt,
            'account_code', code, 'payee_id', demo.id('eeeeeeee', payee), 'method', m,
            'budget_line_id', case when line > 0 then demo.id('dddddddd', line) end, 'estimated', est, 'memo_np', memo),
            '{}', case when est then '[]'::jsonb else demo.photo('receipt-' || n) end);
  perform demo.as_person(2);
  perform demo.ev('payment.approved', d, jsonb_build_object('expense_id', demo.id('ffffffff', n), 'as_role', 'treasurer'));
  if s2 > 0 then
    perform demo.as_person(s2);
    perform demo.ev('payment.approved', d + 1, jsonb_build_object('expense_id', demo.id('ffffffff', n), 'as_role', s2role));
  end if;
  if released then
    perform demo.as_person(2);
    perform demo.ev('payment.released', d + 1, jsonb_build_object('expense_id', demo.id('ffffffff', n)));
  end if;
end $$;

create function demo.income(d date, amt numeric, code text, m text, rn text, memo text) returns void language sql as $$
  select demo.as_person(4);
  select demo.ev('income.recorded', d, jsonb_build_object('amount', amt, 'account_code', code, 'method', m,
            'receipt_no', rn, 'memo_np', memo));
$$;
create function demo.bank(d date, amt numeric, ref text) returns void language sql as $$
  select demo.as_person(4);
  select demo.ev('cash.banked', d, jsonb_build_object('amount', amt, 'bank_ref', ref));
$$;

-- the money, in the order it happened
select demo.income('2026-08-03', 4500, 'IN-2.03', 'cash', '२०१', 'दाउरा बिक्री (९ भारी)');
select demo.pay(1, '2026-08-05', 4, 'EX-1.02', 4, 1800, 'cash', 'साउन मासिक बैठक: चिया र खाजा', 1, 'secretary');
select demo.income('2026-08-10', 2400, 'IN-5.03', 'cash', '२०२', 'वार्षिक नवीकरण शुल्क (१२० घरधुरी × २०)');
select demo.bank('2026-08-12', 7000, 'जम्मा भौचर ११४');
select demo.income('2026-08-28', 150000, 'IN-3.03', 'bank', '२०३', 'ZenTrust: जलाधार र नर्सरी अनुदान');
select demo.pay(2, '2026-08-30', 1, 'EX-2.02', 1, 32000, 'bank', 'नर्सरीका लागि थैली, मल र बिउ', 1, 'secretary');
select demo.pay(3, '2026-09-08', 2, 'EX-2.01', 2, 24000, 'bank', 'पोखरी ४ को किनारमा ढुङ्गा', 1, 'secretary');
select demo.income('2026-09-15', 8600, 'IN-2.06', 'cash', '२०४', 'खोटो बिक्री (७१७ किलो × रु १२)');
select demo.bank('2026-09-19', 7000, 'जम्मा भौचर १७२');
-- treasurer and chair (both men) sign; the release waits for a woman signer, then the secretary signs
select demo.pay(4, '2026-09-25', 2, 'EX-2.01', 17, 7200, 'bank', 'पोखरी ४ मर्मत: १२ घण्टा × रु १०० × ६', 3, 'chair', false);
select demo.as_person(1);
select demo.ev('payment.approved', '2026-09-27', jsonb_build_object('expense_id', demo.id('ffffffff', 4), 'as_role', 'secretary'));
select demo.as_person(2);
select demo.ev('payment.released', '2026-09-27', jsonb_build_object('expense_id', demo.id('ffffffff', 4)));
select demo.income('2026-10-02', 35000, 'IN-3.01', 'bank', '२०५', 'ककनी गाउँपालिका: वृक्षरोपण अनुदान');
select demo.pay(5, '2026-10-06', 3, 'EX-4.00', 1, 20000, 'bank', 'विपन्न घरधुरीलाई मौरीघार (४ थान)', 1, 'secretary');
select demo.income('2026-10-20', 3000, 'IN-2.05', 'cash', '२०६', 'घाँस र स्याउला बिक्री');
select demo.pay(6, '2026-10-21', 1, 'EX-2.02', 18, 2400, 'cash', 'नर्सरी नाइके ज्याला: असोज', 1, 'secretary');
select demo.bank('2026-10-24', 2000, 'जम्मा भौचर २०९');
select demo.pay(7, '2026-11-02', 2, 'EX-2.01', 2, 9500, 'bank', 'चेक ड्याम: ढुङ्गा र ढुवानी', 0, '', false);

-- work on pond 4 and the nursery (ledger keeper logs, supervisor approves)
select demo.as_person(4);
select demo.ev('work.logged', d, jsonb_build_object('work_id', demo.id('abababab', n), 'project', proj, 'task_np', task,
            'hours', h, 'paid', paid, 'output_qty', q, 'output_unit', u),
            jsonb_build_object('person_id', demo.p(w)), demo.work_photos('work-' || n))
from (values (1,'2026-09-20'::date,'पोखरी ४','किनार बलियो पार्ने',6,true,8,'मिटर',7),
             (2,'2026-09-20','पोखरी ४','किनार बलियो पार्ने',6,true,8,'मिटर',8),
             (3,'2026-09-21','पोखरी ४','ढुङ्गा मिलाउने',6,true,10,'मिटर',9),
             (4,'2026-09-21','पोखरी ४','ढुङ्गा मिलाउने',6,true,10,'मिटर',11),
             (5,'2026-09-22','पोखरी ४','ओभरफ्लो नाली',6,true,6,'मिटर',12),
             (6,'2026-09-22','पोखरी ४','ओभरफ्लो नाली',6,true,6,'मिटर',3),
             (7,'2026-10-10','नर्सरी','बिरुवा थैलीमा सार्ने',5,false,400,'थैली',8),
             (8,'2026-10-10','नर्सरी','बिरुवा थैलीमा सार्ने',5,false,380,'थैली',10),
             (9,'2026-10-11','नर्सरी','बिरुवा थैलीमा सार्ने',4,false,300,'थैली',12),
             (10,'2026-11-03','चेक ड्याम','ढुङ्गा ओसार्ने',6,true,2,'ड्याम',7)) v(n, d, proj, task, h, paid, q, u, w);
select demo.as_person(5);
select demo.ev('work.approved', d, jsonb_build_object('work_id', demo.id('abababab', n)))
from (values (1,'2026-09-23'::date),(2,'2026-09-23'),(3,'2026-09-23'),(4,'2026-09-23'),(6,'2026-09-23'),
             (7,'2026-10-12'),(8,'2026-10-12'),(9,'2026-10-12')) v(n, d);
-- entry 10 (a check dam, this week) stays waiting for approval
select demo.ev('work.approved', '2026-09-23', jsonb_build_object('work_id', demo.id('abababab', 5)));

-- fair turns: paid work offered by rota
select demo.as_person(4);
select demo.ev('rota.offered', '2026-09-18', jsonb_build_object('offer_id', demo.id('acacacac', n), 'project', 'पोखरी ४',
            'task_np', 'पोखरी मर्मत', 'hours', 12, 'accepted', acc), jsonb_build_object('household_id', demo.hh(h)))
from (values (1,7,true),(2,8,true),(3,9,true),(4,10,false),(5,11,true),(6,12,true),(7,3,true),(8,1,false)) v(n, h, acc);

-- parma between households
select demo.ev('parma.exchanged', d, jsonb_build_object('days', days, 'task_np', task),
            jsonb_build_object('helper_household_id', demo.hh(a), 'helped_household_id', demo.hh(b)), '[]', null)
from (values ('2026-07-28'::date, 9, 3, 2, 'धान रोपाइँ'), ('2026-07-30', 3, 9, 2, 'धान रोपाइँ'),
             ('2026-10-30', 9, 11, 1.5, 'धान काट्ने')) v(d, a, b, days, task);

-- nature's account: springs every two weeks, rain
select demo.as_person(10);
select demo.ev('reading.spring', d, jsonb_build_object('spring_id', s, 'litres_per_minute', lpm, 'method', 'बाल्टी र घडी'), '{}', demo.photo('spring-' || s || d), null)
from (values ('2026-08-01'::date,'कालो धारा',6.2),('2026-08-15','कालो धारा',7.0),('2026-09-01','कालो धारा',6.8),
             ('2026-09-15','कालो धारा',6.1),('2026-10-01','कालो धारा',5.4),('2026-10-15','कालो धारा',4.9),
             ('2026-11-01','कालो धारा',4.6),
             ('2026-08-01','गैरीखर्क मूल',2.1),('2026-08-15','गैरीखर्क मूल',2.6),('2026-09-01','गैरीखर्क मूल',2.5),
             ('2026-09-15','गैरीखर्क मूल',2.3),('2026-10-01','गैरीखर्क मूल',2.2),('2026-10-15','गैरीखर्क मूल',2.1),
             ('2026-11-01','गैरीखर्क मूल',2.1)) v(d, s, lpm);
select demo.ev('reading.rain', d, jsonb_build_object('gauge_id', 'पोखरी ४ नजिक', 'mm', mm), '{}', '[]', null)
from (values ('2026-08-31'::date, 412),('2026-09-30', 238),('2026-10-31', 46)) v(d, mm);

-- a question answered, and one still open
select demo.as_person(9);
select demo.ev('question.raised', '2026-09-02', jsonb_build_object('question_id', demo.id('12121212', 1),
            'about_seq', (select seq from ww.events where type = 'payment.released' and payload->>'expense_id' = demo.id('ffffffff', 2)::text)),
            '{"text_np": "नर्सरीको थैली र मल किन ३२ हजार?"}', '[]', null);
select demo.as_person(12);
select demo.ev('question.raised', '2026-11-04', jsonb_build_object('question_id', demo.id('12121212', 2),
            'about_seq', (select seq from ww.events where type = 'expense.recorded' and payload->>'expense_id' = demo.id('ffffffff', 7)::text)),
            '{"text_np": "चेक ड्यामको ढुङ्गा कुन ठेकेदारबाट?"}', '[]', null);
select demo.as_person(6);
select demo.ev('question.closed', '2026-09-06', '{"question_id": "12121212-0000-0000-0000-000000000001", "outcome": "explained",
            "answer_np": "५,००० थैली, ४० बोरा कम्पोस्ट र बिउ: बिल लेखा समितिसँग हेर्न सकिन्छ।"}', '{}', '[]', null);

-- a lost receipt: one small estimated expense within the 5% cap (counted against 90 days of spending)
select demo.pay(8, '2026-11-04', 4, 'EX-1.02', 4, 900, 'cash', 'कात्तिक बैठक चिया (बिल हराएको: मूल्य सूचीअनुसार)', 1, 'secretary', true, true);

select demo.as_person(0);

-- ===========================================================================
-- The cooperative (sample: shown as if registered; in reality it is not yet)
-- ===========================================================================
insert into ww.entities (id, ward_id, kind, name_np, name_en, source_doc) values
 ('kakani-mpc', 'kakani-3', 'mpc', 'ककनी बहुउद्देश्यीय सहकारी संस्था लिमिटेड', 'Kakani Multipurpose Cooperative Ltd.',
  'Draft MPC bylaws v4 (Kartik 2083)');
create function demo.mev(p_type text, p_on date, p_payload jsonb, p_private jsonb default '{}',
                         p_evidence jsonb default '[]', p_fy text default '2083/84')
returns jsonb language sql as $$
  select public.record_event('kakani-mpc', p_type, p_payload, p_private, p_on, p_fy, p_evidence)
$$;
create function demo.mpay(n int, d date, line int, code text, payee int, amt numeric, memo text,
                          extra jsonb default '{}', evidence jsonb default null)
returns void language plpgsql as $$
begin
  perform demo.as_person(8);   -- MPC ledger keeper
  perform demo.mev('expense.recorded', d, jsonb_build_object('expense_id', demo.id('fafafafa', n), 'amount', amt,
            'account_code', code, 'payee_id', demo.id('ebebebeb', payee), 'method', 'bank',
            'budget_line_id', demo.id('dcdcdcdc', line), 'memo_np', memo) || extra,
            '{}', coalesce(evidence, demo.photo('mpc-receipt-' || n)));
  perform demo.as_person(11);  -- treasurer
  perform demo.mev('payment.approved', d, jsonb_build_object('expense_id', demo.id('fafafafa', n), 'as_role', 'treasurer'));
  perform demo.as_person(12);  -- chair, a woman
  perform demo.mev('payment.approved', d + 1, jsonb_build_object('expense_id', demo.id('fafafafa', n), 'as_role', 'chair'));
  perform demo.as_person(11);
  perform demo.mev('payment.released', d + 1, jsonb_build_object('expense_id', demo.id('fafafafa', n)));
end $$;

select demo.as_person(0);
select demo.mev('role.assigned', '2026-07-25', jsonb_build_object('person_id', demo.p(10), 'role', 'secretary', 'decision_ref', 'प्रारम्भिक साधारण सभा निर्णय नं. १'), '{}', '[]', null);
select demo.as_person(10);
select demo.mev('role.assigned', '2026-07-25', jsonb_build_object('person_id', demo.p(n), 'role', r, 'decision_ref', 'प्रारम्भिक साधारण सभा निर्णय नं. १'), '{}', '[]', null)
from (values (12,'chair'),(11,'treasurer'),(8,'ledger_keeper'),(3,'supervisor'),(6,'accounts_committee')) v(n, r);
select demo.mev('member.admitted', '2026-07-26', jsonb_build_object('member_no', n, 'decision_ref', 'सञ्चालक समिति निर्णय नं. २'),
                jsonb_build_object('person_id', demo.p(n), 'self_declaration', true), '[]', null)
from generate_series(1, 12) n;
select demo.mev('enterprise.approved', '2026-07-28', '{"enterprise_id": "cdcdcdcd-0000-0000-0000-000000000001", "name_np": "खोटो संकलन र बिक्री",
                "plan_ref": "साधारण सभा २०८३/०४/१२ निर्णय नं. ३ (पहिलो उद्यम योजना)"}', '{}', '[]', null);
select demo.mev('budget.approved', '2026-07-28', jsonb_build_object('line_id', demo.id('dcdcdcdc', n), 'account_code', code,
                'amount', amt, 'title_np', title, 'decision_ref', 'साधारण सभा २०८३/०४/१२ निर्णय नं. ४'))
from (values (1,'EX-WAGES',100000,'खोटो संकलन ज्याला (समान दर)'),(2,'EX-MATERIALS',180000,'मेसिन र कच्चा पदार्थ'),
             (3,'EX-OPS',20000,'ढुवानी र सञ्चालन')) v(n, code, amt, title);

select demo.as_person(8);
-- every member holds exactly one share of Rs 100 (bylaws v4.15 s.7)
select demo.mev('shares.purchased', '2026-07-30', jsonb_build_object('kitta', 1, 'amount', 100, 'method', 'cash', 'receipt_no', 'श-' || n),
                jsonb_build_object('person_id', demo.p(n)))
from generate_series(1, 12) n;
select demo.mev('cash.banked', '2026-07-31', '{"amount": 1200, "bank_ref": "सहकारी जम्मा भौचर १"}');
select demo.mev('payee.registered', '2026-07-31', jsonb_build_object('payee_id', demo.id('ebebebeb', n), 'kind', k, 'name', nm) || x)
from (values (1,'shop','बिदुर मेसिनरी सप्लायर्स','{}'::jsonb),
             (2,'organisation','थुम्की डाँडा गैरीखर्क सामुदायिक वन उपभोक्ता समूह','{"entity_ref": "thumki-cfug"}'),
             (3,'contractor','काठमाडौं खोटो प्रशोधन उद्योग','{}')) v(n, k, nm, x);
select demo.mev('payee.registered', '2026-07-31', jsonb_build_object('payee_id', demo.id('ebebebeb', 10 + n), 'kind', 'person'),
                jsonb_build_object('person_id', demo.p(n)))
from (values (7),(9),(10),(12),(5)) v(n);

select demo.as_person(11);
select demo.mev('loan.received', '2026-08-01', '{"loan_id": "babababa-0000-0000-0000-000000000001", "lender_kind": "organisation",
                "lender_name": "ZenTrust", "amount": 300000, "rate_pct": 4, "term_months": 60,
                "decision_ref": "साधारण सभा निर्णय नं. ५ (ऋण सम्झौता)", "method": "bank"}');
-- members' project loans (bylaws v4.15 s.8): one rate for all, now 10% a year
-- up to Rs 1 lakh: withdrawable with interest on 3 months' notice
select demo.mev('loan.received', '2026-08-01', '{"loan_id": "babababa-0000-0000-0000-000000000002", "lender_kind": "member",
                "amount": 50000, "rate_pct": 10, "decision_ref": "साधारण सभा २०८३/०४/१२ निर्णय नं. ६ (परियोजना ऋण सम्झौता)", "method": "bank"}',
                jsonb_build_object('person_id', demo.p(9)));
-- above Rs 1 lakh: a fixed term of 3 to 5 years
select demo.mev('loan.received', '2026-08-15', '{"loan_id": "babababa-0000-0000-0000-000000000003", "lender_kind": "member",
                "amount": 200000, "rate_pct": 10, "term_months": 48, "decision_ref": "साधारण सभा २०८३/०४/१२ निर्णय नं. ६ (परियोजना ऋण सम्झौता)", "method": "bank"}',
                jsonb_build_object('person_id', demo.p(4)));
-- a member who has not given notice yet, so the "give notice" button can be tried in the demo
select demo.mev('loan.received', '2026-09-01', '{"loan_id": "babababa-0000-0000-0000-000000000004", "lender_kind": "member",
                "amount": 30000, "rate_pct": 10, "decision_ref": "साधारण सभा २०८३/०४/१२ निर्णय नं. ६ (परियोजना ऋण सम्झौता)", "method": "bank"}',
                jsonb_build_object('person_id', demo.p(7)));
select demo.mev('grant.received', '2026-08-20', '{"grant_id": "bcbcbcbc-0000-0000-0000-000000000001", "donor": "ZenTrust",
                "purpose_np": "CNC मेसिन र युवा तालिम", "amount": 150000, "agreement_ref": "अनुदान सम्झौता ZT-2083-02"}');

-- the CNC machine, paid from the restricted grant
select demo.mpay(1, '2026-09-02', 2, 'EX-MATERIALS', 1, 120000, 'CNC राउटर मेसिन (अनुदानबाट)', '{"grant_id": "bcbcbcbc-0000-0000-0000-000000000001"}');

-- resin tapping work (supervisor approves)
select demo.as_person(8);
select demo.mev('work.logged', d, jsonb_build_object('work_id', demo.id('a1a1a1a1', n), 'project', 'खोटो संकलन', 'task_np', task,
                'hours', h, 'paid', true, 'output_qty', q, 'output_unit', 'किलो'),
                jsonb_build_object('person_id', demo.p(w)), demo.work_photos('resin-' || n))
from (values (1,'2026-10-05'::date,9,6,'रिल बनाउने',0),(2,'2026-10-06',9,6,'खोटो संकलन',60),(3,'2026-10-07',9,6,'खोटो संकलन',58),
             (4,'2026-10-08',9,6,'खोटो संकलन',62),(5,'2026-10-05',7,6,'रिल बनाउने',0),(6,'2026-10-06',7,6,'खोटो संकलन',55),
             (7,'2026-10-07',7,6,'खोटो संकलन',57),(8,'2026-10-08',7,6,'खोटो संकलन',60),(9,'2026-10-09',7,6,'खोटो संकलन',59),
             (10,'2026-10-06',10,6,'खोटो संकलन',50),(11,'2026-10-07',10,6,'खोटो संकलन',52),(12,'2026-10-06',12,5,'खोटो संकलन',48),
             (13,'2026-10-07',12,5,'खोटो संकलन',45),(14,'2026-10-08',5,6,'ढुवानी',0),(15,'2026-11-03',9,6,'खोटो संकलन',61)) v(n, d, w, h, task, q);
select demo.as_person(3);
select demo.mev('work.approved', d, jsonb_build_object('work_id', demo.id('a1a1a1a1', n)))
from (select n, '2026-10-10'::date as d from generate_series(1, 14) n) v;

-- wages at the equal rate (Rs 100/hour), only against approved hours
select demo.mpay(2, '2026-10-12', 1, 'EX-WAGES', 19, 2400, 'खोटो संकलन ज्याला: असोज (२४ घण्टा)',
  jsonb_build_object('enterprise_id', 'cdcdcdcd-0000-0000-0000-000000000001', 'work_ids',
    jsonb_build_array(demo.id('a1a1a1a1', 1), demo.id('a1a1a1a1', 2), demo.id('a1a1a1a1', 3), demo.id('a1a1a1a1', 4))), '[]');
select demo.mpay(3, '2026-10-12', 1, 'EX-WAGES', 17, 3000, 'खोटो संकलन ज्याला: असोज (३० घण्टा)',
  jsonb_build_object('enterprise_id', 'cdcdcdcd-0000-0000-0000-000000000001', 'work_ids',
    jsonb_build_array(demo.id('a1a1a1a1', 5), demo.id('a1a1a1a1', 6), demo.id('a1a1a1a1', 7), demo.id('a1a1a1a1', 8), demo.id('a1a1a1a1', 9))), '[]');
select demo.mpay(4, '2026-10-12', 1, 'EX-WAGES', 20, 1200, 'खोटो संकलन ज्याला: असोज (१२ घण्टा)',
  jsonb_build_object('enterprise_id', 'cdcdcdcd-0000-0000-0000-000000000001', 'work_ids',
    jsonb_build_array(demo.id('a1a1a1a1', 10), demo.id('a1a1a1a1', 11))), '[]');

-- buying the CFUG's resin: one payment, recorded in both bodies' books
select demo.mpay(5, '2026-10-14', 2, 'EX-MATERIALS', 2, 14400, 'सामुदायिक वनबाट खोटो खरिद: १,२०० किलो × रु १२',
  '{"counter_income_code": "IN-2.06", "enterprise_id": "cdcdcdcd-0000-0000-0000-000000000001"}');
select demo.mpay(6, '2026-10-20', 3, 'EX-OPS', 3, 6000, 'खोटो ढुवानी: चाउथे–काठमाडौं',
  '{"enterprise_id": "cdcdcdcd-0000-0000-0000-000000000001"}');

-- selling processed resin
select demo.as_person(8);
select demo.mev('income.recorded', '2026-10-28', '{"amount": 45000, "account_code": "IN-SALES", "method": "bank", "receipt_no": "स-१",
                "memo_np": "खोटो बिक्री: १,८०० किलो × रु २५", "enterprise_id": "cdcdcdcd-0000-0000-0000-000000000001"}');

-- Tek gives 3 months' notice in चौतारी to take back Rs 20,000 of his project loan
select demo.as_person(9);
select demo.mev('loan.notice_given', '2026-11-10', '{"loan_id": "babababa-0000-0000-0000-000000000002", "amount": 20000}', '{}', '[]', null);

-- the village price list (SAMPLE prices, not real): the chair records the committee's decision
select demo.as_person(3);
select demo.ev('price.set', '2026-10-15', jsonb_build_object('item_np', i, 'unit', u, 'price', p, 'decision_ref', 'नमुना: कार्यसमिति निर्णय नं. ३'), '{}', '[]', null)
from (values ('JCB भाडा', 'घण्टा', 2600), ('Petrol', 'लिटर', 175), ('सिमेन्ट', 'बोरा', 850),
             ('टिमुर बिरुवा', 'गोटा', 25), ('ढुङ्गा', 'ट्याक्टर', 3500)) v(i, u, p);

select demo.as_person(0);
