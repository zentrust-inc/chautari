-- Chautari — 0013: checks on a bill before anyone confirms it (PRD module 8)
--
--   same_photo        this exact photo is already the evidence of an entry           -> refused
--   same_bill         the same payee and bill number are already recorded            -> refused, unless the
--                     person says why in duplicate_reason_np (public, e.g. "दुई पानाको बिल")
--   same_photo_twice  the same photo is waiting as another suggestion                 -> flag
--   near_photo        a very similar photo was handed in before (another photo of the same bill?) -> flag
--   same_day_amount   same payee, same amount, same date already recorded             -> flag
--   over_price        an item's rate is more than the price list allows (rule price_over_pct) -> flag
--
-- Flags never stop an entry: the person sees them before confirming, the confirmed entry says in public
-- which checks it raised (ai_read.checks), and the accounts committee sees every flagged entry.
-- The village price list is set by the committee with a decision reference (price.set), like any rule.

-- ---------------------------------------------------------------------------
-- The village price list
-- ---------------------------------------------------------------------------
create table ww.price_list (
  entity_id    text not null references ww.entities(id),
  item_np      text not null,
  unit         text not null,
  price        numeric(12,2) not null check (price > 0),
  decision_ref text not null,
  set_seq      bigint not null,
  primary key (entity_id, item_np, unit)
);

insert into ww.rule_defaults (key, value, purpose_np, purpose_en, source) values
 ('price_over_pct', '25', 'बिलमा कुनै वस्तुको दर मूल्यसूचीभन्दा २५% भन्दा बढी भए जाँच्न देखाइन्छ।',
  'A bill item priced more than 25% above the village price list is flagged for checking.', 'Plan (PRD module 8)');

-- price.set: payload {item_np, unit, price, decision_ref}
create or replace function ww.v_price_set(e ww.events) returns ww.events
language plpgsql as $$
begin
  perform ww.req_text(e.payload, 'item_np');
  perform ww.req_text(e.payload, 'unit');
  perform ww.req_amount(e.payload, 'price');
  perform ww.req_text(e.payload, 'decision_ref');
  return e;
end $$;

create or replace function ww.p_price_set(e ww.events) returns void
language sql as $$
  insert into ww.price_list (entity_id, item_np, unit, price, decision_ref, set_seq)
  values (e.entity_id, trim(e.payload->>'item_np'), trim(e.payload->>'unit'), (e.payload->>'price')::numeric,
          e.payload->>'decision_ref', e.seq)
  on conflict (entity_id, item_np, unit) do update
    set price = excluded.price, decision_ref = excluded.decision_ref, set_seq = excluded.set_seq
$$;

insert into ww.event_types (type, allowed_roles, validator, projector, description) values
 ('price.set', array['chair', 'secretary', 'treasurer'], 'ww.v_price_set(ww.events)', 'ww.p_price_set(ww.events)',
  'The committee sets a price on the village price list (with its decision)');

create or replace view public.price_list as
select entity_id, item_np, unit, price, decision_ref from ww.price_list;

-- ---------------------------------------------------------------------------
-- The checks
-- ---------------------------------------------------------------------------
-- an entry that is still live (not corrected away)
create or replace function ww.live_event(w text, s bigint) returns boolean
language sql stable as $$
  select not exists (select 1 from ww.events c where c.ward_id = w and c.type = 'correction'
                     and (c.payload->>'corrects_seq')::bigint = s)
$$;

-- bill numbers compared as written, ignoring spaces, case and Devanagari vs Latin digits
create or replace function ww.norm_no(t text) returns text
language sql immutable as $$
  select nullif(lower(translate(regexp_replace(coalesce(t, ''), '[\s\-/.]', '', 'g'), '०१२३४५६७८९', '0123456789')), '')
$$;
create or replace function ww.norm_name(t text) returns text
language sql immutable as $$
  select lower(regexp_replace(coalesce(t, ''), '[\s[:punct:]]', '', 'g'))
$$;

