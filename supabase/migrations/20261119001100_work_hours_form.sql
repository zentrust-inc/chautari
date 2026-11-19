-- Chautari — 0011: the work-hours form
--
-- The ledger keeper or a supervisor records a worker's hours from the app (काम र घण्टा).
--  * public.officer_workers: the list to pick the worker from (name and house number only, officers only)
--  * work.logged now needs one "before" and one "after" photo, each named by its SHA-256, unless a
--    supervisor records the hours themself. The photos stay on our own server; the chain carries the hashes.
-- Everything else is the rule from 0004: at most 12 hours a person a day, each entry once, and a
-- supervisor approves (never their own or their household's hours).

create or replace function ww.work_photo_ok(ev jsonb, k text) returns boolean
language sql immutable as $$
  select exists (select 1 from jsonb_array_elements(coalesce(ev, '[]'::jsonb)) x
                 where x->>'kind' = k and coalesce(x->>'sha256', '') ~ '^[0-9a-f]{64}$')
$$;

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
  -- before and after photos, unless the supervisor records the hours themself
  if not ww.has_role(e.entity_id, e.actor, array['supervisor'])
     and not (ww.work_photo_ok(e.evidence, 'before') and ww.work_photo_ok(e.evidence, 'after')) then
    perform ww.reject('attach the before/after photos taken in the form');
  end if;
  if coalesce((select sum(hours) from ww.work_logs
       where person_id = (e.private->>'person_id')::uuid and work_date = e.occurred_on and status <> 'cancelled'), 0) + h > 12 then
    perform ww.reject('this person would have more than 12 hours on that day');
  end if;
  return e;
end $$;

-- Who the hours can be written for: the people of the ward, by name and house number.
-- Only the ledger keeper and supervisors see it, and only while they hold the office.
create or replace function public.officer_workers(p_entity text)
returns table (person_id uuid, name text, house_no int)
language plpgsql stable security definer set search_path = '' as $$
begin
  perform ww.require_office(p_entity, array['ledger_keeper', 'supervisor']);
  return query
  select p.id, p.display_name, h.house_no
  from ww.persons p left join ww.households h on h.id = p.household_id
  where p.ward_id = (select ward_id from ww.entities where id = p_entity)
  order by h.house_no nulls last, p.display_name;
end $$;

revoke all on function public.officer_workers(text) from public;
do $$ begin
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    execute 'grant execute on function public.officer_workers(text) to authenticated';
  end if;
end $$;

update ww.event_types set description = 'Hours of work, with before/after photos and output' where type = 'work.logged';
