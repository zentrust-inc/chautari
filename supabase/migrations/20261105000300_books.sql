-- Chautari — 0003: the books
-- Double-entry books in the form the CFUG financial procedure directive requires
-- (सामुदायिक वन उपभोक्ता समूहको आर्थिक कार्यविधि निर्देशिका): account codes from its
-- annexes 5 and 6, summary vouchers (गोस्वारा भौचर), cash book, income and expense ledgers.
-- Postings are derived from events inside the same transaction and are insert-only.

-- ---------------------------------------------------------------------------
-- Chart of accounts
-- ---------------------------------------------------------------------------
create table ww.accounts (
  entity_kind     text not null check (entity_kind in ('cfug', 'mpc', 'guthi')),
  code            text not null,
  kind            text not null check (kind in ('asset', 'liability', 'income', 'expense')),
  directive_code  text,                      -- as printed on the voucher, e.g. '२.०१'
  name_np         text not null,
  name_en         text not null,
  spend_category  text check (spend_category in ('forest', 'pro_poor', 'social_admin')),
  source          text not null,
  primary key (entity_kind, code)
);

insert into ww.accounts (entity_kind, code, kind, directive_code, name_np, name_en, spend_category, source) values
 -- balance-sheet accounts
 ('cfug','BS-CASH','asset',    null,'नगद',                 'Cash in hand',            null,'Directive annex 7 (cash book)'),
 ('cfug','BS-BANK','asset',    null,'बैङ्क',                 'Bank account',            null,'Directive s.13'),
 ('cfug','BS-ADV', 'asset',    null,'पेस्की',                'Advances',                null,'Directive chapter 7'),
 ('cfug','BS-DEP', 'liability',null,'धरौटी',                'Security deposits held',  null,'Directive s.15'),
 -- income heads (directive annex 5)
 ('cfug','IN-1.01','income','१.०१','बैङ्क मौज्दात (अघिल्लो वर्षको बाँकी)','Opening bank balance', null,'Directive annex 5'),
 ('cfug','IN-1.02','income','१.०२','नगद मौज्दात (अघिल्लो वर्षको बाँकी)','Opening cash balance', null,'Directive annex 5'),
 ('cfug','IN-2.01','income','२.०१','काठ बिक्री',             'Timber sales',            null,'Directive annex 5'),
 ('cfug','IN-2.02','income','२.०२','खाँबा (पोल) बिक्री',      'Pole sales',              null,'Directive annex 5'),
 ('cfug','IN-2.03','income','२.०३','दाउरा बिक्री',            'Firewood sales',          null,'Directive annex 5'),
 ('cfug','IN-2.04','income','२.०४','कृषि औजार बिक्री',        'Farm-tool wood sales',    null,'Directive annex 5'),
 ('cfug','IN-2.05','income','२.०५','घाँस र स्याउला बिक्री',    'Grass and leaf-litter sales', null,'Directive annex 5'),
 ('cfug','IN-2.06','income','२.०६','जडीबुटी र अन्य गैरकाष्ठ बिक्री','Herbs and other non-timber sales (incl. resin)', null,'Directive annex 5'),
 ('cfug','IN-3.01','income','३.०१','सरकारी अनुदान',          'Government grants',       null,'Directive annex 5'),
 ('cfug','IN-3.02','income','३.०२','गैर सरकारी अनुदान',       'Non-government grants',   null,'Directive annex 5'),
 ('cfug','IN-3.03','income','३.०३','अन्य अनुदान (व्यक्तिगतसमेत)','Other grants and gifts', null,'Directive annex 5'),
 ('cfug','IN-4.00','income','४.००','दण्ड जरिवाना',            'Fines',                   null,'Directive annex 5'),
 ('cfug','IN-5.01','income','५.०१','प्रवेश शुल्क',            'Entry fees',              null,'Directive annex 5'),
 ('cfug','IN-5.02','income','५.०२','सदस्यता शुल्क',           'Membership fees',         null,'Directive annex 5'),
 ('cfug','IN-5.03','income','५.०३','नवीकरण शुल्क',            'Annual renewal fees',     null,'Directive annex 5'),
 ('cfug','IN-6.00','income','६.००','ऋण',                    'Loans received',          null,'Directive annex 5'),
 ('cfug','IN-7.00','income','७.००','अन्य आय (पुरस्कार, ब्याजसमेत)','Other income (awards, interest)', null,'Directive annex 5'),
 -- expense heads (directive annex 6)
 ('cfug','EX-1.01','expense','१.०१','तलब, भत्ता',             'Salaries and allowances', 'social_admin','Directive annex 6'),
 ('cfug','EX-1.02','expense','१.०२','बैठक, चियापान',          'Meetings and tea',        'social_admin','Directive annex 6'),
 ('cfug','EX-1.03','expense','१.०३','तालिम, गोष्ठी, अध्ययन भ्रमण','Training, workshops, study visits','social_admin','Directive annex 6'),
 ('cfug','EX-1.04','expense','१.०४','स्टेशनरी, छपाई',         'Stationery and printing', 'social_admin','Directive annex 6'),
 ('cfug','EX-1.05','expense','१.०५','पानी, बिजुली र टेलिफोन',  'Water, electricity, phone','social_admin','Directive annex 6'),
 ('cfug','EX-1.06','expense','१.०६','भाडा, औजार',             'Rent and tools',          'social_admin','Directive annex 6'),
 ('cfug','EX-1.07','expense','१.०७','कार्यालय सामान',          'Office equipment',        'social_admin','Directive annex 6'),
 ('cfug','EX-1.08','expense','१.०८','विविध (लेखा परीक्षण शुल्क, इन्धन आदि)','Miscellaneous (audit fee, fuel, other)','social_admin','Directive annex 6'),
 ('cfug','EX-2.01','expense','२.०१','वन संरक्षण',             'Forest protection (guards, fire, fencing, soil conservation)','forest','Directive annex 6'),
 ('cfug','EX-2.02','expense','२.०२','वन विकास',               'Forest development (nursery, planting, income programmes)','forest','Directive annex 6'),
 ('cfug','EX-2.03','expense','२.०३','वन सदुपयोग',             'Forest use (survey, harvesting)','forest','Directive annex 6'),
 ('cfug','EX-3.01','expense','३.०१','संस्थागत विकास',          'Institutional development','social_admin','Directive annex 6'),
 ('cfug','EX-3.02','expense','३.०२','सामुदायिक विकास',         'Community development (ponds, paths, taps, training)','social_admin','Directive annex 6'),
 ('cfug','EX-4.00','expense','४.००','विपन्न वर्ग लक्षित जीविकोपार्जन','Livelihoods for poor households','pro_poor','Directive annex 6'),
 ('cfug','EX-5.00','expense','५.००','अनुदान, क्षतिपूर्ति, सहयोग','Grants, compensation, support','social_admin','Directive annex 6'),
 ('cfug','EX-6.00','expense','६.००','अन्य',                   'Other',                   'social_admin','Directive annex 6');

