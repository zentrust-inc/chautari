-- Chautari — 0010: the document reader's suggestions, and a person's confirmation
--
-- The reader (reader/ in this repository, Tesseract on our own server) reads a photo of a bill and
-- suggests an entry. The suggestion is kept exactly as the reader made it. A named person then
-- confirms it (perhaps after correcting it) or rejects it. Only that person's confirmation creates an
-- event in the chain, through the same rules as any other entry.
--
--   The reader can only suggest. It cannot record, sign, approve or change anything.
--   Suggestions and decisions are insert-only, like the events.
--   The confirmed event says, in public, that the reader read it and which fields the person changed.
--   The photo itself stays on our server; the chain carries only its SHA-256 fingerprint.

create table ww.suggestions (
  id          uuid primary key default gen_random_uuid(),
  entity_id   text not null references ww.entities(id),
  doc_sha256  text not null check (doc_sha256 ~ '^[0-9a-f]{64}$'),
  doc_kind    text not null check (doc_kind in ('bill', 'receipt')),
  doc_path    text not null check (doc_path ~ '^[A-Za-z0-9._/-]+$'),  -- where the photo is kept on our server
  reader      text not null,                    -- e.g. chautari-reader/0.1.0 (tesseract 5.3.4)
  suggested   jsonb not null check (jsonb_typeof(suggested) = 'object'),
              -- {type, payload, occurred_on, fiscal_year, fields: {name: {value, status, why}}, flags: [...]}
  created_at  timestamptz not null default clock_timestamp()
);
create index suggestions_entity on ww.suggestions (entity_id, created_at);
comment on table ww.suggestions is 'What the document reader suggested, exactly as it suggested it. Never changed.';

create table ww.suggestion_decisions (
  suggestion_id uuid primary key references ww.suggestions(id),   -- one decision per suggestion
  decision      text not null check (decision in ('confirmed', 'rejected')),
  decided_by    uuid not null references ww.persons(id),
  ward_id       text,
  event_seq     bigint,
  changed       text[] not null default '{}',
  reason        text,
  decided_at    timestamptz not null default clock_timestamp(),
  check ((decision = 'confirmed') = (event_seq is not null)),
  check (decision = 'confirmed' or length(trim(coalesce(reason, ''))) > 0),
  foreign key (ward_id, event_seq) references ww.events (ward_id, seq)
);
comment on table ww.suggestion_decisions is 'A named person confirmed or rejected a suggestion. Never changed.';

create trigger suggestions_no_update before update or delete on ww.suggestions
  for each row execute function ww.forbid_change();
create trigger suggestions_no_truncate before truncate on ww.suggestions
  for each statement execute function ww.forbid_change();
create trigger suggestion_decisions_no_update before update or delete on ww.suggestion_decisions
  for each row execute function ww.forbid_change();
create trigger suggestion_decisions_no_truncate before truncate on ww.suggestion_decisions
  for each statement execute function ww.forbid_change();

-- who may confirm what a bill says: the people who may record money in and out
create or replace function ww.reader_roles() returns text[] language sql immutable as $$
  select array['treasurer', 'ledger_keeper']
$$;

-- ---------------------------------------------------------------------------
-- The reader hands in a suggestion (our server only, with the service key)
-- ---------------------------------------------------------------------------
create or replace function public.record_suggestion(
  p_entity text, p_doc_sha256 text, p_doc_kind text, p_doc_path text, p_reader text, p_suggested jsonb)
returns uuid language plpgsql security definer set search_path = '' as $$
declare sid uuid;
begin
  if not exists (select 1 from ww.entities where id = p_entity) then raise exception 'unknown body %', p_entity; end if;
  if coalesce(p_suggested->>'type', '') not in ('expense.recorded', 'income.recorded') then
    raise exception 'Chautari rule: the reader suggests only expense.recorded or income.recorded' using errcode = 'check_violation';
  end if;
  insert into ww.suggestions (entity_id, doc_sha256, doc_kind, doc_path, reader, suggested)
  values (p_entity, lower(p_doc_sha256), p_doc_kind, p_doc_path, p_reader, p_suggested)
  returning id into sid;
  return sid;
end $$;

