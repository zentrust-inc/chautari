-- Chautari — 0002: people, roles, rules and the event-type registry
-- Who may record what is decided here, in the database, so no screen can bypass it.

-- ---------------------------------------------------------------------------
-- Households and people (projections of events, plus private reference data)
-- ---------------------------------------------------------------------------
create table ww.households (
  id             uuid primary key,
  ward_id        text not null references ww.wards(id),
  house_no       int  not null,              -- number in the CFUG household register
  tole           text,
  registered_seq bigint not null,
  unique (ward_id, house_no)
);

-- Private reference data from the CFUG household register. Never in the chain,
-- never public except as group totals of 5 or more households.
create table ww.household_details (
  household_id        uuid primary key references ww.households(id),
  head_name           text,
  assistant_head_name text,
  members_female      int,
  members_male        int,
  caste_group         text,
  wellbeing_class     text,
  source              text not null          -- provenance, e.g. 'CFUG register (Eng CSV), 2082'
);

create table ww.persons (
  id             uuid primary key,
  ward_id        text not null references ww.wards(id),
  household_id   uuid references ww.households(id),
  display_name   text not null,
  gender         text not null check (gender in ('f', 'm', 'o')),
  auth_user_id   uuid unique,                 -- Supabase auth user (phone OTP), linked later
  registered_seq bigint not null
);

-- Role terms: who held which office, from which event to which event.
create table ww.role_terms (
  id          bigserial primary key,
  entity_id   text not null references ww.entities(id),
  person_id   uuid not null references ww.persons(id),
  role        text not null check (role in (
                'admin', 'chair', 'vice_chair', 'secretary', 'treasurer',
                'ledger_keeper', 'supervisor', 'accounts_committee', 'nature_guardian')),
  from_seq    bigint not null,
  to_seq      bigint,
  started_on  date not null,
  ended_on    date
);
create unique index role_terms_open on ww.role_terms (entity_id, person_id, role) where to_seq is null;

create or replace function ww.has_role(p_entity text, p_person uuid, p_roles text[])
returns boolean language sql stable as $$
  select exists (select 1 from ww.role_terms
                  where entity_id = p_entity and person_id = p_person
                    and role = any (p_roles) and to_seq is null)
$$;

-- ---------------------------------------------------------------------------
-- Rules: every setting is a rule with a default; the assembly changes it with a
-- rule.set event (recorded with its decision reference). No code change needed.
-- ---------------------------------------------------------------------------
create table ww.rule_defaults (
  key          text primary key,
  value        jsonb not null,
  purpose_np   text not null,
  purpose_en   text not null,
  source       text not null
);

insert into ww.rule_defaults (key, value, purpose_np, purpose_en, source) values
 ('cash_receipt_max',     '10000', 'रु १०,००० भन्दा बढी नगद लिन पाइँदैन; बैंकमार्फत लिनुपर्छ।',
   'Cash receipts above Rs 10,000 must come through the bank.', 'CFUG financial procedure directive s.9(2)'),
 ('cash_on_hand_max',     '5000',  'हातमा रु ५,००० भन्दा बढी नगद राख्न पाइँदैन।',
   'No more than Rs 5,000 cash in hand.', 'CFUG constitution s.15(ग)'),
 ('bank_within_days',     '7',     'प्राप्त रकम ७ दिनभित्र बैंकमा जम्मा गर्नुपर्छ।',
   'Money received is banked within 7 days.', 'CFUG constitution s.13.1; directive s.13'),
 ('require_woman_signer', 'true',  'भुक्तानी गर्ने दुई हस्ताक्षरमध्ये एक महिला हुनुपर्छ।',
   'One of the two payment signers must be a woman.', 'CFUG constitution s.15(ग)'),
 ('signer_roles',         '{"required":["treasurer"],"one_of":["chair","secretary"]}',
   'कोषाध्यक्ष र अध्यक्ष वा सचिवको संयुक्त दस्तखत।',
   'Treasurer plus chair or secretary sign every payment.', 'CFUG constitution s.15(ग)'),
 ('recorder_may_sign',    'false', 'हिसाब लेख्ने व्यक्तिले भुक्तानी स्वीकृत गर्न पाउँदैन।',
   'The person who records an expense never approves its payment.', 'Draft MPC bylaws v4 s.52(2)'),
 ('estimated_cap_pct',    '5',     'अनुमानित खर्च मासिक खर्चको ५% भन्दा बढी हुन पाउँदैन।',
   'Estimated (lost-receipt) spending may not exceed 5% of a month.', 'Design Principles v0.3'),
 ('unbudgeted_item_max',  '25000', 'बजेटमा नभएको खर्च समितिले एक पटकमा रु २५,००० सम्म मात्र स्वीकृत गर्न सक्छ।',
   'The committee may approve unbudgeted spending up to Rs 25,000 per item.', 'Proposed; to confirm at the CFUG general meeting'),
 ('fair_turns_public',    'true',  'पारिश्रमिक पाइने कामको घण्टा घरधुरीअनुसार सार्वजनिक हुन्छ।',
   'Paid work hours are published per household.', 'Draft MPC bylaws v4 s.54; to confirm at the CFUG general meeting'),
 ('min_public_group',     '5',     'सार्वजनिक तथ्याङ्कमा कम्तीमा ५ जना/घरधुरीको समूह।',
   'Public totals never cover fewer than 5 people or households.', 'PRD v0.3');

