-- Chautari — 0004: work hours, fair turns, parma, nature's account, questions

-- ---------------------------------------------------------------------------
-- Work
-- ---------------------------------------------------------------------------
create table ww.work_logs (
  id            uuid primary key,
  entity_id     text not null references ww.entities(id),
  logged_seq    bigint not null,
  logged_by     uuid,
  person_id     uuid not null references ww.persons(id),
  household_id  uuid references ww.households(id),
  work_date     date not null,
  project       text not null,
  task_np       text not null,
  hours         numeric(4,2) not null,
  paid          boolean not null,
  output_qty    numeric,
  output_unit   text,
  status        text not null default 'pending' check (status in ('pending', 'approved', 'cancelled')),
  approved_by   uuid references ww.persons(id),
  status_seq    bigint not null
);

-- work.logged: payload {work_id, project, task_np, hours, paid, output_qty?, output_unit?}; private {person_id}
create or replace function ww.v_work_logged(e ww.events) returns ww.events
language plpgsql as $$
declare h numeric;
begin
  perform ww.req_uuid(e.payload, 'work_id');
  perform ww.req_text(e.payload, 'project');
  perform ww.req_text(e.payload, 'task_np');
  h := ww.req_amount(e.payload, 'hours');
  if h > 12 then perform ww.reject('more than 12 hours in one day'); end if;
  if jsonb_typeof(e.payload->'paid') <> 'boolean' then perform ww.reject('"paid" must be true or false'); end if;
  if not exists (select 1 from ww.persons where id = ww.req_uuid(e.private, 'person_id') and ward_id = e.ward_id) then
    perform ww.reject('unknown worker');
  end if;
  if exists (select 1 from ww.work_logs where id = (e.payload->>'work_id')::uuid) then
    perform ww.reject('this work entry already exists');
  end if;
  -- photo evidence (camera-only in ODK) unless the supervisor records the hours themself
  if jsonb_array_length(e.evidence) = 0 and not ww.has_role(e.entity_id, e.actor, array['supervisor']) then
    perform ww.reject('attach the before/after photos taken in the form');
  end if;
  if coalesce((select sum(hours) from ww.work_logs
       where person_id = (e.private->>'person_id')::uuid and work_date = e.occurred_on and status <> 'cancelled'), 0) + h > 12 then
    perform ww.reject('this person would have more than 12 hours on that day');
  end if;
  return e;
end $$;

create or replace function ww.p_work_logged(e ww.events) returns void
language sql as $$
  insert into ww.work_logs (id, entity_id, logged_seq, logged_by, person_id, household_id, work_date, project,
                            task_np, hours, paid, output_qty, output_unit, status_seq)
  select (e.payload->>'work_id')::uuid, e.entity_id, e.seq, e.actor, p.id, p.household_id, e.occurred_on,
         e.payload->>'project', e.payload->>'task_np', (e.payload->>'hours')::numeric,
         (e.payload->>'paid')::boolean, (e.payload->>'output_qty')::numeric, e.payload->>'output_unit', e.seq
  from ww.persons p where p.id = (e.private->>'person_id')::uuid
$$;

-- work.approved: payload {work_id}. Never your own hours or your own household's.
create or replace function ww.v_work_approved(e ww.events) returns ww.events
language plpgsql as $$
declare w ww.work_logs; me ww.persons;
begin
  select * into w from ww.work_logs where id = ww.req_uuid(e.payload, 'work_id') and entity_id = e.entity_id;
  if not found then perform ww.reject('unknown work entry'); end if;
  if w.status <> 'pending' then perform ww.reject(format('this work entry is already %s', w.status)); end if;
  select * into me from ww.persons where id = e.actor;
  if w.person_id = me.id then perform ww.reject('you cannot approve your own hours'); end if;
  if w.household_id is not null and w.household_id = me.household_id then
    perform ww.reject('you cannot approve hours of your own household');
  end if;
  return e;
