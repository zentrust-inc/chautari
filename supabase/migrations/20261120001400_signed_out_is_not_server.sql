-- Chautari — 0014: a signed-out visitor is not a trusted server job
--
-- Found by the end-to-end test on our own server (20 Nov 2026): the database treated "no signed-in person"
-- (auth.uid() is null) as "a trusted server job". Through the public API a visitor who is not signed in also
-- has no auth.uid(), so officer views (e.g. the worker list) answered them, and record_event would have let
-- them record the event types a server job may record (expenses, role assignments, budgets, ...).
-- On top of that, Supabase by default grants the anon and authenticated roles everything on new tables,
-- views and functions in the public schema; simple public views can then be written through.
--
-- From here on:
--   * ww.is_server(): only a direct database connection (migrations, seed, backups) or the service key (our reader)
--     can be a server job; the anon and authenticated API roles never are. A signed-in person is always that person.
--   * require_office and record_event (ww.validate) use it; a signed-out visitor is refused
--   * ww.harden_public(): the API roles may only SELECT the public views and EXECUTE the functions meant for
--     signed-in people; run at the end of every migration set (deploy/server/setup.sh calls it)

create or replace function ww.is_server() returns boolean
language sql stable as $$
  -- the API sets the role with SET ROLE for every request; SECURITY DEFINER does not change this setting
  select coalesce(nullif(current_setting('role', true), ''), 'none') not in ('anon', 'authenticated')
$$;

create or replace function ww.require_office(p_entity text, p_roles text[]) returns void
language plpgsql stable as $$
declare me uuid := ww.current_person();
begin
  -- a server job: no person signed in, on a direct database connection or with the service key
  if ww.auth_uid() is null and ww.is_server() then return; end if;
  if me is null or not ww.has_role(p_entity, me, p_roles || array['admin']) then
    raise exception 'Chautari: this view is for %', array_to_string(p_roles, ' / ') using errcode = 'insufficient_privilege';
  end if;
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

  -- nobody records anything through the API without signing in
  if uid is null and not ww.is_server() then
    perform ww.reject('sign in first: only a registered person can record');
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

-- What the API roles may do in the public schema, and nothing more. Safe to run again.
create or replace function ww.harden_public() returns void
language plpgsql as $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then return; end if;
  -- tables and views: read only, and only what was granted on purpose (the public views)
  execute 'revoke insert, update, delete, truncate, references, trigger on all tables in schema public from anon, authenticated';
  -- functions: none for a signed-out visitor; the reader's hand-in is for our server (service key) only
  execute 'revoke execute on all functions in schema public from anon';
  if to_regprocedure('public.record_suggestion(text, text, text, text, text, jsonb)') is not null then
    execute 'revoke execute on function public.record_suggestion(text, text, text, text, text, jsonb) from authenticated';
  end if;
  -- the same for objects made later by whoever runs the migrations
  execute 'alter default privileges in schema public revoke insert, update, delete, truncate, references, trigger on tables from anon, authenticated';
  execute 'alter default privileges in schema public revoke execute on functions from anon';
end $$;

select ww.harden_public();
