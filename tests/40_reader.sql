-- Chautari — the document reader: it suggests, a named person confirms. (SAMPLE data, fictional people.)
-- Runs after 10_rules (people, offices, payee eeee…01, budget line dddd…01 for EX-2.02).

create function t.sug(p_amount numeric, p_memo text default 'लप्सी, ऐसेलु, टिमुर बिरुवा') returns uuid language sql as $$
  select public.record_suggestion('thumki-cfug',
    encode(sha256(convert_to('sample bill ' || p_amount || p_memo, 'UTF8')), 'hex'), 'bill',
    'documents/thumki-cfug/' || encode(sha256(convert_to('sample bill ' || p_amount || p_memo, 'UTF8')), 'hex') || '.jpg',
    'chautari-reader/0.1.0 (tesseract 5.3.4)',
    jsonb_build_object('type', 'expense.recorded', 'occurred_on', '2026-10-26', 'fiscal_year', '2083/84',
      'payload', jsonb_build_object('amount', p_amount, 'account_code', 'EX-2.02', 'method', 'cash', 'memo_np', p_memo,
                                    'payee_id', 'eeeeeeee-0000-0000-0000-000000000001',
                                    'budget_line_id', 'dddddddd-0000-0000-0000-000000000001'),
      'fields', jsonb_build_object('total', jsonb_build_object('value', p_amount, 'status', 'ok')),
      'flags', '[]'::jsonb))
$$;

create function t.pay(p_amount numeric, p_memo text, p_expense uuid) returns jsonb language sql as $$
  select jsonb_build_object('expense_id', p_expense, 'amount', p_amount, 'account_code', 'EX-2.02', 'method', 'cash',
    'memo_np', p_memo, 'payee_id', 'eeeeeeee-0000-0000-0000-000000000001',
    'budget_line_id', 'dddddddd-0000-0000-0000-000000000001')
$$;

grant execute on all functions in schema t to authenticated;

-- ---------------------------------------------------------------------------
-- The reader hands in suggestions; only our server can
-- ---------------------------------------------------------------------------
reset role;
select t.as_server();
create table t.s as select t.sug(7900) as a, t.sug(750, 'चिया खाजा') as b, t.sug(1234, 'दोहोरिएको बिल') as c;
grant select on t.s to authenticated;
select t.ok('the reader''s suggestions are kept as it made them', (select count(*) from ww.suggestions) = 3);

set role authenticated;
select t.as_person(4);
select t.rejects('a signed-in person cannot hand in a suggestion as if they were the reader',
  $$select t.sug(10)$$, 'permission denied');
reset role;

select t.as_server();
select t.rejects('the reader suggests only money entries',
  $$select public.record_suggestion('thumki-cfug', repeat('a', 64), 'bill', 'documents/x.jpg', 'r', '{"type": "role.assigned"}')$$,
  'only expense.recorded or income.recorded');
select t.rejects('a fingerprint must be a SHA-256',
  $$select public.record_suggestion('thumki-cfug', 'abc', 'bill', 'documents/x.jpg', 'r', '{"type": "expense.recorded"}')$$,
  'check constraint');

-- ---------------------------------------------------------------------------
-- The reader can never turn its own suggestion into an entry
-- ---------------------------------------------------------------------------
select t.as_server();
select t.rejects('without a signed-in person nothing is confirmed',
  $$select public.confirm_suggestion((select a from t.s), 'expense.recorded', t.pay(7900, 'x', 'ffffffff-0000-0000-0000-00000000a001'), '2026-10-26', '2083/84')$$,
  'named, signed-in person');

-- ---------------------------------------------------------------------------
-- Who sees what is waiting
-- ---------------------------------------------------------------------------
set role authenticated;
select t.as_person(9);   -- Tek, a member with no office
select t.rejects('a member without an office does not see the payee list', $$select * from public.officer_payees('thumki-cfug')$$, 'this view is for');
select t.rejects('a member without an office does not see waiting bills',
  $$select * from public.officer_suggestions('thumki-cfug')$$, 'this view is for');
select t.as_person(4);   -- ledger keeper
select t.ok('the ledger keeper sees the registered payees to choose from', exists (select 1 from public.officer_payees('thumki-cfug') where name = 'ककनी कृषि पसल'));
select t.ok('the ledger keeper sees the three waiting bills', (select count(*) from public.officer_suggestions('thumki-cfug')) = 3);

-- ---------------------------------------------------------------------------
-- Confirming goes through every normal rule, in the person's own name
-- ---------------------------------------------------------------------------
select t.as_person(9);
select t.rejects('only the treasurer or ledger keeper may confirm a bill (the normal rule for expenses)',
  $$select public.confirm_suggestion((select a from t.s), 'expense.recorded', t.pay(7900, 'लप्सी, ऐसेलु, टिमुर बिरुवा', 'ffffffff-0000-0000-0000-00000000a001'), '2026-10-26', '2083/84')$$,
  'only treasurer');
