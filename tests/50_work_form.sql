-- Chautari — the work-hours form: who may see the worker list, and what an entry needs. (SAMPLE data, fictional people.)
-- Runs after 10_rules (person 4 is the ledger keeper, person 5 a supervisor, person 9 a member with no office).

set role authenticated;
select t.as_person(9);
select t.rejects('a member without an office does not see the worker list',
  $$select * from public.officer_workers('thumki-cfug')$$, 'this view is for');
select t.as_person(4);   -- ledger keeper
select t.ok('the ledger keeper sees the ward''s people by name and house number',
  (select count(*) from public.officer_workers('thumki-cfug')) >= 9
  and exists (select 1 from public.officer_workers('thumki-cfug') where person_id = t.p(9) and house_no = 7));
select t.as_person(5);   -- supervisor
select t.ok('a supervisor sees the worker list too', exists (select 1 from public.officer_workers('thumki-cfug')));
reset role;
select t.ok('the worker list carries only id, name and house number',
  pg_get_function_result('public.officer_workers(text)'::regprocedure) = 'TABLE(person_id uuid, name text, house_no integer)');

-- the form's entry: worker, task, hours, paid or voluntary, before and after photos, in the officer's own name
set role authenticated;
select t.as_person(4);
select t.ev('work.logged', '{"work_id": "abababab-0000-0000-0000-000000000051", "project": "नर्सरी", "task_np": "बेर्ना सार्ने", "hours": 4, "paid": false}',
            jsonb_build_object('person_id', t.p(9)), null, t.wph('nursery 51'), '2026-11-05');
reset role;
select t.ok('the form''s entry is waiting for a supervisor, voluntary, with both photos on the chain',
  exists (select 1 from ww.work_logs w join ww.events e on e.seq = w.logged_seq
          where w.id = 'abababab-0000-0000-0000-000000000051' and w.status = 'pending' and not w.paid
            and jsonb_array_length(e.evidence) = 2));
select t.ok('the public chain shows the photos'' hashes but not who worked',
  exists (select 1 from public.chain_export c where c.type = 'work.logged' and c.evidence_text like '%before%'
          and c.payload_text like '%बेर्ना सार्ने%' and c.payload_text not like '%' || t.p(9)::text || '%'));
set role authenticated;
select t.as_person(5);   -- a supervisor recording hours themself needs no photos (rule from 0004, kept)
select t.ev('work.logged', '{"work_id": "abababab-0000-0000-0000-000000000052", "project": "नर्सरी", "task_np": "बेर्ना सार्ने", "hours": 2, "paid": true}',
            jsonb_build_object('person_id', t.p(9)), null, '[]', '2026-11-05');
reset role;
select t.ok('a supervisor may record hours without photos', exists (select 1 from ww.work_logs where id = 'abababab-0000-0000-0000-000000000052'));
select t.ok('the chain still verifies after the form''s entries', (select ok from ww.verify_chain('kakani-3')));
