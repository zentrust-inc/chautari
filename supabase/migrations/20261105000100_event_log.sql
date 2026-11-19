-- Chautari — 0001: the event log and hash chain
-- Everything that happens is one row in ww.events. Rows are never updated or deleted.
-- Each ward has its own gapless sequence and its own SHA-256 chain.
--
-- Privacy by construction: every event has two parts.
--   payload  : facts safe for the public circle (published in the nightly export)
--   private  : personal references (people, households) — never published
-- The chain hashes the public payload text and only a SHA-256 digest of the private
-- part together with the actor, so any witness can verify the whole chain from the
-- public export, while personal details (including who recorded what) stay out of it.

create schema if not exists ww;
comment on schema ww is 'Chautari core: base tables. Not exposed to the API directly.';

-- ---------------------------------------------------------------------------
-- Wards and bodies (CFUG, MPC, Guthi) — configuration, not events
-- ---------------------------------------------------------------------------
create table ww.wards (
  id          text primary key check (id ~ '^[a-z0-9-]+$'),
  name_np     text not null,
  name_en     text not null,
  created_at  timestamptz not null default now()
);

create table ww.entities (
  id          text primary key check (id ~ '^[a-z0-9-]+$'),
  ward_id     text not null references ww.wards(id),
  kind        text not null check (kind in ('cfug', 'mpc', 'guthi')),
  name_np     text not null,
  name_en     text not null,
  source_doc  text,                  -- provenance: which document defines this body
  created_at  timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- The event log
-- ---------------------------------------------------------------------------
create table ww.events (
  ward_id      text        not null references ww.wards(id),
  seq          bigint      not null,
  id           uuid        not null default gen_random_uuid() unique,
  entity_id    text        not null references ww.entities(id),
  type         text        not null check (type ~ '^[a-z]+(\.[a-z_]+)*$'),
  payload      jsonb       not null default '{}'::jsonb,
  private      jsonb       not null default '{}'::jsonb,
  evidence     jsonb       not null default '[]'::jsonb,   -- [{sha256, kind, path}]
  actor        uuid,                                        -- ww.persons.id (null only for bootstrap)
  occurred_on  date        not null,
  fiscal_year  text        check (fiscal_year ~ '^20[0-9]{2}/[0-9]{2}$'),  -- BS, e.g. 2083/84
  recorded_at  timestamptz not null default now(),
  prev_hash    text        not null,
  hash         text        not null unique,
  primary key (ward_id, seq),
  check (jsonb_typeof(payload) = 'object'),
  check (jsonb_typeof(private) = 'object'),
  check (jsonb_typeof(evidence) = 'array')
);
create index events_entity_type on ww.events (entity_id, type);
create index events_payload on ww.events using gin (payload jsonb_path_ops);

comment on table ww.events is 'Insert-only, hash-chained log of everything that happens. Never updated or deleted.';

-- Canonical text that is hashed. The nightly export publishes every field below
-- (private only as its hash) so anyone can recompute the chain.
-- Digest of the parts that are never published: who recorded it, and the private payload.
create or replace function ww.private_digest(e ww.events)
returns text language sql stable as $$
  select encode(sha256(convert_to(coalesce(e.actor::text, '') || '|' || e.private::text, 'UTF8')), 'hex')
$$;

create or replace function ww.canonical(e ww.events)
returns text language sql stable as $$
  select concat_ws('|',
    'wwos-v1',
    e.ward_id,
    e.seq::text,
    e.entity_id,
    e.type,
    to_char(e.occurred_on, 'YYYY-MM-DD'),
    coalesce(e.fiscal_year, ''),
    to_char(e.recorded_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
    e.payload::text,
    ww.private_digest(e),
    e.evidence::text,
    e.prev_hash)
$$;

create or replace function ww.event_hash(e ww.events)
returns text language sql stable as $$
  select encode(sha256(convert_to(ww.canonical(e), 'UTF8')), 'hex')
$$;

-- Validation and projection are filled in by later migrations; start with no-ops.
create or replace function ww.validate(e ww.events) returns ww.events
language plpgsql as $$ begin return e; end $$;

create or replace function ww.project(e ww.events) returns void
language plpgsql as $$ begin return; end $$;

-- BEFORE INSERT: serialise per ward, assign seq and chain, validate, hash.
create or replace function ww.events_before_insert() returns trigger
language plpgsql as $$
declare
  last ww.events;
begin
  -- one writer at a time per ward: gapless seq and an unbroken chain
  perform pg_advisory_xact_lock(hashtext('ww.events:' || new.ward_id));

  if not exists (select 1 from ww.entities where id = new.entity_id and ward_id = new.ward_id) then
    raise exception 'entity % does not belong to ward %', new.entity_id, new.ward_id;
  end if;

  select * into last from ww.events
   where ward_id = new.ward_id order by seq desc limit 1;

  new.seq         := coalesce(last.seq, 0) + 1;
  new.prev_hash   := coalesce(last.hash, repeat('0', 64));
  new.recorded_at := clock_timestamp();   -- the server's clock, never the client's
  new.id          := coalesce(new.id, gen_random_uuid());

  new := ww.validate(new);                 -- may reject, or enrich payload (e.g. voucher no.)
  new.hash := ww.event_hash(new);
  return new;
end $$;

create trigger events_before_insert
  before insert on ww.events
  for each row execute function ww.events_before_insert();

create or replace function ww.events_after_insert() returns trigger
language plpgsql as $$
begin
  perform ww.project(new);
  return null;
end $$;

create trigger events_after_insert
  after insert on ww.events
  for each row execute function ww.events_after_insert();

-- History cannot change: block UPDATE, DELETE and TRUNCATE for everyone, owner included.
create or replace function ww.forbid_change() returns trigger
language plpgsql as $$
begin
  raise exception 'Chautari: % on % is not allowed. Records are corrected with a new "correction" event, never changed or erased.',
    tg_op, tg_table_name using errcode = 'insufficient_privilege';
end $$;

create trigger events_no_update before update or delete on ww.events
  for each row execute function ww.forbid_change();
create trigger events_no_truncate before truncate on ww.events
  for each statement execute function ww.forbid_change();

-- ---------------------------------------------------------------------------
-- Chain check, runnable by anyone with access (the nightly job and witnesses
-- use the same logic on the public export: see scripts/verify-chain.mjs)
-- ---------------------------------------------------------------------------
create or replace function ww.verify_chain(p_ward text)
returns table (ok boolean, checked bigint, first_bad_seq bigint, reason text)
language plpgsql stable as $$
declare
  e ww.events;
  expected_prev text := repeat('0', 64);
  expected_seq bigint := 1;
  n bigint := 0;
begin
  for e in select * from ww.events where ward_id = p_ward order by seq loop
    if e.seq <> expected_seq then
      return query select false, n, e.seq, 'gap in sequence'; return;
    end if;
    if e.prev_hash <> expected_prev then
      return query select false, n, e.seq, 'prev_hash does not match previous event'; return;
    end if;
    if e.hash <> ww.event_hash(e) then
      return query select false, n, e.seq, 'hash does not match content'; return;
    end if;
    expected_prev := e.hash; expected_seq := e.seq + 1; n := n + 1;
  end loop;
  return query select true, n, null::bigint, null::text;
end $$;

-- The latest root (head hash) per ward, published nightly and timestamped.
create or replace view ww.chain_heads as
  select distinct on (ward_id) ward_id, seq as head_seq, hash as head_hash, recorded_at
  from ww.events order by ward_id, seq desc;