create or replace function ww.entity_kind(p_entity text) returns text
language sql stable as $$ select kind from ww.entities where id = p_entity $$;

create or replace function ww.account(p_entity text, p_code text) returns ww.accounts
language sql stable as $$
  select * from ww.accounts where entity_kind = ww.entity_kind(p_entity) and code = p_code
$$;

-- ---------------------------------------------------------------------------
-- Postings (derived from events; insert-only; every event balances)
-- ---------------------------------------------------------------------------
create table ww.postings (
  id           bigserial primary key,
  ward_id      text not null,
  entity_id    text not null references ww.entities(id),
  event_seq    bigint not null,
  voucher_no   int not null,
  fiscal_year  text not null,
  occurred_on  date not null,
  account_code text not null,
  debit        numeric(14,2) not null default 0 check (debit >= 0),
  credit       numeric(14,2) not null default 0 check (credit >= 0),
  narrative_np text,
  check ((debit > 0) <> (credit > 0)),
  foreign key (ward_id, event_seq) references ww.events (ward_id, seq)
);
create index postings_entity_fy on ww.postings (entity_id, fiscal_year, account_code);
create index postings_event on ww.postings (ward_id, event_seq);

create trigger postings_no_update before update or delete on ww.postings
  for each row execute function ww.forbid_change();
create trigger postings_no_truncate before truncate on ww.postings
  for each statement execute function ww.forbid_change();

create or replace function ww.postings_balanced() returns trigger
language plpgsql as $$
declare d numeric; c numeric;
begin
  select sum(debit), sum(credit) into d, c from ww.postings
   where ward_id = new.ward_id and event_seq = new.event_seq;
  if d <> c then
    raise exception 'Chautari: event % does not balance (debit %, credit %)', new.event_seq, d, c;
  end if;
  return null;
end $$;

create constraint trigger postings_balanced after insert on ww.postings
  deferrable initially deferred for each row execute function ww.postings_balanced();

create or replace function ww.post(e ww.events, p_code text, p_debit numeric, p_credit numeric, p_narr text)
returns void language plpgsql as $$
begin
  if (ww.account(e.entity_id, p_code)).code is null then
    perform ww.reject(format('unknown account %s', p_code));
  end if;
  insert into ww.postings (ward_id, entity_id, event_seq, voucher_no, fiscal_year, occurred_on,
                           account_code, debit, credit, narrative_np)
  values (e.ward_id, e.entity_id, e.seq, (e.payload->>'voucher_no')::int, e.fiscal_year,
          e.occurred_on, p_code, p_debit, p_credit, p_narr);