end $$;

create or replace function ww.p_work_approved(e ww.events) returns void
language sql as $$
  update ww.work_logs set status = 'approved', approved_by = e.actor, status_seq = e.seq
   where id = (e.payload->>'work_id')::uuid
$$;

-- rota.offered: payload {offer_id, project, task_np, hours, accepted}; private {household_id}
create table ww.rota_offers (
  id            uuid primary key,
  entity_id     text not null references ww.entities(id),
  household_id  uuid not null references ww.households(id),
  offered_on    date not null,
  project       text not null,
  task_np       text not null,
  hours         numeric(5,2) not null,
  accepted      boolean not null,
  event_seq     bigint not null
);

create or replace function ww.v_rota_offered(e ww.events) returns ww.events
language plpgsql as $$
begin
  perform ww.req_uuid(e.payload, 'offer_id');
  perform ww.req_text(e.payload, 'project');
  perform ww.req_text(e.payload, 'task_np');
  perform ww.req_amount(e.payload, 'hours');
  if jsonb_typeof(e.payload->'accepted') <> 'boolean' then perform ww.reject('"accepted" must be true or false'); end if;
  if not exists (select 1 from ww.households where id = ww.req_uuid(e.private, 'household_id') and ward_id = e.ward_id) then
    perform ww.reject('unknown household');
  end if;
  return e;
end $$;

create or replace function ww.p_rota_offered(e ww.events) returns void
language sql as $$
  insert into ww.rota_offers (id, entity_id, household_id, offered_on, project, task_np, hours, accepted, event_seq)
  values ((e.payload->>'offer_id')::uuid, e.entity_id, (e.private->>'household_id')::uuid, e.occurred_on,
          e.payload->>'project', e.payload->>'task_np', (e.payload->>'hours')::numeric,
          (e.payload->>'accepted')::boolean, e.seq)
$$;

-- Fair turns (bylaws v4 s.54): paid approved hours and declined offers per household per month.
create or replace view ww.v_fair_turns as
with hours as (
  select entity_id, household_id, date_trunc('month', work_date)::date as month, sum(hours) as paid_hours
  from ww.work_logs where paid and status = 'approved' and household_id is not null group by 1, 2, 3),
offers as (
  select entity_id, household_id, date_trunc('month', offered_on)::date as month,
         count(*) as offers, count(*) filter (where not accepted) as declined
  from ww.rota_offers group by 1, 2, 3)
select coalesce(h.entity_id, o.entity_id) as entity_id, hh.house_no,
       coalesce(h.month, o.month) as month,
       coalesce(h.paid_hours, 0) as paid_hours, coalesce(o.offers, 0) as offers, coalesce(o.declined, 0) as declined
from hours h full join offers o using (entity_id, household_id, month)
join ww.households hh on hh.id = coalesce(h.household_id, o.household_id);

-- ---------------------------------------------------------------------------
-- Parma (labour exchange between households; no money)
-- ---------------------------------------------------------------------------
-- parma.exchanged: payload {days, task_np}; private {helper_household_id, helped_household_id}
create table ww.parma (
  event_seq            bigint primary key,
  entity_id            text not null references ww.entities(id),
  helper_household_id  uuid not null references ww.households(id),
  helped_household_id  uuid not null references ww.households(id),
  on_date              date not null,
  days                 numeric(4,1) not null,
  task_np              text not null,
  cancelled            boolean not null default false
);

create or replace function ww.v_parma_exchanged(e ww.events) returns ww.events
language plpgsql as $$
declare a uuid := ww.req_uuid(e.private, 'helper_household_id');
        b uuid := ww.req_uuid(e.private, 'helped_household_id');
begin
  if a = b then perform ww.reject('a household cannot exchange parma with itself'); end if;
  if (select count(*) from ww.households where id in (a, b) and ward_id = e.ward_id) <> 2 then
    perform ww.reject('unknown household');
  end if;
  perform ww.req_amount(e.payload, 'days');
  perform ww.req_text(e.payload, 'task_np');
  return e;