create table ww.rules_current (
  entity_id  text not null references ww.entities(id),
  key        text not null references ww.rule_defaults(key),
  value      jsonb not null,
  set_seq    bigint not null,
  decision_ref text,
  primary key (entity_id, key)
);

create or replace function ww.rule(p_entity text, p_key text)
returns jsonb language sql stable as $$
  select coalesce(
    (select value from ww.rules_current where entity_id = p_entity and key = p_key),
    (select value from ww.rule_defaults where key = p_key))
$$;

-- ---------------------------------------------------------------------------
-- Who is acting
-- ---------------------------------------------------------------------------
-- Supabase provides auth.uid(). It is null for trusted server jobs (ODK importer,
-- nightly export) that connect with the service role.
create or replace function ww.auth_uid() returns uuid
language plpgsql stable as $$
begin
  return auth.uid();
exception when others then
  return null;
end $$;

create or replace function ww.current_person() returns uuid
language sql stable as $$
  select id from ww.persons where auth_user_id = ww.auth_uid()
$$;

-- ---------------------------------------------------------------------------
-- Event-type registry: who may record each type, and which functions check
-- and project it. A type not listed here is rejected.
-- ---------------------------------------------------------------------------
create table ww.event_types (
  type          text primary key,
  allowed_roles text[],          -- null = any registered person of the ward ('member')
  bootstrap_ok  boolean not null default false,  -- may a trusted server job record it without an actor?
  needs_fy      boolean not null default false,
  validator     regprocedure,    -- function(ww.events) returns ww.events
  projector     regprocedure,    -- function(ww.events) returns void
  description   text not null
);

create or replace function ww.reject(msg text) returns void
language plpgsql as $$
begin
  raise exception 'Chautari rule: %', msg using errcode = 'check_violation';
end $$;

create or replace function ww.validate(e ww.events) returns ww.events
language plpgsql as $$
declare
  t ww.event_types;
  me uuid;
  uid uuid := ww.auth_uid();
begin
  select * into t from ww.event_types where type = e.type;
  if not found then
    perform ww.reject(format('unknown event type "%s"', e.type));
  end if;

  -- actor: a signed-in person acts as themselves; nobody can sign as someone else
  if uid is not null then
    me := ww.current_person();
    if me is null then perform ww.reject('this login is not linked to a registered person'); end if;
    if e.actor is not null and e.actor <> me then
      perform ww.reject('you cannot record an event in someone else''s name');
    end if;
    e.actor := me;
  elsif e.actor is null and not t.bootstrap_ok then
    perform ww.reject(format('"%s" needs a person who records it', e.type));
  end if;

  if e.actor is not null then
    if not exists (select 1 from ww.persons where id = e.actor and ward_id = e.ward_id) then
      perform ww.reject('the person recording this is not registered in this ward');
    end if;
    if t.allowed_roles is not null
       and not ww.has_role(e.entity_id, e.actor, t.allowed_roles || array['admin']) then
      perform ww.reject(format('only %s may record "%s"', array_to_string(t.allowed_roles, ' / '), e.type));
    end if;
  end if;

  if t.needs_fy and e.fiscal_year is null then
    perform ww.reject(format('"%s" needs a fiscal year (e.g. 2083/84)', e.type));
  end if;

  if t.validator is not null then
    execute format('select (%s($1)).*', t.validator::regproc) into e using e;
  end if;
  return e;