end $$;

create or replace function ww.balance(p_entity text, p_code text) returns numeric
language sql stable as $$
  select coalesce(sum(debit - credit), 0) from ww.postings where entity_id = p_entity and account_code = p_code
$$;

-- Next summary-voucher number for the body and fiscal year (serialised by the ward lock).
create or replace function ww.next_voucher(p_entity text, p_fy text) returns int
language sql stable as $$
  select coalesce(max(voucher_no), 0) + 1 from ww.postings where entity_id = p_entity and fiscal_year = p_fy
$$;

create or replace function ww.with_voucher(e ww.events) returns ww.events
language plpgsql as $$
begin
  if e.fiscal_year is null then perform ww.reject('a fiscal year is needed for an entry in the books'); end if;
  e.payload := e.payload || jsonb_build_object('voucher_no', ww.next_voucher(e.entity_id, e.fiscal_year));
  return e;
end $$;

create or replace function ww.req_method(j jsonb) returns text
language plpgsql as $$
begin
  if coalesce(j->>'method', '') not in ('cash', 'bank') then
    perform ww.reject('"method" must be cash or bank');
  end if;
  return j->>'method';
end $$;

create or replace function ww.money_account(p_method text) returns text
language sql immutable as $$ select case p_method when 'cash' then 'BS-CASH' else 'BS-BANK' end $$;

-- ---------------------------------------------------------------------------
-- Budget lines, payees, expenses (projections)
-- ---------------------------------------------------------------------------
create table ww.budget_lines (
  id            uuid primary key,
  entity_id     text not null references ww.entities(id),
  fiscal_year   text not null,
  account_code  text not null,
  amount        numeric(14,2) not null,
  title_np      text not null,
  spend_category text not null,
  decision_ref  text not null,
  approved_seq  bigint not null,
  cancelled_seq bigint            -- set when the approval is corrected; the line then takes no spending
);

create table ww.payees (
  id            uuid primary key,
  entity_id     text not null references ww.entities(id),
  kind          text not null check (kind in ('shop', 'contractor', 'organisation', 'person')),
  name          text,                 -- shops, contractors and organisations are public by name
  person_id     uuid references ww.persons(id),   -- for a person: private
  registered_seq bigint not null
);

create table ww.expenses (
  id             uuid primary key,
  entity_id      text not null references ww.entities(id),
  recorded_seq   bigint not null,
  recorded_by    uuid,
  fiscal_year    text not null,
  amount         numeric(14,2) not null,
  account_code   text not null,
  payee_id       uuid not null references ww.payees(id),
  method         text not null,
  budget_line_id uuid references ww.budget_lines(id),
  estimated      boolean not null default false,
  memo_np        text not null,
  status         text not null default 'pending' check (status in ('pending', 'paid', 'cancelled', 'reversed')),
  status_seq     bigint not null
);

create table ww.expense_approvals (
  expense_id   uuid not null references ww.expenses(id),
  person_id    uuid not null references ww.persons(id),
  as_role      text not null,
  event_seq    bigint not null,
  primary key (expense_id, person_id)
);

-- ---------------------------------------------------------------------------
-- Validators and projectors
-- ---------------------------------------------------------------------------

-- balance.opened: payload {cash, bank} — carried forward from the previous year's books
create or replace function ww.v_balance_opened(e ww.events) returns ww.events
language plpgsql as $$
declare c numeric := coalesce((e.payload->>'cash')::numeric, 0);
        b numeric := coalesce((e.payload->>'bank')::numeric, 0);
begin
  if c < 0 or b < 0 or c + b = 0 then perform ww.reject('opening cash and bank must be positive amounts'); end if;
  if exists (select 1 from ww.events where entity_id = e.entity_id and type = 'balance.opened'
               and fiscal_year = e.fiscal_year) then
    perform ww.reject('opening balances for this fiscal year are already recorded');
  end if;
  return ww.with_voucher(e);
end $$;

create or replace function ww.p_balance_opened(e ww.events) returns void
language plpgsql as $$
declare c numeric := coalesce((e.payload->>'cash')::numeric, 0);
        b numeric := coalesce((e.payload->>'bank')::numeric, 0);
begin
  if c > 0 then perform ww.post(e, 'BS-CASH', c, 0, 'अघिल्लो वर्षको नगद मौज्दात');
                perform ww.post(e, 'IN-1.02', 0, c, 'अघिल्लो वर्षको नगद मौज्दात'); end if;
  if b > 0 then perform ww.post(e, 'BS-BANK', b, 0, 'अघिल्लो वर्षको बैङ्क मौज्दात');
                perform ww.post(e, 'IN-1.01', 0, b, 'अघिल्लो वर्षको बैङ्क मौज्दात'); end if;
end $$;