reset role;
select t.ok('a refused confirmation leaves no decision behind', (select count(*) from ww.suggestion_decisions) = 0);
set role authenticated;

select t.as_person(4);
create temp table c1 as select public.confirm_suggestion((select a from t.s), 'expense.recorded',
  t.pay(7900, 'लप्सी, ऐसेलु, टिमुर बिरुवा', 'ffffffff-0000-0000-0000-00000000a001'), '2026-10-26', '2083/84') as r;
reset role;
select t.ok('confirming unchanged records the expense', exists (select 1 from ww.expenses where id = 'ffffffff-0000-0000-0000-00000000a001' and amount = 7900));
select t.ok('…in the name of the person who confirmed it',
  (select actor from ww.events where seq = ((select r from c1)->>'seq')::bigint) = t.p(4));
select t.ok('…with the photo''s fingerprint as its evidence',
  (select evidence->0->>'sha256' from ww.events where seq = ((select r from c1)->>'seq')::bigint) = (select doc_sha256 from ww.suggestions where id = (select a from t.s)));
select t.ok('…and the public record says the reader read it and nothing was changed',
  (select payload->'ai_read'->'changed' from ww.events where seq = ((select r from c1)->>'seq')::bigint) = '[]'::jsonb);

set role authenticated;
select t.as_person(4);
select t.rejects('a suggestion is confirmed once',
  $$select public.confirm_suggestion((select a from t.s), 'expense.recorded', t.pay(7900, 'x', 'ffffffff-0000-0000-0000-00000000a002'), '2026-10-26', '2083/84')$$,
  'already confirmed');

-- the person corrects the amount and the date; a hand-written "ai_read" is replaced
create temp table c2 as select public.confirm_suggestion((select b from t.s), 'expense.recorded',
  t.pay(760, 'चिया खाजा', 'ffffffff-0000-0000-0000-00000000a003') || '{"ai_read": {"changed": []}}', '2026-10-27', '2083/84') as r;
reset role;
select t.ok('what the person corrected is recorded in public: amount and date',
  (select payload->'ai_read'->'changed' from ww.events where seq = ((select r from c2)->>'seq')::bigint) = '["amount", "date"]'::jsonb);
select t.ok('the corrected figure is the one recorded', (select amount from ww.expenses where id = 'ffffffff-0000-0000-0000-00000000a003') = 760);
select t.ok('the reader''s own figure is still kept beside it',
  (select (suggested->'payload'->>'amount')::numeric from ww.suggestions where id = (select b from t.s)) = 750);

-- ---------------------------------------------------------------------------
-- Rejecting needs a reason; decisions and suggestions never change
-- ---------------------------------------------------------------------------
set role authenticated;
select t.as_person(9);
select t.rejects('a member without an office cannot reject', $$select public.reject_suggestion((select c from t.s), 'duplicate')$$, 'this view is for');
select t.as_person(2);   -- treasurer
select t.rejects('a rejection says why', $$select public.reject_suggestion((select c from t.s), '  ')$$, 'say why');
select public.reject_suggestion((select c from t.s), 'दोहोरिएको बिल (duplicate)');
select t.rejects('a rejected suggestion cannot then be confirmed',
  $$select public.confirm_suggestion((select c from t.s), 'expense.recorded', t.pay(1234, 'x', 'ffffffff-0000-0000-0000-00000000a004'), '2026-10-26', '2083/84')$$,
  'already rejected');
select t.ok('nothing is waiting now', (select count(*) from public.officer_suggestions('thumki-cfug')) = 0);
reset role;

select t.as_server();
select t.rejects('a suggestion cannot be edited', $$update ww.suggestions set reader = 'x'$$, 'not allowed');
select t.rejects('a suggestion cannot be deleted', $$delete from ww.suggestions$$, 'not allowed');
select t.rejects('a decision cannot be edited', $$update ww.suggestion_decisions set changed = '{}'$$, 'not allowed');
select t.rejects('a decision cannot be deleted', $$delete from ww.suggestion_decisions$$, 'not allowed');

-- ---------------------------------------------------------------------------
-- Everyone can see how often the reader was right (counts only)
-- ---------------------------------------------------------------------------
set role anon;
select t.ok('the reader''s record is public: 3 suggested, 1 confirmed as read, 1 corrected, 1 rejected',
  (select (suggested, confirmed_unchanged, confirmed_corrected, rejected, waiting) = (3::bigint, 1::bigint, 1::bigint, 1::bigint, 0::bigint)
     from public.reader_record where entity_id = 'thumki-cfug'));
select t.rejects('the public cannot read the suggestions themselves', $$select * from ww.suggestions$$, 'permission denied');
reset role;
select t.ok('the chain still verifies after confirmed suggestions', (select ok from ww.verify_chain('kakani-3')));