-- number of differing bits between two 64-bit picture fingerprints (hex)
create or replace function ww.dhash_distance(a text, b text) returns int
language sql immutable as $$
  select case when a ~ '^[0-9a-f]{16}$' and b ~ '^[0-9a-f]{16}$'
    then bit_count(('x' || a)::bit(64) # ('x' || b)::bit(64))::int end
$$;

create or replace function ww.bill_checks(p_suggestion uuid, p_payload jsonb, p_occurred_on date default null)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  s ww.suggestions; w text; out jsonb := '[]'::jsonb; r record;
  bill text := ww.norm_no(p_payload->>'bill_no');
  payee uuid := nullif(p_payload->>'payee_id', '')::uuid;
  amt numeric := case when (p_payload->>'amount') ~ '^[0-9]+(\.[0-9]+)?$' then (p_payload->>'amount')::numeric end;
  pct numeric;
begin
  select * into s from ww.suggestions where id = p_suggestion;
  if not found then return out; end if;
  w := (select ward_id from ww.entities where id = s.entity_id);
  pct := coalesce((ww.rule(s.entity_id, 'price_over_pct'))::text::numeric, 25);

  -- the same photo is already an entry's evidence
  for r in select e.seq from ww.events e
           where e.ward_id = w and e.evidence @> jsonb_build_array(jsonb_build_object('sha256', s.doc_sha256))
             and ww.live_event(e.ward_id, e.seq) limit 1 loop
    out := out || jsonb_build_object('code', 'same_photo', 'block', true, 'seq', r.seq,
      'np', format('यही फोटो इन्ट्री नं. %s को प्रमाण भइसकेको छ।', r.seq),
      'en', format('This same photo is already the evidence of entry %s.', r.seq));
  end loop;

  -- the same photo is waiting as another suggestion
  if exists (select 1 from ww.suggestions o where o.entity_id = s.entity_id and o.id <> s.id and o.doc_sha256 = s.doc_sha256
             and not exists (select 1 from ww.suggestion_decisions d where d.suggestion_id = o.id)) then
    out := out || jsonb_build_object('code', 'same_photo_twice', 'block', false,
      'np', 'यही फोटो अर्को पटक पनि पठाइएको छ; एउटा मात्र लिनुहोस्।',
      'en', 'The same photo was handed in twice; take only one.');
  end if;

  -- a very similar photo handed in before
  for r in select o.id, ww.dhash_distance(s.suggested->>'dhash', o.suggested->>'dhash') as d,
                  (select decision from ww.suggestion_decisions x where x.suggestion_id = o.id) as decision
           from ww.suggestions o
           where o.entity_id = s.entity_id and o.id <> s.id and o.doc_sha256 <> s.doc_sha256
             and ww.dhash_distance(s.suggested->>'dhash', o.suggested->>'dhash') <= 5
           order by 2 limit 1 loop
    out := out || jsonb_build_object('code', 'near_photo', 'block', false, 'distance', r.d,
      'np', 'यस्तै देखिने फोटो पहिले पनि आएको थियो' || case r.decision when 'confirmed' then ' र लिइसकिएको छ' when 'rejected' then ' (नलिइएको)' else ' (पुष्टि पर्खँदै)' end || '। एउटै बिलको दोस्रो फोटो त होइन?',
      'en', 'A very similar photo was handed in before' || case r.decision when 'confirmed' then ' and was taken' when 'rejected' then ' (rejected)' else ' (waiting)' end || '. Is this a second photo of the same bill?');
  end loop;

  -- the same payee and bill number already recorded
  if bill is not null and payee is not null then
    for r in select e.seq from ww.events e join ww.expenses x on x.recorded_seq = e.seq and x.entity_id = e.entity_id
             where e.entity_id = s.entity_id and e.type = 'expense.recorded' and x.status not in ('cancelled', 'reversed')
               and x.payee_id = payee and ww.norm_no(e.payload->>'bill_no') = bill limit 1 loop
      out := out || jsonb_build_object('code', 'same_bill', 'block', true, 'seq', r.seq,
        'np', format('यही पसलको यही बिल नं. इन्ट्री नं. %s मा लेखिइसकेको छ।', r.seq),
        'en', format('This shop''s bill with this number is already recorded as entry %s.', r.seq));
    end loop;
  end if;

  -- same payee, same amount, same day
  if payee is not null and amt is not null and p_occurred_on is not null then
    for r in select e.seq from ww.events e join ww.expenses x on x.recorded_seq = e.seq and x.entity_id = e.entity_id
             where e.entity_id = s.entity_id and e.type = 'expense.recorded' and x.status not in ('cancelled', 'reversed')
               and x.payee_id = payee and x.amount = amt and e.occurred_on = p_occurred_on limit 1 loop
      out := out || jsonb_build_object('code', 'same_day_amount', 'block', false, 'seq', r.seq,
        'np', format('यही पसललाई यही दिन यही रकम इन्ट्री नं. %s मा छ। दोहोरिएको त होइन?', r.seq),
        'en', format('The same amount to the same shop on the same day is entry %s. A duplicate?', r.seq));
    end loop;
  end if;

  -- items above the village price list
  for r in select it->>'name' as name, p.item_np, p.unit, p.price,
                  coalesce(nullif(it->>'rate', '')::numeric,
                           case when nullif(it->>'qty', '')::numeric > 0 then (it->>'amount')::numeric / (it->>'qty')::numeric end) as rate
           from jsonb_array_elements(coalesce(s.suggested->'items', '[]'::jsonb)) it
           join ww.price_list p on p.entity_id = s.entity_id
             and length(ww.norm_name(p.item_np)) >= 2
             and (ww.norm_name(it->>'name') like '%' || ww.norm_name(p.item_np) || '%') loop
    if r.rate is not null and r.rate > r.price * (1 + pct / 100) then
      out := out || jsonb_build_object('code', 'over_price', 'block', false, 'item', r.name,
        'np', format('%s: दर रु %s, मूल्यसूचीमा रु %s/%s (%s%% बढी)।', r.name, round(r.rate), round(r.price), r.unit, round((r.rate / r.price - 1) * 100)),
        'en', format('%s: rate Rs %s, price list Rs %s/%s (%s%% above).', r.name, round(r.rate), round(r.price), r.unit, round((r.rate / r.price - 1) * 100)));
    end if;
  end loop;
  return out;
end $$;

-- the app re-runs the checks while the person fills in the entry (payee and bill number may change)
create or replace function public.check_bill(p_suggestion uuid, p_payload jsonb, p_occurred_on date default null)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  perform ww.require_office((select entity_id from ww.suggestions where id = p_suggestion), ww.reader_roles());
  return ww.bill_checks(p_suggestion, p_payload, p_occurred_on);
end $$;

-- ---------------------------------------------------------------------------
-- Waiting bills now come with their checks
-- ---------------------------------------------------------------------------
drop function public.officer_suggestions(text);
create function public.officer_suggestions(p_entity text)
returns table (suggestion_id uuid, doc_sha256 text, doc_kind text, doc_path text, reader text,
               suggested jsonb, created_at timestamptz, checks jsonb)
language plpgsql stable security definer set search_path = '' as $$
begin
  perform ww.require_office(p_entity, ww.reader_roles());
  return query
  select s.id, s.doc_sha256, s.doc_kind, s.doc_path, s.reader, s.suggested, s.created_at,
         ww.bill_checks(s.id, s.suggested->'payload', nullif(s.suggested->>'occurred_on', '')::date)
  from ww.suggestions s
  where s.entity_id = p_entity
    and not exists (select 1 from ww.suggestion_decisions d where d.suggestion_id = s.id)
  order by s.created_at;
end $$;

-- ---------------------------------------------------------------------------
-- Confirming: blocking checks stop it; every raised check is kept and shown in public by its code
-- ---------------------------------------------------------------------------
alter table ww.suggestion_decisions add column checks jsonb not null default '[]'::jsonb;

create or replace function public.confirm_suggestion(
  p_suggestion uuid, p_type text, p_payload jsonb, p_occurred_on date, p_fiscal_year text,
  p_private jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  s ww.suggestions;
  me uuid := ww.current_person();
  sp jsonb;
  ch text[] := '{}';
  k text;
  payload jsonb;
  r jsonb;
  chk jsonb;
  c jsonb;
  codes text[] := '{}';
begin
  if ww.auth_uid() is null or me is null then
    raise exception 'Chautari rule: a named, signed-in person confirms every entry; the reader cannot' using errcode = 'check_violation';
  end if;
  perform pg_advisory_xact_lock(hashtext('ww.suggestion:' || p_suggestion::text));
  select * into s from ww.suggestions where id = p_suggestion;
  if not found then raise exception 'unknown suggestion'; end if;
  if exists (select 1 from ww.suggestion_decisions where suggestion_id = s.id) then
    raise exception 'Chautari rule: this suggestion is already %',
      (select decision from ww.suggestion_decisions where suggestion_id = s.id) using errcode = 'check_violation';
  end if;
  if p_type not in ('expense.recorded', 'income.recorded') then
    raise exception 'Chautari rule: a bill becomes expense.recorded or income.recorded' using errcode = 'check_violation';
  end if;

  -- the checks, on what the person is about to confirm
  perform pg_advisory_xact_lock(hashtext('ww.bills:' || s.entity_id));   -- two people confirming the same bill at once
  chk := ww.bill_checks(s.id, p_payload, p_occurred_on);
  for c in select * from jsonb_array_elements(chk) loop
    codes := array_append(codes, c->>'code');
    if c->>'code' = 'same_photo' then
      raise exception 'Chautari rule: %', c->>'en' using errcode = 'check_violation';
    end if;
    if c->>'code' = 'same_bill' and length(trim(coalesce(p_payload->>'duplicate_reason_np', ''))) = 0 then
      raise exception 'Chautari rule: % Reject it, or say why it is not a duplicate (duplicate_reason_np).', c->>'en'
        using errcode = 'check_violation';
    end if;
  end loop;

  -- what the person changed, compared with what the reader suggested
  sp := coalesce(s.suggested->'payload', '{}'::jsonb);
  for k in select unnest(array['amount', 'account_code', 'payee_id', 'method', 'budget_line_id', 'memo_np', 'receipt_no', 'bill_no', 'estimated']) loop
    if (sp->k) is distinct from (p_payload->k) and not (sp->k is null and p_payload->k is null) then
      if k = 'amount' and (sp->>k) ~ '^[0-9.]+$' and (p_payload->>k) ~ '^[0-9.]+$'
         and (sp->>k)::numeric = (p_payload->>k)::numeric then continue; end if;
      ch := array_append(ch, k);
    end if;
  end loop;
  if (s.suggested->>'type') is distinct from p_type then ch := array_append(ch, 'type'); end if;
  if (s.suggested->>'occurred_on') is distinct from p_occurred_on::text then ch := array_append(ch, 'date'); end if;

  -- the public part says the reader read it, what the person changed and which checks it raised
  payload := (coalesce(p_payload, '{}'::jsonb) - 'ai_read')
          || jsonb_build_object('ai_read', jsonb_build_object('reader', s.reader, 'suggestion', s.id,
               'changed', to_jsonb(ch), 'checks', to_jsonb(codes)));

  r := public.record_event(s.entity_id, p_type, payload, coalesce(p_private, '{}'::jsonb), p_occurred_on, p_fiscal_year,
         jsonb_build_array(jsonb_build_object('sha256', s.doc_sha256, 'kind', s.doc_kind || '_photo', 'path', s.doc_path)));

  insert into ww.suggestion_decisions (suggestion_id, decision, decided_by, ward_id, event_seq, changed, checks)
  values (s.id, 'confirmed', me, (select ward_id from ww.entities where id = s.entity_id), (r->>'seq')::bigint, ch, chk);

  return r || jsonb_build_object('suggestion', s.id, 'changed', to_jsonb(ch), 'checks', chk);
end $$;

-- ---------------------------------------------------------------------------
-- The accounts committee sees every entry that raised a check
-- ---------------------------------------------------------------------------
create or replace function public.officer_flagged_bills(p_entity text)
returns table (event_seq bigint, occurred_on date, amount numeric, payee text, memo_np text,
               confirmed_by text, checks jsonb, duplicate_reason_np text)
language plpgsql stable security definer set search_path = '' as $$
begin
  perform ww.require_office(p_entity, array['accounts_committee']);
  return query
  select e.seq, e.occurred_on, (e.payload->>'amount')::numeric,
         (select coalesce(py.name, pp.display_name) from ww.payees py left join ww.persons pp on pp.id = py.person_id
           where py.id = (e.payload->>'payee_id')::uuid),
         e.payload->>'memo_np', p.display_name, d.checks, e.payload->>'duplicate_reason_np'
  from ww.suggestion_decisions d
  join ww.suggestions s on s.id = d.suggestion_id
  join ww.events e on e.ward_id = d.ward_id and e.seq = d.event_seq
  join ww.persons p on p.id = d.decided_by
  where s.entity_id = p_entity and d.decision = 'confirmed' and jsonb_array_length(d.checks) > 0
  order by e.seq desc;
end $$;

-- ---------------------------------------------------------------------------
-- Who may call what
-- ---------------------------------------------------------------------------
revoke all on function public.check_bill(uuid, jsonb, date) from public;
revoke all on function public.officer_suggestions(text) from public;
revoke all on function public.officer_flagged_bills(text) from public;
revoke all on public.price_list from public;
do $$ begin
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    execute 'grant execute on function public.check_bill(uuid, jsonb, date) to authenticated';
    execute 'grant execute on function public.officer_suggestions(text) to authenticated';
    execute 'grant execute on function public.officer_flagged_bills(text) to authenticated';
    execute 'grant select on public.price_list to anon, authenticated';
  end if;
end $$;