-- budget.approved: payload {line_id, account_code, amount, title_np, decision_ref, category?}
create or replace function ww.v_budget_approved(e ww.events) returns ww.events
language plpgsql as $$
declare a ww.accounts;
begin
  perform ww.req_uuid(e.payload, 'line_id');
  perform ww.req_amount(e.payload, 'amount');
  perform ww.req_text(e.payload, 'title_np');
  perform ww.req_text(e.payload, 'decision_ref');
  a := ww.account(e.entity_id, ww.req_text(e.payload, 'account_code'));
  if a.kind is distinct from 'expense' then perform ww.reject('a budget line needs an expense account'); end if;
  if e.payload ? 'category' and e.payload->>'category' not in ('forest', 'pro_poor', 'social_admin') then
    perform ww.reject('category must be forest, pro_poor or social_admin');
  end if;
  if exists (select 1 from ww.budget_lines where id = (e.payload->>'line_id')::uuid) then
    perform ww.reject('this budget line already exists');
  end if;
  e.payload := e.payload || jsonb_build_object('category', coalesce(e.payload->>'category', a.spend_category));
  return e;
end $$;

create or replace function ww.p_budget_approved(e ww.events) returns void
language sql as $$
  insert into ww.budget_lines (id, entity_id, fiscal_year, account_code, amount, title_np, spend_category, decision_ref, approved_seq)
  values ((e.payload->>'line_id')::uuid, e.entity_id, e.fiscal_year, e.payload->>'account_code',
          (e.payload->>'amount')::numeric, e.payload->>'title_np', e.payload->>'category',
          e.payload->>'decision_ref', e.seq)
$$;

-- payee.registered: payload {payee_id, kind, name}; private {person_id} for a person
create or replace function ww.v_payee_registered(e ww.events) returns ww.events
language plpgsql as $$
begin
  perform ww.req_uuid(e.payload, 'payee_id');
  if coalesce(e.payload->>'kind', '') not in ('shop', 'contractor', 'organisation', 'person') then
    perform ww.reject('payee kind must be shop, contractor, organisation or person');
  end if;
  if e.payload->>'kind' = 'person' then
    if e.payload ? 'name' then perform ww.reject('a person''s name goes in the private part, not the public one'); end if;
    if not exists (select 1 from ww.persons where id = ww.req_uuid(e.private, 'person_id') and ward_id = e.ward_id) then
      perform ww.reject('unknown person');
    end if;
  else
    perform ww.req_text(e.payload, 'name');
  end if;
  if exists (select 1 from ww.payees where id = (e.payload->>'payee_id')::uuid) then
    perform ww.reject('this payee is already registered');
  end if;
  return e;
end $$;

create or replace function ww.p_payee_registered(e ww.events) returns void
language sql as $$
  insert into ww.payees (id, entity_id, kind, name, person_id, registered_seq)
  values ((e.payload->>'payee_id')::uuid, e.entity_id, e.payload->>'kind', e.payload->>'name',
          (e.private->>'person_id')::uuid, e.seq)
$$;

-- income.recorded: payload {amount, account_code, method, receipt_no, memo_np}
create or replace function ww.v_income_recorded(e ww.events) returns ww.events
language plpgsql as $$
declare amt numeric := ww.req_amount(e.payload, 'amount');
        a ww.accounts := ww.account(e.entity_id, ww.req_text(e.payload, 'account_code'));
begin
  if a.kind is distinct from 'income' or a.code in ('IN-1.01', 'IN-1.02') then
    perform ww.reject('income needs an income account (opening balances use balance.opened)');
  end if;
  if ww.req_method(e.payload) = 'cash' and amt > (ww.rule(e.entity_id, 'cash_receipt_max'))::numeric then
    perform ww.reject(format('cash above Rs %s must come through the bank', ww.rule(e.entity_id, 'cash_receipt_max')));
  end if;
  perform ww.req_text(e.payload, 'receipt_no');
  return ww.with_voucher(e);
end $$;

create or replace function ww.p_income_recorded(e ww.events) returns void
language plpgsql as $$
declare amt numeric := (e.payload->>'amount')::numeric;
begin
  perform ww.post(e, ww.money_account(e.payload->>'method'), amt, 0, e.payload->>'memo_np');
  perform ww.post(e, e.payload->>'account_code', 0, amt, e.payload->>'memo_np');
end $$;

-- cash.banked: payload {amount, bank_ref}
create or replace function ww.v_cash_banked(e ww.events) returns ww.events
language plpgsql as $$
declare amt numeric := ww.req_amount(e.payload, 'amount');
begin
  if amt > ww.balance(e.entity_id, 'BS-CASH') then perform ww.reject('more than the cash in hand'); end if;
  perform ww.req_text(e.payload, 'bank_ref');
  return ww.with_voucher(e);
end $$;

