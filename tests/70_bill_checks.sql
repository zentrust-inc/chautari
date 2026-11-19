-- Chautari — checks on a bill before anyone confirms it. (SAMPLE data, fictional shops and people.)
-- Runs after 40_reader: person 3 chair, 4 ledger keeper, 6 accounts committee, 9 a member;
-- payee eeee…01 (ककनी कृषि पसल), budget line dddd…01 (EX-2.02); suggestion "a" (Rs 7900) is confirmed.

create function t.sug2(p_tag text, p_amount numeric, p_bill text, p_dhash text, p_items jsonb default '[]') returns uuid language sql as $$
  select public.record_suggestion('thumki-cfug', encode(sha256(convert_to(p_tag, 'UTF8')), 'hex'), 'bill',
    'documents/thumki-cfug/' || encode(sha256(convert_to(p_tag, 'UTF8')), 'hex') || '.jpg', 'chautari-reader/0.1.0 (test)',
    jsonb_build_object('type', 'expense.recorded', 'occurred_on', '2026-10-28', 'fiscal_year', '2083/84', 'dhash', p_dhash,
      'items', p_items, 'flags', '[]'::jsonb,
      'payload', jsonb_build_object('amount', p_amount, 'account_code', 'EX-2.02', 'method', 'cash', 'memo_np', 'बिरुवा',
        'payee_id', 'eeeeeeee-0000-0000-0000-000000000001', 'budget_line_id', 'dddddddd-0000-0000-0000-000000000001', 'bill_no', p_bill)))
$$;
create function t.pay2(p_amount numeric, p_bill text, p_expense text, p_extra jsonb default '{}') returns jsonb language sql as $$
  select jsonb_build_object('expense_id', p_expense, 'amount', p_amount, 'account_code', 'EX-2.02', 'method', 'cash',
    'memo_np', 'बिरुवा', 'payee_id', 'eeeeeeee-0000-0000-0000-000000000001',
    'budget_line_id', 'dddddddd-0000-0000-0000-000000000001', 'bill_no', p_bill) || p_extra
$$;
create function t.codes(j jsonb) returns text[] language sql immutable as $$
  select coalesce(array_agg(x->>'code' order by x->>'code'), '{}') from jsonb_array_elements(j) x
$$;
grant execute on all functions in schema t to authenticated;

-- the village price list, set by the committee with its decision
set role authenticated;
select t.as_person(9);
select t.rejects('a member cannot set a price', $$select t.ev('price.set', '{"item_np": "टिमुर बिरुवा", "unit": "गोटा", "price": 20, "decision_ref": "x"}')$$, 'only');
select t.as_person(3);
select t.rejects('a price needs its decision', $$select t.ev('price.set', '{"item_np": "टिमुर बिरुवा", "unit": "गोटा", "price": 20}')$$, 'decision_ref');
select t.ev('price.set', '{"item_np": "टिमुर बिरुवा", "unit": "गोटा", "price": 20, "decision_ref": "कार्यसमिति निर्णय नं. ७"}');
select t.ev('price.set', '{"item_np": "टिमुर बिरुवा", "unit": "गोटा", "price": 25, "decision_ref": "कार्यसमिति निर्णय नं. ८"}');
set role anon;
select t.ok('the price list is public, and the newest decision wins',
  (select price from public.price_list where item_np = 'टिमुर बिरुवा') = 25);
reset role;

-- three new bills from the reader (our server)
select t.as_server();
create table t.b as select
  t.sug2('bill p', 3000, '१२३', 'f0f0f0f0f0f0f0f0', '[{"name": "टिमुर बिरुवा", "qty": 100, "rate": 30, "amount": 3000}]') as p,  -- 20% over: fine
  t.sug2('bill q', 4000, '124',  '0f0f0f0f0f0f0f0f', '[{"name": "टिमुर बिरुवा", "qty": 100, "rate": 40, "amount": 4000}]') as q,  -- 60% over
  t.sug2('bill r', 3000, '123',  'f0f0f0f0f0f0f0f1') as r,    -- another photo of bill p (one bit differs), same number in Latin digits
  t.sug2('bill p', 3000, '१२३', 'f0f0f0f0f0f0f0f0') as p2;    -- the very same photo handed in twice
grant select on t.b to authenticated;

set role authenticated;
select t.as_person(4);
select t.ok('waiting bills come with their checks',
  t.codes((select checks from public.officer_suggestions('thumki-cfug') where suggestion_id = (select q from t.b))) = '{over_price}');
select t.ok('a rate within the allowed margin raises nothing about price',
  not ('over_price' = any (t.codes((select checks from public.officer_suggestions('thumki-cfug') where suggestion_id = (select p from t.b))))));