end $$;

create or replace function ww.project(e ww.events) returns void
language plpgsql as $$
declare p regprocedure;
begin
  select projector into p from ww.event_types where type = e.type;
  if p is not null then
    execute format('select %s($1)', p::regproc) using e;
  end if;
end $$;

-- small helpers for validators
create or replace function ww.req_text(j jsonb, k text) returns text
language plpgsql as $$
begin
  if j ->> k is null or btrim(j ->> k) = '' then perform ww.reject(format('"%s" is required', k)); end if;
  return j ->> k;
end $$;

create or replace function ww.req_amount(j jsonb, k text) returns numeric
language plpgsql as $$
declare v numeric;
begin
  begin v := (j ->> k)::numeric; exception when others then v := null; end;
  if v is null or v <= 0 then perform ww.reject(format('"%s" must be a positive amount', k)); end if;
  if v <> round(v, 2) then perform ww.reject(format('"%s" has more than 2 decimals', k)); end if;
  return v;
end $$;

create or replace function ww.req_uuid(j jsonb, k text) returns uuid
language plpgsql as $$
declare v uuid;
begin
  begin v := (j ->> k)::uuid; exception when others then v := null; end;
  if v is null then perform ww.reject(format('"%s" must be an id', k)); end if;
  return v;
end $$;

-- ---------------------------------------------------------------------------
-- household.registered / person.registered / role.assigned / role.ended / rule.set
-- ---------------------------------------------------------------------------
create or replace function ww.v_household_registered(e ww.events) returns ww.events
language plpgsql as $$
begin
  perform ww.req_uuid(e.payload, 'household_id');
  if (e.payload ->> 'house_no') !~ '^[0-9]+$' then perform ww.reject('"house_no" must be a number'); end if;
  if exists (select 1 from ww.households where id = (e.payload->>'household_id')::uuid
                or (ward_id = e.ward_id and house_no = (e.payload->>'house_no')::int)) then
    perform ww.reject('this household is already registered');
  end if;
  return e;
end $$;

create or replace function ww.p_household_registered(e ww.events) returns void
language sql as $$
  insert into ww.households (id, ward_id, house_no, tole, registered_seq)
  values ((e.payload->>'household_id')::uuid, e.ward_id, (e.payload->>'house_no')::int,
          e.payload->>'tole', e.seq)
$$;

-- person.registered: payload {} ; private {person_id, display_name, gender, household_id}
-- (the public sees only that a person was registered)
create or replace function ww.v_person_registered(e ww.events) returns ww.events
language plpgsql as $$
begin
  perform ww.req_uuid(e.private, 'person_id');
  if e.payload <> '{}'::jsonb then perform ww.reject('person details belong in the private part'); end if;
  perform ww.req_text(e.private, 'display_name');
  if coalesce(e.private->>'gender', '') not in ('f', 'm', 'o') then
    perform ww.reject('"gender" must be f, m or o');
  end if;
  if e.private ? 'household_id' and not exists
     (select 1 from ww.households where id = (e.private->>'household_id')::uuid and ward_id = e.ward_id) then
    perform ww.reject('unknown household');
  end if;
  if exists (select 1 from ww.persons where id = (e.private->>'person_id')::uuid) then
    perform ww.reject('this person is already registered');
  end if;
  return e;
end $$;