end $$;

create or replace function ww.p_parma_exchanged(e ww.events) returns void
language sql as $$
  insert into ww.parma (event_seq, entity_id, helper_household_id, helped_household_id, on_date, days, task_np)
  values (e.seq, e.entity_id, (e.private->>'helper_household_id')::uuid, (e.private->>'helped_household_id')::uuid,
          e.occurred_on, (e.payload->>'days')::numeric, e.payload->>'task_np')
$$;

-- ---------------------------------------------------------------------------
-- Nature's account
-- ---------------------------------------------------------------------------
-- reading.spring: payload {spring_id, litres_per_minute, method}
-- reading.rain:   payload {gauge_id, mm}
create or replace function ww.v_reading(e ww.events) returns ww.events
language plpgsql as $$
begin
  if e.type = 'reading.spring' then
    perform ww.req_text(e.payload, 'spring_id');
    if (e.payload->>'litres_per_minute') is null or (e.payload->>'litres_per_minute')::numeric < 0 then
      perform ww.reject('"litres_per_minute" must be zero or more');
    end if;
  else
    perform ww.req_text(e.payload, 'gauge_id');
    if (e.payload->>'mm') is null or (e.payload->>'mm')::numeric < 0 then
      perform ww.reject('"mm" must be zero or more');
    end if;
  end if;
  return e;
end $$;

-- ---------------------------------------------------------------------------
-- Questions on entries (जानकारी माग्नुहोस्) — the asker stays private
-- ---------------------------------------------------------------------------
create table ww.questions (
  id           uuid primary key,
  entity_id    text not null references ww.entities(id),
  about_seq    bigint not null,
  asked_seq    bigint not null,
  asked_by     uuid not null references ww.persons(id),
  text_np      text not null,
  status       text not null default 'open' check (status in ('open', 'closed')),
  outcome      text check (outcome in ('explained', 'difference_returned', 'refunded', 'improved')),
  closed_seq   bigint
);

-- question.raised: payload {question_id, about_seq}; private {text_np}
create or replace function ww.v_question_raised(e ww.events) returns ww.events
language plpgsql as $$
begin
  perform ww.req_uuid(e.payload, 'question_id');
  perform ww.req_text(e.private, 'text_np');
  if not exists (select 1 from ww.events where ward_id = e.ward_id and seq = (ww.req_text(e.payload, 'about_seq'))::bigint) then
    perform ww.reject('no entry with that number');
  end if;
  if e.actor is null then perform ww.reject('a question needs the person asking'); end if;
  return e;
end $$;

create or replace function ww.p_question_raised(e ww.events) returns void
language sql as $$
  insert into ww.questions (id, entity_id, about_seq, asked_seq, asked_by, text_np)
  values ((e.payload->>'question_id')::uuid, e.entity_id, (e.payload->>'about_seq')::bigint, e.seq, e.actor, e.private->>'text_np')
$$;

-- question.closed: payload {question_id, outcome, answer_np}
create or replace function ww.v_question_closed(e ww.events) returns ww.events
language plpgsql as $$
declare q ww.questions;
begin
  select * into q from ww.questions where id = ww.req_uuid(e.payload, 'question_id') and entity_id = e.entity_id;
  if not found then perform ww.reject('unknown question'); end if;
  if q.status <> 'open' then perform ww.reject('this question is already closed'); end if;
  if coalesce(e.payload->>'outcome', '') not in ('explained', 'difference_returned', 'refunded', 'improved') then
    perform ww.reject('outcome must be explained, difference_returned, refunded or improved');
  end if;
  perform ww.req_text(e.payload, 'answer_np');
  return e;
end $$;

create or replace function ww.p_question_closed(e ww.events) returns void
language sql as $$
  update ww.questions set status = 'closed', outcome = e.payload->>'outcome', closed_seq = e.seq
   where id = (e.payload->>'question_id')::uuid
