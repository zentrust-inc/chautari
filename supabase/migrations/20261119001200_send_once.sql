-- Chautari — 0012: entries saved on the phone are recorded once, however often they are sent
--
-- Field forms (work hours, spring and rain readings) are filled in the app, often with no signal.
-- The app keeps each entry on the phone with its own id (client_ref) and sends it when signal returns.
-- If the answer is lost on the way back, the phone sends it again; public.record_event_once then returns
-- the entry already recorded instead of adding a second one. Nothing else changes: the entry still goes
-- through public.record_event and every rule, in the sender's own name.

create table ww.client_refs (
  client_ref  uuid primary key,
  ward_id     text not null references ww.wards(id),
  person_id   uuid not null references ww.persons(id),
  seq         bigint not null,
  received_at timestamptz not null default now()
);
create trigger client_refs_no_update before update or delete on ww.client_refs
  for each row execute function ww.forbid_change();
create trigger client_refs_no_truncate before truncate on ww.client_refs
  for each statement execute function ww.forbid_change();
revoke all on ww.client_refs from public;

create or replace function public.record_event_once(
  p_client_ref  uuid,
  p_entity      text,
  p_type        text,
  p_payload     jsonb default '{}'::jsonb,
  p_private     jsonb default '{}'::jsonb,
  p_occurred_on date  default current_date,
  p_fiscal_year text  default null,
  p_evidence    jsonb default '[]'::jsonb)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := ww.current_person();
  c ww.client_refs;
  e ww.events;
  r jsonb;
begin
  if p_client_ref is null then raise exception 'the entry has no id (client_ref)'; end if;
  if me is null then raise exception 'sign in first'; end if;
  -- two sends of the same entry at once: the second waits for the first, then finds it
  perform pg_advisory_xact_lock(hashtextextended(p_client_ref::text, 0));
  select * into c from ww.client_refs where client_ref = p_client_ref;
  if found then
    if c.person_id <> me then raise exception 'this entry id belongs to someone else'; end if;
    select * into e from ww.events where ward_id = c.ward_id and seq = c.seq;
    return jsonb_build_object('seq', e.seq, 'hash', e.hash, 'voucher_no', e.payload->'voucher_no', 'already', true);
  end if;
  r := public.record_event(p_entity, p_type, p_payload, p_private, p_occurred_on, p_fiscal_year, p_evidence);
  insert into ww.client_refs (client_ref, ward_id, person_id, seq)
  values (p_client_ref, (select ward_id from ww.entities where id = p_entity), me, (r->>'seq')::bigint);
  return r || jsonb_build_object('already', false);
end $$;

revoke all on function public.record_event_once(uuid, text, text, jsonb, jsonb, date, text, jsonb) from public;
do $$ begin
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    execute 'grant execute on function public.record_event_once(uuid, text, text, jsonb, jsonb, date, text, jsonb) to authenticated';
  end if;
end $$;
