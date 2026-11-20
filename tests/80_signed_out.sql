-- Chautari — a signed-out visitor through the API is never a trusted server job (migration 0014).
-- The stub gives the API roles Supabase's default grants, like the real server.

set role anon;
select set_config('request.jwt.claim.sub', '', false);
select t.rejects('a signed-out visitor cannot call an officer view (it is not allowed to run it at all)',
  $$select * from public.officer_workers('thumki-cfug')$$, 'permission denied');
select t.rejects('a signed-out visitor cannot record anything, not even a type a server job may record',
  $$select public.record_event('thumki-cfug', 'budget.approved', '{"line_id": "dddddddd-0000-0000-0000-000000000077", "account_code": "EX-2.02", "amount": 1, "title_np": "x"}', '{}', '2026-11-01', '2083/84', '[]')$$,
  'permission denied');
select t.rejects('a signed-out visitor cannot write through a public view',
  $$insert into public.price_list values ('thumki-cfug', 'x', 'y', 1, 'z')$$, 'permission denied');
select t.rejects('a signed-out visitor cannot hand in a reader suggestion', $$select t.sug(5)$$, 'permission denied');
reset role;
select t.ok('signed-out visitors still read the public views', has_table_privilege('anon', 'public.payments', 'select'));

-- even if a function were granted by mistake, the rule itself refuses a signed-out caller
grant execute on function public.officer_workers(text), public.record_event(text, text, jsonb, jsonb, date, text, jsonb) to anon;
set role anon;
select t.rejects('the rule refuses a signed-out caller even with a grant (officer view)',
  $$select * from public.officer_workers('thumki-cfug')$$, 'this view is for');
select t.rejects('the rule refuses a signed-out caller even with a grant (record_event)',
  $$select public.record_event('thumki-cfug', 'budget.approved', '{"line_id": "dddddddd-0000-0000-0000-000000000077", "account_code": "EX-2.02", "amount": 1, "title_np": "x"}', '{}', '2026-11-01', '2083/84', '[]')$$,
  'sign in first');
reset role;
revoke execute on function public.officer_workers(text), public.record_event(text, text, jsonb, jsonb, date, text, jsonb) from anon;

set role authenticated;
select t.as_person(4);
select t.rejects('a signed-in person cannot hand in a reader suggestion (only our server can)', $$select t.sug(6)$$, 'permission denied');
select t.rejects('a signed-in person cannot write through a public view', $$update public.price_list set price = 1$$, 'permission denied');
reset role;
select t.ok('a direct database connection is still a server job', ww.is_server());
select t.ok('the chain still verifies', (select ok from ww.verify_chain('kakani-3')));