create or replace function ww.p_cash_banked(e ww.events) returns void
language plpgsql as $$
declare amt numeric := (e.payload->>'amount')::numeric;
begin
  perform ww.post(e, 'BS-BANK', amt, 0, 'नगद बैङ्क दाखिला');
  perform ww.post(e, 'BS-CASH', 0, amt, 'नगद बैङ्क दाखिला');
end $$;

-- expense.recorded: payload {expense_id, amount, account_code, payee_id, method, budget_line_id?, estimated?, memo_np}
-- Recording is not paying: nothing reaches the books until payment.released.
create or replace function ww.v_expense_recorded(e ww.events) returns ww.events
language plpgsql as $$
declare amt numeric := ww.req_amount(e.payload, 'amount');
        a ww.accounts := ww.account(e.entity_id, ww.req_text(e.payload, 'account_code'));
        line ww.budget_lines;
        est boolean := coalesce((e.payload->>'estimated')::boolean, false);
begin
  perform ww.req_uuid(e.payload, 'expense_id');
  perform ww.req_method(e.payload);
  perform ww.req_text(e.payload, 'memo_np');
  if a.kind is distinct from 'expense' then perform ww.reject('an expense needs an expense account'); end if;
  if not exists (select 1 from ww.payees where id = ww.req_uuid(e.payload, 'payee_id') and entity_id = e.entity_id) then
    perform ww.reject('payments only go to a registered payee');
  end if;
  if exists (select 1 from ww.expenses where id = (e.payload->>'expense_id')::uuid) then
    perform ww.reject('this expense is already recorded');
  end if;
  if e.payload->>'budget_line_id' is not null then
    select * into line from ww.budget_lines where id = (e.payload->>'budget_line_id')::uuid and entity_id = e.entity_id;
    if not found then perform ww.reject('unknown budget line'); end if;
    if line.cancelled_seq is not null then perform ww.reject('this budget line was withdrawn'); end if;
    if line.fiscal_year <> e.fiscal_year then perform ww.reject('the budget line is for another fiscal year'); end if;
    if line.account_code <> a.code then perform ww.reject('the expense account does not match its budget line'); end if;
  elsif amt > (ww.rule(e.entity_id, 'unbudgeted_item_max'))::numeric then
    perform ww.reject(format('unbudgeted spending above Rs %s needs the general assembly', ww.rule(e.entity_id, 'unbudgeted_item_max')));
  end if;
  if not est and jsonb_array_length(e.evidence) = 0 and not (e.payload ? 'work_ids') then
    perform ww.reject('attach the receipt photo, or mark the expense as estimated (lost receipt)');
  end if;
  e.payload := e.payload || jsonb_build_object('estimated', est);
  return e;
end $$;

create or replace function ww.p_expense_recorded(e ww.events) returns void
language sql as $$
  insert into ww.expenses (id, entity_id, recorded_seq, recorded_by, fiscal_year, amount, account_code,
                           payee_id, method, budget_line_id, estimated, memo_np, status_seq)
  values ((e.payload->>'expense_id')::uuid, e.entity_id, e.seq, e.actor, e.fiscal_year,
          (e.payload->>'amount')::numeric, e.payload->>'account_code', (e.payload->>'payee_id')::uuid,
          e.payload->>'method', (e.payload->>'budget_line_id')::uuid,
          (e.payload->>'estimated')::boolean, e.payload->>'memo_np', e.seq)
$$;

-- payment.approved: payload {expense_id, as_role}
create or replace function ww.v_payment_approved(e ww.events) returns ww.events
language plpgsql as $$
declare x ww.expenses; signer jsonb := ww.rule(e.entity_id, 'signer_roles');
        r text := ww.req_text(e.payload, 'as_role');
begin
  select * into x from ww.expenses where id = ww.req_uuid(e.payload, 'expense_id') and entity_id = e.entity_id;
  if not found then perform ww.reject('unknown expense'); end if;
  if x.status <> 'pending' then perform ww.reject(format('this expense is already %s', x.status)); end if;
  if not (r = any (array(select jsonb_array_elements_text(signer->'required'))
                   || array(select jsonb_array_elements_text(signer->'one_of')))) then
    perform ww.reject(format('"%s" is not a signing role', r));
  end if;
  if not ww.has_role(e.entity_id, e.actor, array[r]) then
    perform ww.reject(format('you do not hold the role %s', r));
  end if;
  if x.recorded_by = e.actor and not (ww.rule(e.entity_id, 'recorder_may_sign'))::boolean then
    perform ww.reject('the person who recorded an expense cannot approve its payment');
  end if;
  if exists (select 1 from ww.payees p join ww.persons pp on pp.id = p.person_id
              join ww.persons me on me.id = e.actor
             where p.id = x.payee_id and (pp.id = me.id or pp.household_id = me.household_id)) then
    perform ww.reject('you cannot approve a payment to yourself or your own household');
  end if;
  if exists (select 1 from ww.expense_approvals where expense_id = x.id and (person_id = e.actor or as_role = r)) then
    perform ww.reject('this signature is already given');
  end if;
  return e;
