-- Chautari — 0005: privacy circles and the API
-- The core schema ww is closed to the API. Everything the app reads or writes goes
-- through this file:
--   the world    : public.* views (totals, the chain export, fair turns, nature)
--   a member     : public.my_record()  — only their own and their household's rows
--   officers     : public.officer_*()  — full detail, only while holding the office
--   writing      : public.record_event() — every write goes through ww.validate

revoke all on schema ww from public;
revoke all on all tables in schema ww from public;
revoke all on all functions in schema ww from public;
do $$ begin
  if exists (select 1 from pg_roles where rolname = 'anon') then
    execute 'revoke all on schema ww from anon, authenticated';
    execute 'revoke all on all tables in schema ww from anon, authenticated';
    execute 'revoke all on all functions in schema ww from anon, authenticated';
  end if;
end $$;

alter default privileges in schema ww revoke execute on functions from public;

-- The public views call four small helpers. PostgreSQL checks function permissions
-- against the reader of a view, so these run as their owner and are the only ww
-- functions the API roles may execute. Schema usage alone gives no table access.
alter function ww.private_digest(ww.events) security definer set search_path = '';
alter function ww.entity_kind(text)         security definer set search_path = '';
alter function ww.balance(text, text)       security definer set search_path = '';
alter function ww.rule(text, text)          security definer set search_path = '';
do $$ begin
  if exists (select 1 from pg_roles where rolname = 'anon') then
    execute 'grant usage on schema ww to anon, authenticated';
    execute 'grant execute on function ww.private_digest(ww.events), ww.entity_kind(text), ww.balance(text, text), ww.rule(text, text) to anon, authenticated';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Writing: one door
-- ---------------------------------------------------------------------------
create or replace function public.record_event(
  p_entity      text,
  p_type        text,
  p_payload     jsonb default '{}'::jsonb,
  p_private     jsonb default '{}'::jsonb,
  p_occurred_on date  default current_date,
  p_fiscal_year text  default null,
  p_evidence    jsonb default '[]'::jsonb)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare r ww.events; w text;
begin
  select ward_id into w from ww.entities where id = p_entity;
  if w is null then raise exception 'unknown body %', p_entity; end if;
  if p_occurred_on > current_date + 1 then raise exception 'the date is in the future'; end if;
  insert into ww.events (ward_id, entity_id, type, payload, private, evidence, occurred_on, fiscal_year)
  values (w, p_entity, p_type, coalesce(p_payload, '{}'), coalesce(p_private, '{}'),
          coalesce(p_evidence, '[]'), p_occurred_on, p_fiscal_year)
  returning * into r;
  return jsonb_build_object('seq', r.seq, 'hash', r.hash, 'voucher_no', r.payload->'voucher_no');
end $$;

revoke all on function public.record_event(text, text, jsonb, jsonb, date, text, jsonb) from public;
do $$ begin
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    execute 'grant execute on function public.record_event(text, text, jsonb, jsonb, date, text, jsonb) to authenticated';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- The world: public views (no person, no household detail, no actor)
-- ---------------------------------------------------------------------------