select t.ok('the same photo handed in twice is flagged',
  'same_photo_twice' = any (t.codes((select checks from public.officer_suggestions('thumki-cfug') where suggestion_id = (select p2 from t.b)))));
select t.ok('a near-identical photo is flagged',
  'near_photo' = any (t.codes((select checks from public.officer_suggestions('thumki-cfug') where suggestion_id = (select r from t.b)))));

-- confirm bill p
create temp table cp as select public.confirm_suggestion((select p from t.b), 'expense.recorded',
  t.pay2(3000, '१२३', 'ffffffff-0000-0000-0000-00000000b001'), '2026-10-28', '2083/84') as r;
select t.rejects('the same photo cannot become a second entry',
  $$select public.confirm_suggestion((select p2 from t.b), 'expense.recorded', t.pay2(3000, '१२३', 'ffffffff-0000-0000-0000-00000000b002'), '2026-10-28', '2083/84')$$,
  'already the evidence');
select t.rejects('the same shop''s bill number cannot be recorded twice (१२३ = 123)',
  $$select public.confirm_suggestion((select r from t.b), 'expense.recorded', t.pay2(3000, '123', 'ffffffff-0000-0000-0000-00000000b003'), '2026-10-29', '2083/84')$$,
  'already recorded');
select t.ok('the app can see this before pressing confirm',
  'same_bill' = any (t.codes(public.check_bill((select r from t.b), t.pay2(3000, '123 ', 'x'), '2026-10-29'))));

-- bill q is above the price list: it can still be confirmed; the check is kept and shown
create temp table cq as select public.confirm_suggestion((select q from t.b), 'expense.recorded',
  t.pay2(4000, '124', 'ffffffff-0000-0000-0000-00000000b004'), '2026-10-28', '2083/84') as r;
reset role;
select t.ok('a flag does not stop the entry', exists (select 1 from ww.expenses where id = 'ffffffff-0000-0000-0000-00000000b004'));
select t.ok('the public entry says which checks it raised (codes only)',
  (select payload->'ai_read'->'checks' from ww.events where seq = ((select r from cq)->>'seq')::bigint) = '["over_price"]'::jsonb);
select t.ok('a refused confirmation leaves no decision behind',
  not exists (select 1 from ww.suggestion_decisions where suggestion_id in ((select p2 from t.b), (select r from t.b))));

-- a real second bill with the same number (e.g. a two-page bill): allowed with a public reason
set role authenticated;
select t.as_person(4);
create temp table cr as select public.confirm_suggestion((select r from t.b), 'expense.recorded',
  t.pay2(1500, '123', 'ffffffff-0000-0000-0000-00000000b005', '{"duplicate_reason_np": "दुई पानाको बिल; यो दोस्रो पाना"}'), '2026-10-29', '2083/84') as r;
reset role;
select t.ok('with a reason it is recorded, and the reason is public',
  (select payload->>'duplicate_reason_np' from ww.events where seq = ((select r from cr)->>'seq')::bigint) like 'दुई पानाको%');

-- the accounts committee sees every flagged entry
set role authenticated;
select t.as_person(4);
select t.rejects('only the accounts committee sees the flagged list', $$select * from public.officer_flagged_bills('thumki-cfug')$$, 'this view is for');
select t.as_person(6);
select t.ok('the accounts committee sees the flagged entries, newest first, with who confirmed them',
  (select array_agg(t.codes(checks)::text order by event_seq desc) from public.officer_flagged_bills('thumki-cfug'))
    = array['{near_photo,same_bill}', '{over_price}', '{near_photo,same_photo_twice}']
  and (select bool_and(confirmed_by = 'Gita') from public.officer_flagged_bills('thumki-cfug')));
reset role;

-- a corrected (cancelled) entry no longer blocks its photo or bill number
select t.as_person(2);   -- treasurer
select t.ev('correction', jsonb_build_object('corrects_seq', ((select r from cp)->>'seq')::bigint, 'reason_np', 'गलत पसल छानियो'));
select t.ok('after a correction, the corrected entry no longer blocks its photo or bill number (only the live second page does)',
  not ('same_photo' = any (t.codes(ww.bill_checks((select p2 from t.b), t.pay2(3000, '१२३', 'x'), '2026-10-28'))))
  and (select (x->>'seq')::bigint from jsonb_array_elements(ww.bill_checks((select p2 from t.b), t.pay2(3000, '१२३', 'x'), '2026-10-28')) x
       where x->>'code' = 'same_bill') = ((select r from cr)->>'seq')::bigint);
reset role;
select t.ok('the chain still verifies', (select ok from ww.verify_chain('kakani-3')));