end $$;

create or replace function ww.p_payment_approved(e ww.events) returns void
language sql as $$
  insert into ww.expense_approvals (expense_id, person_id, as_role, event_seq)
  values ((e.payload->>'expense_id')::uuid, e.actor, e.payload->>'as_role', e.seq)
$$;

-- payment.released: payload {expense_id}
create or replace function ww.v_payment_released(e ww.events) returns ww.events
language plpgsql as $$
declare x ww.expenses; line ww.budget_lines; signer jsonb := ww.rule(e.entity_id, 'signer_roles');
        spent numeric; est_window numeric; total_window numeric; cap numeric;
begin
  select * into x from ww.expenses where id = ww.req_uuid(e.payload, 'expense_id') and entity_id = e.entity_id;
  if not found then perform ww.reject('unknown expense'); end if;
  if x.status <> 'pending' then perform ww.reject(format('this expense is already %s', x.status)); end if;
  if x.fiscal_year <> e.fiscal_year then perform ww.reject('release it in the fiscal year it was recorded'); end if;

  -- signatures: every required role, plus one of the alternatives, by different people
  if exists (select 1 from jsonb_array_elements_text(signer->'required') req
              where not exists (select 1 from ww.expense_approvals where expense_id = x.id and as_role = req)) then
    perform ww.reject('the treasurer has not signed');
  end if;
  if jsonb_array_length(signer->'one_of') > 0 and not exists (
       select 1 from ww.expense_approvals where expense_id = x.id
          and as_role in (select jsonb_array_elements_text(signer->'one_of'))) then
    perform ww.reject('the chair or the secretary has not signed');
  end if;
  if (select count(distinct person_id) from ww.expense_approvals where expense_id = x.id) < 2 then
    perform ww.reject('two different people must sign');
  end if;
  if (ww.rule(e.entity_id, 'require_woman_signer'))::boolean and not exists (
       select 1 from ww.expense_approvals a join ww.persons p on p.id = a.person_id
        where a.expense_id = x.id and p.gender = 'f') then
    perform ww.reject('one of the signers must be a woman');
  end if;

  -- budget
  if x.budget_line_id is not null then
    select * into line from ww.budget_lines where id = x.budget_line_id;
    select coalesce(sum(amount), 0) into spent from ww.expenses where budget_line_id = line.id and status = 'paid';
    if spent + x.amount > line.amount then
      perform ww.reject(format('the budget line "%s" has only Rs %s left', line.title_np, line.amount - spent));
    end if;
  end if;

  -- money available
  if x.method = 'cash' and x.amount > ww.balance(e.entity_id, 'BS-CASH') then
    perform ww.reject('not enough cash in hand');
  end if;
  if x.method = 'bank' and x.amount > ww.balance(e.entity_id, 'BS-BANK') then
    perform ww.reject('not enough money in the bank');
  end if;

  -- lost receipts: estimated spending stays within the cap over the last 90 days
  if x.estimated then
    cap := (ww.rule(e.entity_id, 'estimated_cap_pct'))::numeric;
    select coalesce(sum(amount) filter (where estimated), 0), coalesce(sum(amount), 0)
      into est_window, total_window
      from ww.expenses x2 join ww.events ev on ev.ward_id = e.ward_id and ev.seq = x2.status_seq
     where x2.entity_id = e.entity_id and x2.status = 'paid' and ev.occurred_on > e.occurred_on - 90;
    if (est_window + x.amount) > cap / 100 * (total_window + x.amount) then
      perform ww.reject(format('estimated spending would pass %s%% of spending in the last 90 days', cap));
    end if;
  end if;

  e.payload := e.payload || jsonb_build_object('amount', x.amount, 'account_code', x.account_code, 'method', x.method);
  return ww.with_voucher(e);
end $$;

create or replace function ww.p_payment_released(e ww.events) returns void
language plpgsql as $$
declare x ww.expenses;
begin
  select * into x from ww.expenses where id = (e.payload->>'expense_id')::uuid;
  perform ww.post(e, x.account_code, x.amount, 0, x.memo_np);
  perform ww.post(e, ww.money_account(x.method), 0, x.amount, x.memo_np);
  update ww.expenses set status = 'paid', status_seq = e.seq where id = x.id;
end $$;

-- correction: payload {corrects_seq, reason_np}
-- A correction never erases: it reverses the original's postings (if any) and both stay visible.
create table ww.corrections (
  corrected_seq  bigint not null,
  ward_id        text not null,
  correction_seq bigint not null,
  primary key (ward_id, corrected_seq)
);