create or replace function ww.p_person_registered(e ww.events) returns void
language sql as $$
  insert into ww.persons (id, ward_id, household_id, display_name, gender, registered_seq)
  values ((e.private->>'person_id')::uuid, e.ward_id, (e.private->>'household_id')::uuid,
          e.private->>'display_name', e.private->>'gender', e.seq)
$$;

-- role.assigned / role.ended: payload {person_id, role, decision_ref}
-- Office holders are public (as on every CFUG notice board).
create or replace function ww.v_role(e ww.events) returns ww.events
language plpgsql as $$
declare pid uuid := ww.req_uuid(e.payload, 'person_id');
begin
  perform ww.req_text(e.payload, 'role');
  if not exists (select 1 from ww.persons where id = pid and ward_id = e.ward_id) then
    perform ww.reject('unknown person');
  end if;
  if e.type = 'role.assigned' then
    -- bootstrap: a server job may appoint the first admin/secretary when no office holders exist
    if e.actor is null and exists (select 1 from ww.role_terms where entity_id = e.entity_id) then
      perform ww.reject('office holders exist: a role must be assigned by the secretary or admin');
    end if;
    if ww.has_role(e.entity_id, pid, array[e.payload->>'role']) then
      perform ww.reject('this person already holds that role');
    end if;
  elsif not ww.has_role(e.entity_id, pid, array[e.payload->>'role']) then
    perform ww.reject('this person does not hold that role');
  end if;
  return e;
end $$;

create or replace function ww.p_role(e ww.events) returns void
language plpgsql as $$
begin
  if e.type = 'role.assigned' then
    insert into ww.role_terms (entity_id, person_id, role, from_seq, started_on)
    values (e.entity_id, (e.payload->>'person_id')::uuid, e.payload->>'role', e.seq, e.occurred_on);
  else
    update ww.role_terms set to_seq = e.seq, ended_on = e.occurred_on
     where entity_id = e.entity_id and person_id = (e.payload->>'person_id')::uuid
       and role = e.payload->>'role' and to_seq is null;
  end if;
end $$;

-- rule.set: payload {key, value, decision_ref}
create or replace function ww.v_rule_set(e ww.events) returns ww.events
language plpgsql as $$
declare d jsonb;
begin
  select value into d from ww.rule_defaults where key = ww.req_text(e.payload, 'key');
  if d is null then perform ww.reject(format('unknown rule "%s"', e.payload->>'key')); end if;
  if not e.payload ? 'value' or jsonb_typeof(e.payload->'value') <> jsonb_typeof(d) then
    perform ww.reject(format('rule "%s" needs a %s value', e.payload->>'key', jsonb_typeof(d)));
  end if;
  if e.actor is not null then perform ww.req_text(e.payload, 'decision_ref'); end if;
  return e;
end $$;

create or replace function ww.p_rule_set(e ww.events) returns void
language sql as $$
  insert into ww.rules_current (entity_id, key, value, set_seq, decision_ref)
  values (e.entity_id, e.payload->>'key', e.payload->'value', e.seq, e.payload->>'decision_ref')
  on conflict (entity_id, key) do update
    set value = excluded.value, set_seq = excluded.set_seq, decision_ref = excluded.decision_ref
$$;

insert into ww.event_types (type, allowed_roles, bootstrap_ok, validator, projector, description) values
 ('household.registered', array['secretary','ledger_keeper'], true,
   'ww.v_household_registered(ww.events)', 'ww.p_household_registered(ww.events)',
   'A household from the CFUG register joins the system'),
 ('person.registered', array['secretary','ledger_keeper'], true,
   'ww.v_person_registered(ww.events)', 'ww.p_person_registered(ww.events)',
   'A person is registered (name and gender stay private)'),
 ('role.assigned', array['secretary'], true, 'ww.v_role(ww.events)', 'ww.p_role(ww.events)',
   'A person takes an office or duty'),
 ('role.ended', array['secretary'], false, 'ww.v_role(ww.events)', 'ww.p_role(ww.events)',
   'A person leaves an office or duty'),
 ('rule.set', array['secretary'], true, 'ww.v_rule_set(ww.events)', 'ww.p_rule_set(ww.events)',
   'The assembly or committee sets a rule (with its decision reference)');