$$;

-- ---------------------------------------------------------------------------
-- Corrections now also cover work and parma
-- ---------------------------------------------------------------------------
create or replace function ww.p_correction(e ww.events) returns void
language plpgsql as $$
declare target ww.events; p ww.postings;
begin
  select * into target from ww.events where ward_id = e.ward_id and seq = (e.payload->>'corrects_seq')::bigint;
  insert into ww.corrections values (target.seq, e.ward_id, e.seq);
  for p in select * from ww.postings where ward_id = e.ward_id and event_seq = target.seq loop
    perform ww.post(e, p.account_code, p.credit, p.debit, 'सच्याइएको: ' || (e.payload->>'reason_np'));
  end loop;
  case target.type
    when 'payment.released' then
      update ww.expenses set status = 'reversed', status_seq = e.seq where id = (target.payload->>'expense_id')::uuid;
    when 'expense.recorded' then
      update ww.expenses set status = 'cancelled', status_seq = e.seq where recorded_seq = target.seq;
    when 'budget.approved' then
      update ww.budget_lines set cancelled_seq = e.seq where approved_seq = target.seq;
    when 'work.logged' then
      update ww.work_logs set status = 'cancelled', status_seq = e.seq where logged_seq = target.seq;
    when 'work.approved' then
      update ww.work_logs set status = 'pending', approved_by = null, status_seq = e.seq
       where id = (target.payload->>'work_id')::uuid;
    when 'parma.exchanged' then
      update ww.parma set cancelled = true where event_seq = target.seq;
    else null;
  end case;
end $$;

-- a correction of approved work must not leave the work unapprovable by mistake; a
-- correction of a work entry already approved must first undo the approval
create or replace function ww.v_correction_work_guard(e ww.events) returns ww.events
language plpgsql as $$
declare target ww.events;
begin
  e := ww.v_correction(e);
  select * into target from ww.events where ward_id = e.ward_id and seq = (e.payload->>'corrects_seq')::bigint;
  if target.type = 'work.logged' and exists
     (select 1 from ww.work_logs where logged_seq = target.seq and status = 'approved') then
    perform ww.reject('this work is approved: correct the approval first');
  end if;
  return e;
end $$;

update ww.event_types set validator = 'ww.v_correction_work_guard(ww.events)' where type = 'correction';

insert into ww.event_types (type, allowed_roles, validator, projector, description) values
 ('work.logged',     array['ledger_keeper','supervisor'], 'ww.v_work_logged(ww.events)',   'ww.p_work_logged(ww.events)',   'Hours of work, with photos and output'),
 ('work.approved',   array['supervisor'],                 'ww.v_work_approved(ww.events)', 'ww.p_work_approved(ww.events)', 'A supervisor approves hours (never their own or their household''s)'),
 ('rota.offered',    array['ledger_keeper','supervisor'], 'ww.v_rota_offered(ww.events)',  'ww.p_rota_offered(ww.events)',  'Paid work offered to a household in turn'),
 ('parma.exchanged', array['ledger_keeper'],              'ww.v_parma_exchanged(ww.events)','ww.p_parma_exchanged(ww.events)','Labour exchanged between two households'),
 ('reading.spring',  array['ledger_keeper','nature_guardian'], 'ww.v_reading(ww.events)', null, 'Spring flow, litres per minute'),
 ('reading.rain',    array['ledger_keeper','nature_guardian'], 'ww.v_reading(ww.events)', null, 'Rain gauge, millimetres'),
 ('question.raised', null,                                'ww.v_question_raised(ww.events)','ww.p_question_raised(ww.events)','A member asks about an entry'),
 ('question.closed', array['accounts_committee'],         'ww.v_question_closed(ww.events)','ww.p_question_closed(ww.events)','The accounts committee answers, with one of four outcomes');