create or replace function ww.v_correction(e ww.events) returns ww.events
language plpgsql as $$
declare target ww.events;
begin
  perform ww.req_text(e.payload, 'reason_np');
  select * into target from ww.events where ward_id = e.ward_id
     and seq = (ww.req_text(e.payload, 'corrects_seq'))::bigint;
  if not found then perform ww.reject('nothing to correct at that number'); end if;
  if target.entity_id <> e.entity_id then perform ww.reject('that entry belongs to another body'); end if;
  if target.type not in ('income.recorded', 'cash.banked', 'payment.released', 'expense.recorded',
                         'work.logged', 'work.approved', 'parma.exchanged', 'reading.spring', 'reading.rain',
                         'budget.approved', 'shares.purchased', 'shares.refunded', 'loan.received',
                         'loan.repaid', 'grant.received', 'benefit.paid') then
    perform ww.reject(format('"%s" cannot be corrected this way', target.type));
  end if;
  if exists (select 1 from ww.corrections where ward_id = e.ward_id and corrected_seq = target.seq) then
    perform ww.reject('that entry is already corrected');
  end if;
  if target.type = 'expense.recorded' and exists
     (select 1 from ww.expenses where recorded_seq = target.seq and status <> 'pending') then
    perform ww.reject('this expense is already paid: correct its payment instead');
  end if;
  if target.type = 'budget.approved' and exists
     (select 1 from ww.expenses where budget_line_id = (target.payload->>'line_id')::uuid and status in ('pending', 'paid')) then
    perform ww.reject('this budget line has expenses against it');
  end if;
  e.payload := e.payload || jsonb_build_object('corrects_type', target.type);
  if exists (select 1 from ww.postings where ward_id = e.ward_id and event_seq = target.seq) then
    return ww.with_voucher(e);
  end if;
  return e;
end $$;

create or replace function ww.p_correction(e ww.events) returns void
language plpgsql as $$
declare target ww.events; p ww.postings;
begin
  select * into target from ww.events where ward_id = e.ward_id and seq = (e.payload->>'corrects_seq')::bigint;
  insert into ww.corrections values (target.seq, e.ward_id, e.seq);
  for p in select * from ww.postings where ward_id = e.ward_id and event_seq = target.seq loop
    perform ww.post(e, p.account_code, p.credit, p.debit, 'सच्याइएको: ' || (e.payload->>'reason_np'));
  end loop;
  if target.type = 'payment.released' then
    update ww.expenses set status = 'reversed', status_seq = e.seq where id = (target.payload->>'expense_id')::uuid;
  elsif target.type = 'expense.recorded' then
    update ww.expenses set status = 'cancelled', status_seq = e.seq where recorded_seq = target.seq;
  elsif target.type = 'budget.approved' then
    update ww.budget_lines set cancelled_seq = e.seq where approved_seq = target.seq;
  end if;
end $$;

insert into ww.event_types (type, allowed_roles, needs_fy, validator, projector, description) values
 ('balance.opened',   array['treasurer'], true, 'ww.v_balance_opened(ww.events)',   'ww.p_balance_opened(ww.events)',   'Opening cash and bank balance for the fiscal year'),
 ('budget.approved',  array['secretary'], true, 'ww.v_budget_approved(ww.events)',  'ww.p_budget_approved(ww.events)',  'A budget line approved by the general assembly'),
 ('payee.registered', array['secretary','treasurer','ledger_keeper'], false, 'ww.v_payee_registered(ww.events)', 'ww.p_payee_registered(ww.events)', 'A shop, contractor, organisation or person who can be paid'),
 ('income.recorded',  array['treasurer','ledger_keeper'], true, 'ww.v_income_recorded(ww.events)', 'ww.p_income_recorded(ww.events)', 'Money received, with its receipt number'),
 ('cash.banked',      array['treasurer','ledger_keeper'], true, 'ww.v_cash_banked(ww.events)',     'ww.p_cash_banked(ww.events)',     'Cash deposited into the bank account'),
 ('expense.recorded', array['treasurer','ledger_keeper'], true, 'ww.v_expense_recorded(ww.events)','ww.p_expense_recorded(ww.events)','An expense with its receipt, waiting for signatures'),
 ('payment.approved', array['treasurer','chair','secretary'], false, 'ww.v_payment_approved(ww.events)', 'ww.p_payment_approved(ww.events)', 'One signature on a payment'),
 ('payment.released', array['treasurer','chair','secretary'], true, 'ww.v_payment_released(ww.events)', 'ww.p_payment_released(ww.events)', 'A fully signed payment enters the books'),
 ('correction',       array['treasurer','secretary','supervisor'], false, 'ww.v_correction(ww.events)', 'ww.p_correction(ww.events)', 'A correction of an earlier entry, with its reason');

