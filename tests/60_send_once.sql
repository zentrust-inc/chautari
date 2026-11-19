-- Chautari — entries kept on the phone are recorded once, however often they are sent. (SAMPLE data, fictional people.)
-- Runs after 10_rules: person 4 is the ledger keeper, person 5 a supervisor, person 9 a member.

create function t.once(p_ref uuid, p_payload jsonb, p_on date default '2026-11-06') returns jsonb language sql as $$
  select public.record_event_once(p_ref, 'thumki-cfug', 'work.logged', p_payload, jsonb_build_object('person_id', t.p(9)),
                                  p_on, '2083/84', t.wph('once ' || p_ref))
$$;
grant execute on all functions in schema t to authenticated;

set role authenticated;
select t.as_person(4);
create temp table r1 as select t.once('0e0e0e0e-0000-0000-0000-000000000001',
  '{"work_id": "abababab-0000-0000-0000-000000000061", "project": "नर्सरी", "task_np": "गोडमेल", "hours": 3, "paid": true}') as r;
create temp table r2 as select t.once('0e0e0e0e-0000-0000-0000-000000000001',
  '{"work_id": "abababab-0000-0000-0000-000000000061", "project": "नर्सरी", "task_np": "गोडमेल", "hours": 3, "paid": true}') as r;
select t.ok('sending the same entry twice records it once and returns the same entry number',
  (select (r->>'seq')::bigint from r1) = (select (r->>'seq')::bigint from r2)
  and (select (r->>'already')::boolean from r2) and not (select (r->>'already')::boolean from r1));
select t.ok('a second send with a changed payload still returns the first entry, not a new one',
  (t.once('0e0e0e0e-0000-0000-0000-000000000001',
     '{"work_id": "abababab-0000-0000-0000-000000000062", "project": "नर्सरी", "task_np": "गोडमेल", "hours": 9, "paid": true}')->>'seq')::bigint
  = (select (r->>'seq')::bigint from r1));
select t.rejects('an entry sent once still passes every rule (12 hours a day)',
  $$select t.once('0e0e0e0e-0000-0000-0000-000000000002',
     '{"work_id": "abababab-0000-0000-0000-000000000063", "project": "नर्सरी", "task_np": "गोडमेल", "hours": 10, "paid": true}')$$,
  'more than 12 hours');
select t.ok('a rejected entry leaves no id behind, so it can be corrected and sent again',
  (t.once('0e0e0e0e-0000-0000-0000-000000000002',
     '{"work_id": "abababab-0000-0000-0000-000000000063", "project": "नर्सरी", "task_np": "गोडमेल", "hours": 2, "paid": true}')->>'already')::boolean = false);
select t.as_person(5);
select t.rejects('nobody else can claim an entry id', $$select t.once('0e0e0e0e-0000-0000-0000-000000000001',
  '{"work_id": "abababab-0000-0000-0000-000000000064", "project": "x", "task_np": "x", "hours": 1, "paid": true}')$$, 'belongs to someone else');
select t.rejects('the entry ids cannot be read from the app', $$select * from ww.client_refs$$, 'permission denied');
reset role;
select t.ok('the work was recorded once for that id',
  (select count(*) from ww.work_logs where id in ('abababab-0000-0000-0000-000000000061', 'abababab-0000-0000-0000-000000000062')) = 1);
select t.rejects('an entry id cannot be changed', $$update ww.client_refs set seq = 1$$, 'not allowed');
select t.ok('the chain still verifies', (select ok from ww.verify_chain('kakani-3')));