-- ---------------------------------------------------------------------------
-- Officers see what is waiting
-- ---------------------------------------------------------------------------
create or replace function public.officer_suggestions(p_entity text)
returns table (suggestion_id uuid, doc_sha256 text, doc_kind text, doc_path text, reader text,
               suggested jsonb, created_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
begin
  perform ww.require_office(p_entity, ww.reader_roles());
  return query
  select s.id, s.doc_sha256, s.doc_kind, s.doc_path, s.reader, s.suggested, s.created_at
  from ww.suggestions s
  where s.entity_id = p_entity
    and not exists (select 1 from ww.suggestion_decisions d where d.suggestion_id = s.id)
  order by s.created_at;
end $$;

-- ---------------------------------------------------------------------------
-- A person confirms: the entry goes through record_event's rules, in their own name
-- ---------------------------------------------------------------------------
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

  -- what the person changed, compared with what the reader suggested
  sp := coalesce(s.suggested->'payload', '{}'::jsonb);
  for k in select unnest(array['amount', 'account_code', 'payee_id', 'method', 'budget_line_id', 'memo_np', 'receipt_no', 'estimated']) loop
    if (sp->k) is distinct from (p_payload->k) and not (sp->k is null and p_payload->k is null) then
      -- 7900 and 7900.00 are the same amount
      if k = 'amount' and (sp->>k) ~ '^[0-9.]+$' and (p_payload->>k) ~ '^[0-9.]+$'
         and (sp->>k)::numeric = (p_payload->>k)::numeric then continue; end if;
      ch := array_append(ch, k);
    end if;
  end loop;
  if (s.suggested->>'type') is distinct from p_type then ch := array_append(ch, 'type'); end if;
  if (s.suggested->>'occurred_on') is distinct from p_occurred_on::text then ch := array_append(ch, 'date'); end if;

  -- the public part says the reader read it and what the person changed; nobody can write this themselves
  payload := (coalesce(p_payload, '{}'::jsonb) - 'ai_read')
          || jsonb_build_object('ai_read', jsonb_build_object('reader', s.reader, 'suggestion', s.id, 'changed', to_jsonb(ch)));

  r := public.record_event(s.entity_id, p_type, payload, coalesce(p_private, '{}'::jsonb), p_occurred_on, p_fiscal_year,
         jsonb_build_array(jsonb_build_object('sha256', s.doc_sha256, 'kind', s.doc_kind || '_photo', 'path', s.doc_path)));

  insert into ww.suggestion_decisions (suggestion_id, decision, decided_by, ward_id, event_seq, changed)
  values (s.id, 'confirmed', me, (select ward_id from ww.entities where id = s.entity_id), (r->>'seq')::bigint, ch);

  return r || jsonb_build_object('suggestion', s.id, 'changed', to_jsonb(ch));
end $$;

create or replace function public.reject_suggestion(p_suggestion uuid, p_reason text)
returns void language plpgsql security definer set search_path = '' as $$
declare s ww.suggestions; me uuid := ww.current_person();
begin
  if ww.auth_uid() is null or me is null then
    raise exception 'Chautari rule: a named, signed-in person decides' using errcode = 'check_violation';
  end if;
  select * into s from ww.suggestions where id = p_suggestion;
  if not found then raise exception 'unknown suggestion'; end if;
  perform ww.require_office(s.entity_id, ww.reader_roles());
  if length(trim(coalesce(p_reason, ''))) = 0 then
    raise exception 'Chautari rule: say why it is rejected (e.g. not our bill, a duplicate, unreadable)' using errcode = 'check_violation';
  end if;
  perform pg_advisory_xact_lock(hashtext('ww.suggestion:' || p_suggestion::text));
  if exists (select 1 from ww.suggestion_decisions where suggestion_id = s.id) then
    raise exception 'Chautari rule: this suggestion is already decided' using errcode = 'check_violation';
  end if;
  insert into ww.suggestion_decisions (suggestion_id, decision, decided_by, changed, reason)
  values (s.id, 'rejected', me, '{}', p_reason);
end $$;

-- ---------------------------------------------------------------------------
-- How well the reader does, in public: counts only, no bills, no people
-- ---------------------------------------------------------------------------
create or replace view public.reader_record as
select s.entity_id,
       count(*)                                                             as suggested,
       count(d.*) filter (where d.decision = 'confirmed')                   as confirmed,
       count(d.*) filter (where d.decision = 'confirmed' and d.changed = '{}') as confirmed_unchanged,
       count(d.*) filter (where d.decision = 'confirmed' and d.changed <> '{}') as confirmed_corrected,
       count(d.*) filter (where d.decision = 'rejected')                    as rejected,
       count(*) filter (where d.suggestion_id is null)                      as waiting
from ww.suggestions s left join ww.suggestion_decisions d on d.suggestion_id = s.id
group by s.entity_id;

-- ---------------------------------------------------------------------------
-- Who may call what
-- ---------------------------------------------------------------------------
revoke all on public.reader_record from public;
revoke all on function public.record_suggestion(text, text, text, text, text, jsonb) from public;
revoke all on function public.officer_suggestions(text) from public;
revoke all on function public.confirm_suggestion(uuid, text, jsonb, date, text, jsonb) from public;
revoke all on function public.reject_suggestion(uuid, text) from public;
do $$ begin
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    execute 'revoke all on public.reader_record from anon, authenticated';
    execute 'grant select on public.reader_record to anon, authenticated';
    execute 'grant execute on function public.record_suggestion(text, text, text, text, text, jsonb) to service_role';
    execute 'grant execute on function public.officer_suggestions(text) to authenticated';
    execute 'grant execute on function public.confirm_suggestion(uuid, text, jsonb, date, text, jsonb) to authenticated';
    execute 'grant execute on function public.reject_suggestion(uuid, text) to authenticated';
  end if;
end $$;