-- The chain export: everything a witness needs to recompute every hash.
create or replace view public.chain_export as
select ward_id, seq, entity_id, type, occurred_on, fiscal_year,
       to_char(recorded_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"') as recorded_at_utc,
       payload::text as payload_text, ww.private_digest(e) as private_digest,
       evidence::text as evidence_text, prev_hash, hash
from ww.events e;

create or replace view public.chain_heads as select * from ww.chain_heads;

create or replace view public.bodies as
select e.id, e.ward_id, e.kind, e.name_np, e.name_en, w.name_np as ward_name_np
from ww.entities e join ww.wards w on w.id = e.ward_id;

create or replace view public.income_and_spending as
select * from ww.v_ledger_by_head;

create or replace view public.budget_status as
select * from ww.v_budget_status;

create or replace view public.spending_shares as
select * from ww.v_spending_shares;

create or replace view public.money_status as
select en.id as entity_id,
       ww.balance(en.id, 'BS-CASH') as cash_in_hand,
       ww.balance(en.id, 'BS-BANK') as in_bank,
       ww.balance(en.id, 'BS-ADV')  as advances_out,
       f.over_limit as cash_over_limit, f.late_banking,
       (select count(*) from ww.expenses x where x.entity_id = en.id and x.status = 'pending') as payments_waiting
from ww.entities en join ww.v_cash_flags f on f.entity_id = en.id;

-- Payments, as the notice board shows them: shops and contractors by name, people never.
create or replace view public.payments as
select x.entity_id, x.fiscal_year, ev.occurred_on as paid_on, (ev.payload->>'voucher_no')::int as voucher_no,
       x.amount, x.account_code, a.name_np as head_np, x.memo_np,
       case when p.kind = 'person' then null else p.name end as payee_name,
       p.kind as payee_kind, x.estimated, x.status
from ww.expenses x
join ww.payees p on p.id = x.payee_id
join ww.accounts a on a.entity_kind = ww.entity_kind(x.entity_id) and a.code = x.account_code
join ww.events ev on ev.ward_id = (select ward_id from ww.entities where id = x.entity_id) and ev.seq = x.status_seq
where x.status in ('paid', 'reversed');

-- Fair turns: paid hours per household number, only while the assembly keeps it public.
create or replace view public.fair_turns as
select ft.* from ww.v_fair_turns ft
where (ww.rule(ft.entity_id, 'fair_turns_public'))::boolean;

-- Work per project: shown only when at least min_public_group people worked on it that month.
create or replace view public.project_hours as
select entity_id, project, date_trunc('month', work_date)::date as month,
       case when count(distinct person_id) >= (ww.rule(entity_id, 'min_public_group'))::int
            then sum(hours) end as hours,
       case when count(distinct person_id) >= (ww.rule(entity_id, 'min_public_group'))::int
            then count(distinct person_id) end as workers,
       count(distinct person_id) < (ww.rule(entity_id, 'min_public_group'))::int as too_few_to_show
from ww.work_logs where status = 'approved'
group by entity_id, project, date_trunc('month', work_date);

create or replace view public.office_holders as
select r.entity_id, r.role, p.display_name, r.started_on
from ww.role_terms r join ww.persons p on p.id = r.person_id
where r.to_seq is null and r.role <> 'admin';

create or replace view public.nature_readings as
select ev.entity_id, ev.occurred_on, ev.type,
       coalesce(ev.payload->>'spring_id', ev.payload->>'gauge_id') as site,
       coalesce((ev.payload->>'litres_per_minute')::numeric, (ev.payload->>'mm')::numeric) as value,
       case ev.type when 'reading.spring' then 'litres/min' else 'mm' end as unit,
       ev.seq
from ww.events ev
where ev.type in ('reading.spring', 'reading.rain')
  and not exists (select 1 from ww.corrections c where c.ward_id = ev.ward_id and c.corrected_seq = ev.seq);

create or replace view public.questions as
select q.entity_id, q.id, q.about_seq, q.status, q.outcome,
       (select occurred_on from ww.events where seq = q.asked_seq and entity_id = q.entity_id) as asked_on,
       (select payload->>'answer_np' from ww.events where seq = q.closed_seq and entity_id = q.entity_id) as answer_np
from ww.questions q;

create or replace view public.rules as
select en.id as entity_id, d.key, ww.rule(en.id, d.key) as value, d.purpose_np, d.purpose_en, d.source,
       rc.decision_ref
from ww.entities en cross join ww.rule_defaults d
left join ww.rules_current rc on rc.entity_id = en.id and rc.key = d.key;

create or replace view public.accounts as
select entity_kind, code, kind, directive_code, name_np, name_en, spend_category from ww.accounts;

do $$
declare v text;
begin
  foreach v in array array['chain_export','chain_heads','bodies','income_and_spending','budget_status',
                           'spending_shares','money_status','payments','fair_turns','project_hours',
                           'office_holders','nature_readings','questions','rules','accounts'] loop
    execute format('revoke all on public.%I from public', v);
    if exists (select 1 from pg_roles where rolname = 'anon') then
      execute format('revoke all on public.%I from anon, authenticated', v);
      execute format('grant select on public.%I to anon, authenticated', v);
    end if;
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- A member: their own record, and their household's
-- ---------------------------------------------------------------------------
create or replace function public.my_record()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare me ww.persons;
begin
  select * into me from ww.persons where id = ww.current_person();
  if me.id is null then raise exception 'this login is not linked to a registered person'; end if;
  return jsonb_build_object(
    'person', jsonb_build_object('id', me.id, 'name', me.display_name,
                'house_no', (select house_no from ww.households where id = me.household_id)),
    'roles', coalesce((select jsonb_agg(jsonb_build_object('entity', entity_id, 'role', role))
                         from ww.role_terms where person_id = me.id and to_seq is null), '[]'),
    'work', coalesce((select jsonb_agg(jsonb_build_object('date', work_date, 'project', project, 'task_np', task_np,
                         'hours', hours, 'paid', paid, 'status', status) order by work_date desc)
                        from ww.work_logs where person_id = me.id), '[]'),
    'payments_to_me', coalesce((select jsonb_agg(jsonb_build_object('amount', x.amount, 'memo_np', x.memo_np,
                         'status', x.status) order by x.recorded_seq desc)
                        from ww.expenses x join ww.payees p on p.id = x.payee_id
                       where p.person_id = me.id), '[]'),
    'household_turns', coalesce((select jsonb_agg(to_jsonb(ft) order by ft.month desc) from ww.v_fair_turns ft
                       join ww.households h on h.house_no = ft.house_no and h.id = me.household_id), '[]'),
    'parma', coalesce((
        select jsonb_agg(jsonb_build_object('other_house_no', other.house_no, 'days_we_helped', s.helped, 'days_they_helped', s.received))
        from (select case when helper_household_id = me.household_id then helped_household_id else helper_household_id end as other_id,
                     sum(days) filter (where helper_household_id = me.household_id) as helped,
                     sum(days) filter (where helped_household_id = me.household_id) as received
                from ww.parma where not cancelled
                 and me.household_id in (helper_household_id, helped_household_id)
               group by 1) s
        join ww.households other on other.id = s.other_id), '[]'),
    'my_questions', coalesce((select jsonb_agg(jsonb_build_object('id', id, 'about_seq', about_seq, 'status', status, 'outcome', outcome))
                       from ww.questions where asked_by = me.id), '[]'));
end $$;

-- ---------------------------------------------------------------------------
-- Officers: full detail while they hold office
-- ---------------------------------------------------------------------------
create or replace function ww.require_office(p_entity text, p_roles text[]) returns void
language plpgsql stable as $$
declare me uuid := ww.current_person();
begin
  if ww.auth_uid() is null then return; end if;   -- trusted server job
  if me is null or not ww.has_role(p_entity, me, p_roles || array['admin']) then
    raise exception 'Chautari: this view is for %', array_to_string(p_roles, ' / ') using errcode = 'insufficient_privilege';
  end if;
end $$;

create or replace function public.officer_vouchers(p_entity text, p_fiscal_year text)
returns setof ww.v_vouchers language plpgsql stable security definer set search_path = '' as $$
begin
  perform ww.require_office(p_entity, array['chair','secretary','treasurer','accounts_committee']);
  return query select * from ww.v_vouchers where entity_id = p_entity and fiscal_year = p_fiscal_year;
end $$;

create or replace function public.officer_cash_book(p_entity text, p_fiscal_year text)
returns setof ww.v_cash_book language plpgsql stable security definer set search_path = '' as $$
begin
  perform ww.require_office(p_entity, array['chair','secretary','treasurer','accounts_committee']);
  return query select * from ww.v_cash_book where entity_id = p_entity and fiscal_year = p_fiscal_year;
end $$;

create or replace function public.officer_payments_waiting(p_entity text)
returns table (expense_id uuid, recorded_seq bigint, amount numeric, account_code text, memo_np text,
               payee text, method text, estimated boolean, budget_line text, signed_by jsonb)
language plpgsql stable security definer set search_path = '' as $$
begin
  perform ww.require_office(p_entity, array['chair','secretary','treasurer','accounts_committee']);
  return query
  select x.id, x.recorded_seq, x.amount, x.account_code, x.memo_np,
         coalesce(p.name, pp.display_name), x.method, x.estimated, l.title_np,
         coalesce((select jsonb_agg(jsonb_build_object('role', a.as_role, 'name', s.display_name))
                     from ww.expense_approvals a join ww.persons s on s.id = a.person_id
                    where a.expense_id = x.id), '[]')
  from ww.expenses x join ww.payees p on p.id = x.payee_id
  left join ww.persons pp on pp.id = p.person_id
  left join ww.budget_lines l on l.id = x.budget_line_id
  where x.entity_id = p_entity and x.status = 'pending' order by x.recorded_seq;
end $$;

create or replace function public.officer_work_waiting(p_entity text)
returns table (work_id uuid, logged_seq bigint, work_date date, worker text, house_no int,
               project text, task_np text, hours numeric, paid boolean)
language plpgsql stable security definer set search_path = '' as $$
begin
  perform ww.require_office(p_entity, array['supervisor','accounts_committee']);
  return query
  select w.id, w.logged_seq, w.work_date, p.display_name, h.house_no, w.project, w.task_np, w.hours, w.paid
  from ww.work_logs w join ww.persons p on p.id = w.person_id left join ww.households h on h.id = w.household_id
  where w.entity_id = p_entity and w.status = 'pending' order by w.work_date, w.logged_seq;
end $$;

create or replace function public.officer_questions(p_entity text)
returns table (question_id uuid, about_seq bigint, asked_by text, text_np text, status text, outcome text)
language plpgsql stable security definer set search_path = '' as $$
begin
  perform ww.require_office(p_entity, array['accounts_committee']);
  return query
  select q.id, q.about_seq, p.display_name, q.text_np, q.status, q.outcome
  from ww.questions q join ww.persons p on p.id = q.asked_by
  where q.entity_id = p_entity order by q.asked_seq;
end $$;

do $$
declare f text;
begin
  foreach f in array array[
    'public.my_record()',
    'public.officer_vouchers(text, text)', 'public.officer_cash_book(text, text)',
    'public.officer_payments_waiting(text)', 'public.officer_work_waiting(text)', 'public.officer_questions(text)'] loop
    execute format('revoke all on function %s from public', f);
    if exists (select 1 from pg_roles where rolname = 'authenticated') then
      execute format('grant execute on function %s to authenticated', f);
    end if;
  end loop;
end $$;