-- ---------------------------------------------------------------------------
-- The statutory books, as views
-- ---------------------------------------------------------------------------
create or replace view ww.v_vouchers as
select p.entity_id, p.fiscal_year, p.voucher_no, p.occurred_on, p.event_seq,
       ev.type as event_type, p.account_code, a.directive_code, a.name_np as account_name_np,
       p.debit, p.credit, p.narrative_np,
       ev.payload->>'receipt_no' as receipt_no
from ww.postings p
join ww.events ev on ev.ward_id = p.ward_id and ev.seq = p.event_seq
join ww.accounts a on a.entity_kind = ww.entity_kind(p.entity_id) and a.code = p.account_code
order by p.entity_id, p.fiscal_year, p.voucher_no, p.debit desc, p.id;

create or replace view ww.v_cash_book as
select p.entity_id, p.fiscal_year, p.voucher_no, p.occurred_on, p.narrative_np,
       p.debit, p.credit,
       sum(p.debit - p.credit) over (partition by p.entity_id, p.fiscal_year order by p.voucher_no, p.id) as balance
from ww.postings p where p.account_code = 'BS-CASH';

create or replace view ww.v_ledger_by_head as
select p.entity_id, p.fiscal_year, p.account_code, a.directive_code, a.name_np, a.kind,
       date_trunc('month', p.occurred_on)::date as month,
       sum(case when a.kind = 'income' then p.credit - p.debit else p.debit - p.credit end) as amount
from ww.postings p
join ww.accounts a on a.entity_kind = ww.entity_kind(p.entity_id) and a.code = p.account_code
where a.kind in ('income', 'expense')
group by 1, 2, 3, 4, 5, 6, 7;

create or replace view ww.v_budget_status as
select l.entity_id, l.fiscal_year, l.id as line_id, l.title_np, l.account_code, l.spend_category,
       l.amount as budget, coalesce(sum(x.amount) filter (where x.status = 'paid'), 0) as spent,
       l.amount - coalesce(sum(x.amount) filter (where x.status = 'paid'), 0) as remaining,
       l.decision_ref
from ww.budget_lines l left join ww.expenses x on x.budget_line_id = l.id
where l.cancelled_seq is null
group by l.id;

-- Forest Act s.22 / CFUG constitution s.15: at least 25% of income on forest work, and
-- at least 50% of the rest on poverty reduction, women's empowerment and enterprise.
create or replace view ww.v_spending_shares as
with inc as (
  select entity_id, fiscal_year, sum(credit - debit) as income
  from ww.postings where account_code like 'IN-%' and account_code not in ('IN-1.01', 'IN-1.02', 'IN-6.00')
  group by 1, 2),
exp as (
  select x.entity_id, x.fiscal_year,
         sum(x.amount) filter (where coalesce(l.spend_category, a.spend_category) = 'forest')   as forest,
         sum(x.amount) filter (where coalesce(l.spend_category, a.spend_category) = 'pro_poor') as pro_poor
  from ww.expenses x
  left join ww.budget_lines l on l.id = x.budget_line_id
  join ww.accounts a on a.entity_kind = ww.entity_kind(x.entity_id) and a.code = x.account_code
  where x.status = 'paid' group by 1, 2)
select inc.entity_id, inc.fiscal_year, inc.income,
       coalesce(exp.forest, 0) as forest_spent, round(inc.income * 0.25, 2) as forest_required,
       coalesce(exp.pro_poor, 0) as pro_poor_spent, round(inc.income * 0.75 * 0.5, 2) as pro_poor_required
from inc left join exp using (entity_id, fiscal_year);

-- Cash rules: in hand above the limit, or held longer than the banking limit
create or replace view ww.v_cash_flags as
with last_banked as (
  select entity_id, max(occurred_on) as on_date from ww.events where type = 'cash.banked' group by 1),
oldest_unbanked as (
  select ev.entity_id, min(ev.occurred_on) as since
  from ww.events ev left join last_banked lb using (entity_id)
  where ev.type = 'income.recorded' and ev.payload->>'method' = 'cash'
    and (lb.on_date is null or ev.occurred_on > lb.on_date)
  group by 1)
select en.id as entity_id,
       ww.balance(en.id, 'BS-CASH') as cash_in_hand,
       (ww.rule(en.id, 'cash_on_hand_max'))::numeric as cash_limit,
       ww.balance(en.id, 'BS-CASH') > (ww.rule(en.id, 'cash_on_hand_max'))::numeric as over_limit,
       ou.since as unbanked_since,
       (ww.balance(en.id, 'BS-CASH') > 0 and ou.since is not null
         and current_date - ou.since > (ww.rule(en.id, 'bank_within_days'))::int) as late_banking
from ww.entities en left join oldest_unbanked ou on ou.entity_id = en.id;
