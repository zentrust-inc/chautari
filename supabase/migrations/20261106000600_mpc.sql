-- Chautari — 0006: the Kakani Multipurpose Cooperative (MPC)
-- Rulebook: draft MPC bylaws v4 (Kartik 2083). The MPC takes no savings or deposits
-- (s.11). Capital comes from shares, restricted grants and loans capped at 10% (s.22–25,
-- s.65–69). Pay is one equal hourly rate for everyone (s.53). After the year's audit the
-- surplus goes to the reserve fund (at least 25%), the cooperative promotion fund (0.5%),
-- then 40% community, 30% member benefit by recorded work, 30% capital and training (s.72–74).
--
-- Everything here is built and tested before the MPC is registered; it holds real money
-- only after registration and the lawyer's review.

-- ---------------------------------------------------------------------------
-- Chart of accounts (provisional until the registrar's format is confirmed)
-- ---------------------------------------------------------------------------
alter table ww.accounts drop constraint accounts_kind_check;
alter table ww.accounts add constraint accounts_kind_check
  check (kind in ('asset', 'liability', 'equity', 'income', 'expense'));

insert into ww.accounts (entity_kind, code, kind, directive_code, name_np, name_en, spend_category, source)
select 'mpc', code, kind, null, name_np, name_en, null, 'Draft MPC bylaws v4 s.72–74; provisional chart'
from (values
 ('BS-CASH','asset','नगद','Cash in hand'),
 ('BS-BANK','asset','बैङ्क','Bank account'),
 ('BS-ADV','asset','पेस्की','Advances'),
 ('BS-STOCK','asset','मौज्दात सामान','Stock'),
 ('BS-FIXED','asset','मेसिन तथा उपकरण','Machines and equipment'),
 ('LI-LOAN','liability','तिर्नुपर्ने ऋण','Loans payable'),
 ('LI-RESTRICTED','liability','प्रतिबन्धित (अनुदान) कोष','Restricted grant fund'),
 ('EQ-SHARE','equity','शेयर पूँजी','Share capital'),
 ('EQ-RESERVE','equity','जगेडा कोष','Reserve fund'),
 ('EQ-PROMO','equity','सहकारी प्रवर्द्धन कोष','Cooperative promotion fund'),
 ('EQ-COMMUNITY','equity','सामुदायिक विकास कोष','Community development fund'),
 ('EQ-MEMBER','equity','सदस्य लाभ कोष','Member benefit fund'),
 ('EQ-CAPITAL','equity','पूँजी, प्रविधि, विस्तार तथा तालिम कोष','Capital, technology, expansion and training fund'),
 ('IN-SALES','income','उत्पादन बिक्री','Sales'),
 ('IN-SERVICE','income','सेवा शुल्क','Service income'),
 ('IN-INTEREST','income','ब्याज आम्दानी','Interest received'),
 ('IN-OTHER','income','अन्य आम्दानी','Other income'),
 ('IN-GRANT-USED','income','प्रतिबन्धित कोषबाट खर्च','Restricted grant used'),
 ('EX-WAGES','expense','ज्याला (समान दर)','Wages at the equal rate'),
 ('EX-MATERIALS','expense','कच्चा पदार्थ','Raw materials'),
 ('EX-MAINT','expense','मर्मतसम्भार','Maintenance'),
 ('EX-OPS','expense','सञ्चालन खर्च','Running costs'),
 ('EX-TAX','expense','कर तथा कानुनी दायित्व','Taxes and legal dues'),
 ('EX-DEPR','expense','ह्रास कट्टी','Depreciation'),
 ('EX-INTEREST','expense','ऋणको ब्याज','Loan interest'),
 ('EX-TRAINING','expense','सहकारी शिक्षा तथा तालिम','Cooperative education and training')
) v(code, kind, name_np, name_en);

insert into ww.rule_defaults (key, value, purpose_np, purpose_en, source) values
 ('hourly_rate',      '100',    'सबैको प्रति घण्टा ज्याला एउटै।', 'One hourly rate for everyone.', 'Draft MPC bylaws v4 s.53 (assembly sets; never below the legal minimum)'),
 ('share_price',      '100',    'एक कित्ता शेयरको मूल्य।', 'Price of one share.', 'Draft MPC bylaws v4 s.22(1)'),
 ('min_shares',       '5',      'प्रत्येक सदस्यले कम्तीमा ५ कित्ता शेयर लिनुपर्छ।', 'Every member holds at least 5 shares.', 'Draft MPC bylaws v4 s.22(2)'),
 ('max_share_pct',    '5',      'कुनै सदस्यले कुल शेयर पूँजीको ५% भन्दा बढी लिन पाउँदैन।', 'No member holds more than 5% of share capital.', 'Draft MPC bylaws v4 s.22(2)'),
 ('share_cap_applies_from', '100000', 'कुल शेयर पूँजी रु १ लाख पुगेपछि ५% सीमा लागू हुन्छ।', 'The 5% limit applies once share capital reaches Rs 1 lakh.', 'Proposed: the limit cannot work while the first members join'),
 ('loan_rate_cap',    '10',     'कुनै पनि ऋणको ब्याज (शुल्कसमेत) वार्षिक १०% भन्दा बढी हुँदैन।', 'No loan costs more than 10% a year, fees included.', 'Draft MPC bylaws v4 s.24'),
 ('reserve_pct',      '25',     'खुद बचतको कम्तीमा २५% जगेडा कोषमा।', 'At least 25% of net surplus to the reserve fund.', 'Draft MPC bylaws v4 s.73(1)'),
 ('promotion_pct',    '0.5',    'बाँकीको ०.५% सहकारी प्रवर्द्धन कोषमा।', '0.5% of the rest to the cooperative promotion fund.', 'Draft MPC bylaws v4 s.73(2)'),
 ('split_community_pct', '40',  'बाँडफाँडयोग्य बचतको ४०% सामुदायिक विकास कोषमा।', '40% of the distributable surplus to community development.', 'Draft MPC bylaws v4 s.74(1)'),
 ('split_member_pct', '30',     'बाँडफाँडयोग्य बचतको ३०% सदस्य लाभ कोषमा।', '30% of the distributable surplus to member benefit.', 'Draft MPC bylaws v4 s.74(2)'),
 ('active_min_hours', '156',    'सक्रिय सदस्य: वर्षमा कम्तीमा १५६ घण्टा (हप्ताको औसत ३ घण्टा)।', 'Active member: at least 156 hours a year (3 a week on average).', 'Design Principles v0.3; to set in the internal procedure (bylaws v4 s.20)');

-- ---------------------------------------------------------------------------
-- Columns the MPC adds to shared tables
-- ---------------------------------------------------------------------------
alter table ww.payees   add column entity_ref text references ww.entities(id);   -- payee is another body (CFUG ↔ MPC)
alter table ww.budget_lines alter column spend_category drop not null;   -- Forest Act categories are for the CFUG
alter table ww.expenses add column enterprise_id uuid;
alter table ww.expenses add column grant_id uuid;
alter table ww.expenses add column work_ids uuid[];

-- posting into a named body and voucher (for the other side of a CFUG ↔ MPC payment)
create or replace function ww.post_to(e ww.events, p_entity text, p_voucher int, p_code text,
                                      p_debit numeric, p_credit numeric, p_narr text)
returns void language plpgsql as $$
begin
  if (ww.account(p_entity, p_code)).code is null then
    perform ww.reject(format('unknown account %s for %s', p_code, p_entity));
  end if;
  insert into ww.postings (ward_id, entity_id, event_seq, voucher_no, fiscal_year, occurred_on,
                           account_code, debit, credit, narrative_np)
  values (e.ward_id, p_entity, e.seq, p_voucher, e.fiscal_year, e.occurred_on, p_code, p_debit, p_credit, p_narr);
end $$;

create or replace function ww.require_mpc(e ww.events) returns void
language plpgsql as $$
begin
  if ww.entity_kind(e.entity_id) <> 'mpc' then
    perform ww.reject(format('"%s" belongs to the cooperative, not to %s', e.type, e.entity_id));
  end if;
end $$;

create or replace function ww.is_corrected(p_ward text, p_seq bigint) returns boolean
language sql stable as $$ select exists (select 1 from ww.corrections where ward_id = p_ward and corrected_seq = p_seq) $$;

-- ---------------------------------------------------------------------------
-- Members (bylaws v4 s.15–21)
-- ---------------------------------------------------------------------------
create table ww.members (
  entity_id    text not null references ww.entities(id),
  person_id    uuid not null references ww.persons(id),
  member_no    int  not null,
  admitted_on  date not null,
  admitted_seq bigint not null,
  left_on      date,
  left_seq     bigint,
  primary key (entity_id, person_id),
  unique (entity_id, member_no)
);

-- member.admitted: payload {member_no, decision_ref}; private {person_id, self_declaration}
-- self_declaration: the person declares they are an 18+ Nepali citizen living in the working
-- area with no competing business (s.15(1)); the board's decision is cited.
create or replace function ww.v_member_admitted(e ww.events) returns ww.events
language plpgsql as $$
declare pid uuid := ww.req_uuid(e.private, 'person_id');
begin
  perform ww.require_mpc(e);
  perform ww.req_text(e.payload, 'decision_ref');
  if (e.payload->>'member_no') !~ '^[0-9]+$' then perform ww.reject('"member_no" must be a number'); end if;
  if coalesce((e.private->>'self_declaration')::boolean, false) is not true then
    perform ww.reject('the person''s signed self-declaration (18+, citizen, resident) is required');
  end if;
  if not exists (select 1 from ww.persons where id = pid and ward_id = e.ward_id) then perform ww.reject('unknown person'); end if;
  if exists (select 1 from ww.members where entity_id = e.entity_id and person_id = pid and left_seq is null) then
    perform ww.reject('already a member');
  end if;
  if exists (select 1 from ww.members where entity_id = e.entity_id and member_no = (e.payload->>'member_no')::int) then
    perform ww.reject('that member number is taken');
  end if;
  return e;
end $$;

create or replace function ww.p_member_admitted(e ww.events) returns void
language sql as $$
  insert into ww.members (entity_id, person_id, member_no, admitted_on, admitted_seq)
  values (e.entity_id, (e.private->>'person_id')::uuid, (e.payload->>'member_no')::int, e.occurred_on, e.seq)
  on conflict (entity_id, person_id) do update
    set member_no = excluded.member_no, admitted_on = excluded.admitted_on, admitted_seq = excluded.admitted_seq,
        left_on = null, left_seq = null
$$;

-- ---------------------------------------------------------------------------
-- Shares (s.22): holdings are computed from uncorrected events, never stored
-- ---------------------------------------------------------------------------
create or replace view ww.v_share_moves as
select ev.entity_id, (ev.private->>'person_id')::uuid as person_id, ev.seq, ev.occurred_on, ev.type,
       case ev.type when 'shares.purchased' then 1 else -1 end * (ev.payload->>'kitta')::int as kitta,
       case ev.type when 'shares.purchased' then 1 else -1 end * (ev.payload->>'amount')::numeric as amount
from ww.events ev
where ev.type in ('shares.purchased', 'shares.refunded') and not ww.is_corrected(ev.ward_id, ev.seq);

create or replace function ww.shares_held(p_entity text, p_person uuid) returns int
language sql stable as $$
  select coalesce(sum(kitta), 0)::int from ww.v_share_moves where entity_id = p_entity and person_id = p_person
$$;

create or replace function ww.share_capital(p_entity text) returns numeric
language sql stable as $$ select coalesce(sum(amount), 0) from ww.v_share_moves where entity_id = p_entity $$;

-- shares.purchased: payload {kitta, amount, method, receipt_no}; private {person_id}
create or replace function ww.v_shares_purchased(e ww.events) returns ww.events
language plpgsql as $$
declare pid uuid := ww.req_uuid(e.private, 'person_id');
        k int; amt numeric := ww.req_amount(e.payload, 'amount');
        price numeric := (ww.rule(e.entity_id, 'share_price'))::numeric;
        held int; total numeric; cap_from numeric; cap_pct numeric;
begin
  perform ww.require_mpc(e);
  if (e.payload->>'kitta') !~ '^[1-9][0-9]*$' then perform ww.reject('"kitta" must be a whole number of shares'); end if;
  k := (e.payload->>'kitta')::int;
  if amt <> k * price then perform ww.reject(format('%s shares cost Rs %s', k, k * price)); end if;
  if not exists (select 1 from ww.members where entity_id = e.entity_id and person_id = pid and left_seq is null) then
    perform ww.reject('only a member can buy shares');
  end if;
  perform ww.req_text(e.payload, 'receipt_no');
  if ww.req_method(e.payload) = 'cash' and amt > (ww.rule(e.entity_id, 'cash_receipt_max'))::numeric then
    perform ww.reject(format('cash above Rs %s must come through the bank', ww.rule(e.entity_id, 'cash_receipt_max')));
  end if;
  held := ww.shares_held(e.entity_id, pid) + k;
  if held < (ww.rule(e.entity_id, 'min_shares'))::int then
    perform ww.reject(format('a member holds at least %s shares', ww.rule(e.entity_id, 'min_shares')));
  end if;
  total := ww.share_capital(e.entity_id) + amt;
  cap_from := (ww.rule(e.entity_id, 'share_cap_applies_from'))::numeric;
  cap_pct := (ww.rule(e.entity_id, 'max_share_pct'))::numeric;
  if total >= cap_from and held * price > total * cap_pct / 100 then
    perform ww.reject(format('no member may hold more than %s%% of share capital', cap_pct));
  end if;
  return ww.with_voucher(e);
end $$;

create or replace function ww.p_shares_purchased(e ww.events) returns void
language plpgsql as $$
declare amt numeric := (e.payload->>'amount')::numeric;
begin
  perform ww.post(e, ww.money_account(e.payload->>'method'), amt, 0, 'शेयर खरिद');
  perform ww.post(e, 'EQ-SHARE', 0, amt, 'शेयर खरिद');
end $$;

-- shares.refunded: payload {kitta, method, decision_ref}; private {person_id} — at face value (s.21)
create or replace function ww.v_shares_refunded(e ww.events) returns ww.events
language plpgsql as $$
declare pid uuid := ww.req_uuid(e.private, 'person_id');
        k int; price numeric := (ww.rule(e.entity_id, 'share_price'))::numeric; left_ int;
begin
  perform ww.require_mpc(e);
  perform ww.req_text(e.payload, 'decision_ref');
  if (e.payload->>'kitta') !~ '^[1-9][0-9]*$' then perform ww.reject('"kitta" must be a whole number of shares'); end if;
  k := (e.payload->>'kitta')::int;
  left_ := ww.shares_held(e.entity_id, pid) - k;
  if left_ < 0 then perform ww.reject('more shares than the member holds'); end if;
  if left_ > 0 and left_ < (ww.rule(e.entity_id, 'min_shares'))::int then
    perform ww.reject('a member keeps at least the minimum, or refunds all shares on leaving');
  end if;
  if ww.balance(e.entity_id, ww.money_account(ww.req_method(e.payload))) < k * price then
    perform ww.reject('not enough money to refund');
  end if;
  e.payload := e.payload || jsonb_build_object('amount', k * price);
  return ww.with_voucher(e);
end $$;

create or replace function ww.p_shares_refunded(e ww.events) returns void
language plpgsql as $$
declare amt numeric := (e.payload->>'amount')::numeric;
begin
  perform ww.post(e, 'EQ-SHARE', amt, 0, 'शेयर फिर्ता');
  perform ww.post(e, ww.money_account(e.payload->>'method'), 0, amt, 'शेयर फिर्ता');
end $$;

-- member.left: payload {member_no, reason_np}; private {person_id}
create or replace function ww.v_member_left(e ww.events) returns ww.events
language plpgsql as $$
declare pid uuid := ww.req_uuid(e.private, 'person_id');
begin
  perform ww.require_mpc(e);
  perform ww.req_text(e.payload, 'reason_np');
  if not exists (select 1 from ww.members where entity_id = e.entity_id and person_id = pid and left_seq is null) then
    perform ww.reject('not a member');
  end if;
  if ww.shares_held(e.entity_id, pid) > 0 then perform ww.reject('refund the member''s shares first'); end if;
  return e;
end $$;

create or replace function ww.p_member_left(e ww.events) returns void
language sql as $$
  update ww.members set left_on = e.occurred_on, left_seq = e.seq
   where entity_id = e.entity_id and person_id = (e.private->>'person_id')::uuid and left_seq is null
$$;

-- ---------------------------------------------------------------------------
-- Loans (s.24): capped interest, written terms, public register
-- ---------------------------------------------------------------------------
-- loan.received: payload {loan_id, lender_kind, lender_name?, amount, rate_pct, term_months, decision_ref, method}
--                private {person_id} when the lender is a person
create or replace view ww.v_loans as
select ev.entity_id, (ev.payload->>'loan_id')::uuid as loan_id, ev.payload->>'lender_kind' as lender_kind,
       ev.payload->>'lender_name' as lender_name, (ev.private->>'person_id')::uuid as lender_person_id,
       (ev.payload->>'amount')::numeric as amount, (ev.payload->>'rate_pct')::numeric as rate_pct,
       (ev.payload->>'term_months')::int as term_months, coalesce((ev.payload->>'related_party')::boolean, false) as related_party,
       ev.payload->>'decision_ref' as decision_ref, ev.occurred_on as received_on, ev.seq,
       (ev.payload->>'amount')::numeric - coalesce((
          select sum((r.payload->>'principal')::numeric) from ww.events r
           where r.type = 'loan.repaid' and r.entity_id = ev.entity_id and r.payload->>'loan_id' = ev.payload->>'loan_id'
             and not ww.is_corrected(r.ward_id, r.seq)), 0) as outstanding,
       coalesce((select sum((r.payload->>'interest')::numeric) from ww.events r
           where r.type = 'loan.repaid' and r.entity_id = ev.entity_id and r.payload->>'loan_id' = ev.payload->>'loan_id'
             and not ww.is_corrected(r.ward_id, r.seq)), 0) as interest_paid,
       coalesce((select max(r.occurred_on) from ww.events r
           where r.type = 'loan.repaid' and r.entity_id = ev.entity_id and r.payload->>'loan_id' = ev.payload->>'loan_id'
             and not ww.is_corrected(r.ward_id, r.seq)), ev.occurred_on) as last_paid_on
from ww.events ev
where ev.type = 'loan.received' and not ww.is_corrected(ev.ward_id, ev.seq);

create or replace function ww.v_loan_received(e ww.events) returns ww.events
language plpgsql as $$
declare cap numeric := (ww.rule(e.entity_id, 'loan_rate_cap'))::numeric; rate numeric; pid uuid; related boolean := false;
begin
  perform ww.require_mpc(e);
  perform ww.req_uuid(e.payload, 'loan_id');
  perform ww.req_amount(e.payload, 'amount');
  perform ww.req_text(e.payload, 'decision_ref');
  if exists (select 1 from ww.v_loans where loan_id = (e.payload->>'loan_id')::uuid) then perform ww.reject('this loan already exists'); end if;
  begin rate := (e.payload->>'rate_pct')::numeric; exception when others then rate := null; end;
  if rate is null or rate < 0 then perform ww.reject('"rate_pct" must be zero or more (fees included)'); end if;
  if (e.payload->>'term_months') !~ '^[1-9][0-9]*$' then perform ww.reject('"term_months" is required'); end if;
  case e.payload->>'lender_kind'
    when 'member' then
      pid := ww.req_uuid(e.private, 'person_id');
      if not exists (select 1 from ww.members where entity_id = e.entity_id and person_id = pid and left_seq is null) then
        perform ww.reject('a person lending must be a member');
      end if;
      if e.payload ? 'lender_name' then perform ww.reject('a member''s name goes in the private part'); end if;
      -- officers, the custodian and their households are related parties (s.24(6))
      related := exists (select 1 from ww.role_terms rt join ww.persons p on p.id = rt.person_id
                          join ww.persons l on l.id = pid
                          where rt.entity_id = e.entity_id and rt.to_seq is null
                            and (p.id = l.id or p.household_id = l.household_id));
    when 'organisation', 'bank' then perform ww.req_text(e.payload, 'lender_name');
    else perform ww.reject('lender_kind must be member, organisation or bank');
  end case;
  if rate > cap and not (e.payload->>'lender_kind' = 'bank' and coalesce((e.payload->>'assembly_approved')::boolean, false)) then
    perform ww.reject(format('interest above %s%% is not allowed (a licensed bank''s loan needs the general assembly)', cap));
  end if;
  if related and not coalesce((e.payload->>'assembly_approved')::boolean, false) then
    perform ww.reject('a loan from an officer or their household needs the general assembly''s approval');
  end if;
  perform ww.req_method(e.payload);
  e.payload := e.payload || jsonb_build_object('related_party', related);
  return ww.with_voucher(e);
end $$;

create or replace function ww.p_loan_received(e ww.events) returns void
language plpgsql as $$
declare amt numeric := (e.payload->>'amount')::numeric;
begin
  perform ww.post(e, ww.money_account(e.payload->>'method'), amt, 0, 'ऋण प्राप्त');
  perform ww.post(e, 'LI-LOAN', 0, amt, 'ऋण प्राप्त');
end $$;

-- loan.repaid: payload {loan_id, principal, interest, method}
create or replace function ww.v_loan_repaid(e ww.events) returns ww.events
language plpgsql as $$
declare l ww.v_loans; pr numeric := coalesce((e.payload->>'principal')::numeric, 0);
        it numeric := coalesce((e.payload->>'interest')::numeric, 0); max_it numeric;
begin
  perform ww.require_mpc(e);
  select * into l from ww.v_loans where loan_id = ww.req_uuid(e.payload, 'loan_id') and entity_id = e.entity_id;
  if not found then perform ww.reject('unknown loan'); end if;
  if pr < 0 or it < 0 or pr + it = 0 then perform ww.reject('principal and interest must be positive amounts'); end if;
  if pr > l.outstanding then perform ww.reject(format('only Rs %s is outstanding', l.outstanding)); end if;
  max_it := ceil(l.outstanding * l.rate_pct / 100 * greatest(e.occurred_on - l.last_paid_on, 0) / 365.0);
  if it > max_it then
    perform ww.reject(format('interest for this period is at most Rs %s at %s%%', max_it, l.rate_pct));
  end if;
  if ww.balance(e.entity_id, ww.money_account(ww.req_method(e.payload))) < pr + it then
    perform ww.reject('not enough money to repay');
  end if;
  return ww.with_voucher(e);
end $$;

create or replace function ww.p_loan_repaid(e ww.events) returns void
language plpgsql as $$
declare pr numeric := coalesce((e.payload->>'principal')::numeric, 0);
        it numeric := coalesce((e.payload->>'interest')::numeric, 0);
begin
  if pr > 0 then perform ww.post(e, 'LI-LOAN', pr, 0, 'ऋणको साँवा भुक्तानी'); end if;
  if it > 0 then perform ww.post(e, 'EX-INTEREST', it, 0, 'ऋणको ब्याज भुक्तानी'); end if;
  perform ww.post(e, ww.money_account(e.payload->>'method'), 0, pr + it, 'ऋण भुक्तानी');
end $$;

-- ---------------------------------------------------------------------------
-- Grants (s.65–69): restricted fund, never surplus, never member benefit
-- ---------------------------------------------------------------------------
-- grant.received: payload {grant_id, donor, purpose_np, amount, agreement_ref}  (always by bank)
create or replace view ww.v_grants as
select ev.entity_id, (ev.payload->>'grant_id')::uuid as grant_id, ev.payload->>'donor' as donor,
       ev.payload->>'purpose_np' as purpose_np, (ev.payload->>'amount')::numeric as amount,
       ev.payload->>'agreement_ref' as agreement_ref, ev.occurred_on as received_on,
       coalesce((select sum(x.amount) from ww.expenses x where x.grant_id = (ev.payload->>'grant_id')::uuid and x.status = 'paid'), 0) as used
from ww.events ev
where ev.type = 'grant.received' and not ww.is_corrected(ev.ward_id, ev.seq);

create or replace function ww.v_grant_received(e ww.events) returns ww.events
language plpgsql as $$
begin
  perform ww.require_mpc(e);
  perform ww.req_uuid(e.payload, 'grant_id');
  perform ww.req_text(e.payload, 'donor');
  perform ww.req_text(e.payload, 'purpose_np');
  perform ww.req_text(e.payload, 'agreement_ref');
  perform ww.req_amount(e.payload, 'amount');
  if exists (select 1 from ww.v_grants where grant_id = (e.payload->>'grant_id')::uuid) then perform ww.reject('this grant already exists'); end if;
  return ww.with_voucher(e);
end $$;

create or replace function ww.p_grant_received(e ww.events) returns void
language plpgsql as $$
declare amt numeric := (e.payload->>'amount')::numeric;
begin
  perform ww.post(e, 'BS-BANK', amt, 0, 'प्रतिबन्धित अनुदान: ' || (e.payload->>'donor'));
  perform ww.post(e, 'LI-RESTRICTED', 0, amt, 'प्रतिबन्धित अनुदान: ' || (e.payload->>'donor'));
end $$;

-- ---------------------------------------------------------------------------
-- Enterprises (s.85–86): one plan approved by the assembly per enterprise
-- ---------------------------------------------------------------------------
create table ww.enterprises (
  id           uuid primary key,
  entity_id    text not null references ww.entities(id),
  name_np      text not null,
  plan_ref     text not null,
  approved_seq bigint not null
);

create or replace function ww.v_enterprise_approved(e ww.events) returns ww.events
language plpgsql as $$
begin
  perform ww.require_mpc(e);
  perform ww.req_uuid(e.payload, 'enterprise_id');
  perform ww.req_text(e.payload, 'name_np');
  perform ww.req_text(e.payload, 'plan_ref');
  if exists (select 1 from ww.enterprises where id = (e.payload->>'enterprise_id')::uuid) then perform ww.reject('this enterprise already exists'); end if;
  return e;
end $$;

create or replace function ww.p_enterprise_approved(e ww.events) returns void
language sql as $$
  insert into ww.enterprises values ((e.payload->>'enterprise_id')::uuid, e.entity_id, e.payload->>'name_np', e.payload->>'plan_ref', e.seq)
$$;

-- ---------------------------------------------------------------------------
-- Income and expenses: enterprise tags, grants, equal pay, payments between bodies
-- ---------------------------------------------------------------------------
create table ww.wage_links (
  work_id    uuid primary key references ww.work_logs(id),
  expense_id uuid not null references ww.expenses(id)
);

create or replace function ww.v_income_recorded_mpc(e ww.events) returns ww.events
language plpgsql as $$
begin
  if e.payload ? 'enterprise_id' and not exists
     (select 1 from ww.enterprises where id = (e.payload->>'enterprise_id')::uuid and entity_id = e.entity_id) then
    perform ww.reject('unknown enterprise');
  end if;
  if e.payload->>'account_code' = 'IN-GRANT-USED' then perform ww.reject('restricted grant income is recorded automatically'); end if;
  return ww.v_income_recorded(e);
end $$;

create or replace function ww.v_expense_recorded_mpc(e ww.events) returns ww.events
language plpgsql as $$
declare pay ww.payees; g ww.v_grants; ids uuid[]; w record; hrs numeric; rate numeric;
begin
  e := ww.v_expense_recorded(e);
  select * into pay from ww.payees where id = (e.payload->>'payee_id')::uuid;

  if e.payload ? 'enterprise_id' and not exists
     (select 1 from ww.enterprises where id = (e.payload->>'enterprise_id')::uuid and entity_id = e.entity_id) then
    perform ww.reject('unknown enterprise');
  end if;

  if e.payload ? 'grant_id' then
    select * into g from ww.v_grants where grant_id = (e.payload->>'grant_id')::uuid and entity_id = e.entity_id;
    if not found then perform ww.reject('unknown grant'); end if;
    if g.amount - g.used < (e.payload->>'amount')::numeric then
      perform ww.reject(format('the grant "%s" has only Rs %s left', g.purpose_np, g.amount - g.used));
    end if;
  end if;

  -- equal pay: wages are exactly the equal rate × approved paid hours, each hour paid once
  if e.payload ? 'work_ids' then
    if jsonb_typeof(e.payload->'work_ids') <> 'array' or jsonb_array_length(e.payload->'work_ids') = 0 then
      perform ww.reject('"work_ids" must list the approved work entries');
    end if;
    ids := array(select jsonb_array_elements_text(e.payload->'work_ids')::uuid);
    if pay.kind <> 'person' then perform ww.reject('wages go to a person'); end if;
    hrs := 0;
    for w in select * from ww.work_logs where id = any (ids) loop
      if w.entity_id <> e.entity_id then perform ww.reject('that work belongs to another body'); end if;
      if w.status <> 'approved' or not w.paid then perform ww.reject('only approved paid work can be paid'); end if;
      if w.person_id <> pay.person_id then perform ww.reject('that work was done by someone else'); end if;
      if exists (select 1 from ww.wage_links where work_id = w.id) then perform ww.reject('some of these hours are already paid'); end if;
      hrs := hrs + w.hours;
    end loop;
    if (select count(*) from ww.work_logs where id = any (ids)) <> cardinality(ids) then perform ww.reject('unknown work entry'); end if;
    rate := (ww.rule(e.entity_id, 'hourly_rate'))::numeric;
    if (e.payload->>'amount')::numeric <> hrs * rate then
      perform ww.reject(format('%s hours at the equal rate of Rs %s is Rs %s', hrs, rate, hrs * rate));
    end if;
  elsif ww.entity_kind(e.entity_id) = 'mpc' and e.payload->>'account_code' = 'EX-WAGES' then
    perform ww.reject('wages are paid only against approved work entries');
  end if;

  -- a payment to the other body: name the income head it lands in
  if pay.entity_ref is not null then
    if (ww.account(pay.entity_ref, ww.req_text(e.payload, 'counter_income_code'))).kind is distinct from 'income' then
      perform ww.reject(format('choose an income head of %s for the other side', pay.entity_ref));
    end if;
  end if;
  return e;
end $$;

create or replace function ww.p_expense_recorded_mpc(e ww.events) returns void
language plpgsql as $$
declare ids uuid[];
begin
  perform ww.p_expense_recorded(e);
  update ww.expenses set enterprise_id = (e.payload->>'enterprise_id')::uuid, grant_id = (e.payload->>'grant_id')::uuid
   where id = (e.payload->>'expense_id')::uuid;
  if e.payload ? 'work_ids' then
    ids := array(select jsonb_array_elements_text(e.payload->'work_ids')::uuid);
    update ww.expenses set work_ids = ids where id = (e.payload->>'expense_id')::uuid;
    insert into ww.wage_links select unnest(ids), (e.payload->>'expense_id')::uuid;
  end if;
end $$;

create or replace function ww.v_payment_released_mpc(e ww.events) returns ww.events
language plpgsql as $$
declare x ww.expenses; pay ww.payees; g ww.v_grants; rec ww.events;
begin
  e := ww.v_payment_released(e);
  select * into x from ww.expenses where id = (e.payload->>'expense_id')::uuid;
  select * into pay from ww.payees where id = x.payee_id;
  if x.grant_id is not null then
    select * into g from ww.v_grants where grant_id = x.grant_id;
    if g.amount - g.used < x.amount then perform ww.reject(format('the grant has only Rs %s left', g.amount - g.used)); end if;
  end if;
  if pay.entity_ref is not null then
    select * into rec from ww.events where ward_id = e.ward_id and seq = x.recorded_seq;
    if x.method = 'cash' and x.amount > (ww.rule(pay.entity_ref, 'cash_receipt_max'))::numeric then
      perform ww.reject('the other body cannot receive this much cash: pay by bank');
    end if;
    e.payload := e.payload || jsonb_build_object('counter_entity', pay.entity_ref,
                   'counter_income_code', rec.payload->>'counter_income_code',
                   'counter_voucher_no', ww.next_voucher(pay.entity_ref, e.fiscal_year));
  end if;
  return e;
end $$;

create or replace function ww.p_payment_released_mpc(e ww.events) returns void
language plpgsql as $$
declare x ww.expenses;
begin
  perform ww.p_payment_released(e);
  select * into x from ww.expenses where id = (e.payload->>'expense_id')::uuid;
  if x.grant_id is not null then
    perform ww.post(e, 'LI-RESTRICTED', x.amount, 0, 'प्रतिबन्धित अनुदानबाट: ' || x.memo_np);
    perform ww.post(e, 'IN-GRANT-USED', 0, x.amount, 'प्रतिबन्धित अनुदानबाट: ' || x.memo_np);
  end if;
  if e.payload ? 'counter_entity' then
    perform ww.post_to(e, e.payload->>'counter_entity', (e.payload->>'counter_voucher_no')::int,
                       ww.money_account(x.method), x.amount, 0, x.memo_np);
    perform ww.post_to(e, e.payload->>'counter_entity', (e.payload->>'counter_voucher_no')::int,
                       e.payload->>'counter_income_code', 0, x.amount, x.memo_np);
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Year end (s.72–74): close the year, fill the funds, share member benefit by work
-- ---------------------------------------------------------------------------
create table ww.member_benefits (
  entity_id    text not null references ww.entities(id),
  fiscal_year  text not null,
  person_id    uuid not null references ww.persons(id),
  hours        numeric not null,
  amount       numeric(14,2) not null,
  alloc_seq    bigint not null,
  primary key (entity_id, fiscal_year, person_id)
);

-- Net surplus of a year: income minus expenses from the books, restricted grants excluded
-- (grant-funded spending and the matching grant release cancel out), closing entries excluded.
create or replace function ww.net_surplus(p_entity text, p_fy text) returns numeric
language sql stable as $$
  select coalesce(sum(case a.kind when 'income' then p.credit - p.debit else p.credit - p.debit end), 0)
  from ww.postings p
  join ww.events ev on ev.ward_id = p.ward_id and ev.seq = p.event_seq
  join ww.accounts a on a.entity_kind = ww.entity_kind(p.entity_id) and a.code = p.account_code
  where p.entity_id = p_entity and p.fiscal_year = p_fy and a.kind in ('income', 'expense')
    and ev.type <> 'surplus.allocated'
$$;

-- Work hours that count toward member benefit: approved, in the body, in that fiscal year
create or replace function ww.member_hours(p_entity text, p_fy text)
returns table (person_id uuid, hours numeric) language sql stable as $$
  select w.person_id, sum(w.hours)
  from ww.work_logs w join ww.events ev on ev.ward_id = (select ward_id from ww.entities where id = p_entity)
       and ev.seq = w.logged_seq
  join ww.members m on m.entity_id = p_entity and m.person_id = w.person_id and m.left_seq is null
  where w.entity_id = p_entity and w.status = 'approved' and ev.fiscal_year = p_fy
  group by w.person_id
$$;

create or replace function ww.split(p_entity text, p_net numeric) returns jsonb
language plpgsql stable as $$
declare reserve numeric; promo numeric; dist numeric; community numeric; member numeric;
begin
  reserve   := round(p_net * (ww.rule(p_entity, 'reserve_pct'))::numeric / 100, 2);
  promo     := round((p_net - reserve) * (ww.rule(p_entity, 'promotion_pct'))::numeric / 100, 2);
  dist      := p_net - reserve - promo;
  community := round(dist * (ww.rule(p_entity, 'split_community_pct'))::numeric / 100, 2);
  member    := round(dist * (ww.rule(p_entity, 'split_member_pct'))::numeric / 100, 2);
  return jsonb_build_object('net', p_net, 'reserve', reserve, 'promotion', promo, 'distributable', dist,
                            'community', community, 'member', member, 'capital', dist - community - member);
end $$;

-- surplus.allocated: payload {decision_ref, audit_ref}; fiscal_year = the year being closed
create or replace function ww.v_surplus_allocated(e ww.events) returns ww.events
language plpgsql as $$
declare net numeric; s jsonb; total_h numeric; min_h numeric; benefits jsonb; given numeric;
begin
  perform ww.require_mpc(e);
  perform ww.req_text(e.payload, 'decision_ref');
  perform ww.req_text(e.payload, 'audit_ref');
  if exists (select 1 from ww.events where entity_id = e.entity_id and type = 'surplus.allocated'
               and fiscal_year = e.fiscal_year and not ww.is_corrected(ward_id, seq)) then
    perform ww.reject('this year''s surplus is already allocated');
  end if;
  net := ww.net_surplus(e.entity_id, e.fiscal_year);
  if net <= 0 then perform ww.reject(format('there is no surplus to share for %s (net Rs %s)', e.fiscal_year, net)); end if;
  s := ww.split(e.entity_id, net);

  min_h := (ww.rule(e.entity_id, 'active_min_hours'))::numeric;
  select sum(hours) into total_h from ww.member_hours(e.entity_id, e.fiscal_year) where hours >= min_h;
  if coalesce(total_h, 0) = 0 then
    benefits := '[]';
  else
    select jsonb_agg(jsonb_build_object('person_id', person_id, 'hours', hours,
                     'amount', floor((s->>'member')::numeric * hours / total_h)))
      into benefits from ww.member_hours(e.entity_id, e.fiscal_year) where hours >= min_h;
  end if;
  select coalesce(sum((b->>'amount')::numeric), 0) into given from jsonb_array_elements(benefits) b;
  -- what cannot be shared in whole rupees, or when nobody was active, stays in the capital fund
  s := s || jsonb_build_object('member_shared', given, 'capital', (s->>'capital')::numeric + (s->>'member')::numeric - given,
                               'member', given, 'active_members', jsonb_array_length(benefits), 'active_hours', coalesce(total_h, 0));
  e.payload := e.payload || s;
  e.private := e.private || jsonb_build_object('benefits', benefits);
  return ww.with_voucher(e);
end $$;

create or replace function ww.p_surplus_allocated(e ww.events) returns void
language plpgsql as $$
declare r record; b jsonb;
begin
  -- close every income and expense head of the year
  for r in select p.account_code, a.kind, sum(p.debit) as d, sum(p.credit) as c
             from ww.postings p join ww.accounts a on a.entity_kind = 'mpc' and a.code = p.account_code
             join ww.events ev on ev.ward_id = p.ward_id and ev.seq = p.event_seq
            where p.entity_id = e.entity_id and p.fiscal_year = e.fiscal_year and a.kind in ('income', 'expense')
              and ev.type <> 'surplus.allocated' and p.event_seq <> e.seq
            group by p.account_code, a.kind loop
    if r.c - r.d > 0 then perform ww.post(e, r.account_code, r.c - r.d, 0, 'वर्षान्त बन्द');
    elsif r.d - r.c > 0 then perform ww.post(e, r.account_code, 0, r.d - r.c, 'वर्षान्त बन्द'); end if;
  end loop;
  if (e.payload->>'reserve')::numeric > 0 then perform ww.post(e, 'EQ-RESERVE', 0, (e.payload->>'reserve')::numeric, 'जगेडा कोष'); end if;
  if (e.payload->>'promotion')::numeric > 0 then perform ww.post(e, 'EQ-PROMO', 0, (e.payload->>'promotion')::numeric, 'सहकारी प्रवर्द्धन कोष'); end if;
  if (e.payload->>'community')::numeric > 0 then perform ww.post(e, 'EQ-COMMUNITY', 0, (e.payload->>'community')::numeric, 'सामुदायिक विकास कोष'); end if;
  if (e.payload->>'member')::numeric > 0 then perform ww.post(e, 'EQ-MEMBER', 0, (e.payload->>'member')::numeric, 'सदस्य लाभ कोष'); end if;
  if (e.payload->>'capital')::numeric > 0 then perform ww.post(e, 'EQ-CAPITAL', 0, (e.payload->>'capital')::numeric, 'पूँजी, प्रविधि र तालिम कोष'); end if;
  for b in select * from jsonb_array_elements(e.private->'benefits') loop
    insert into ww.member_benefits values (e.entity_id, e.fiscal_year, (b->>'person_id')::uuid,
      (b->>'hours')::numeric, (b->>'amount')::numeric, e.seq);
  end loop;
end $$;

-- benefit.paid: payload {benefit_year, method}; private {person_id}
create or replace function ww.v_benefit_paid(e ww.events) returns ww.events
language plpgsql as $$
declare pid uuid := ww.req_uuid(e.private, 'person_id'); b ww.member_benefits; me ww.persons; them ww.persons;
begin
  perform ww.require_mpc(e);
  select * into b from ww.member_benefits where entity_id = e.entity_id and person_id = pid
     and fiscal_year = ww.req_text(e.payload, 'benefit_year');
  if not found then perform ww.reject('no member benefit for that person and year'); end if;
  if exists (select 1 from ww.events where entity_id = e.entity_id and type = 'benefit.paid'
               and private->>'person_id' = pid::text and payload->>'benefit_year' = b.fiscal_year
               and not ww.is_corrected(ward_id, seq)) then
    perform ww.reject('this member benefit is already paid');
  end if;
  select * into me from ww.persons where id = e.actor;
  select * into them from ww.persons where id = pid;
  if me.id = them.id or me.household_id = them.household_id then
    perform ww.reject('you cannot pay a benefit to yourself or your own household');
  end if;
  if ww.balance(e.entity_id, ww.money_account(ww.req_method(e.payload))) < b.amount then
    perform ww.reject('not enough money to pay');
  end if;
  e.payload := e.payload || jsonb_build_object('amount', b.amount);
  return ww.with_voucher(e);
end $$;

create or replace function ww.p_benefit_paid(e ww.events) returns void
language plpgsql as $$
declare amt numeric := (e.payload->>'amount')::numeric;
begin
  perform ww.post(e, 'EQ-MEMBER', amt, 0, 'सदस्य लाभ वितरण');
  perform ww.post(e, ww.money_account(e.payload->>'method'), 0, amt, 'सदस्य लाभ वितरण');
end $$;

-- ---------------------------------------------------------------------------
-- Corrections: reverse in every body the original touched; free paid hours
-- ---------------------------------------------------------------------------
create or replace function ww.v_correction_mpc(e ww.events) returns ww.events
language plpgsql as $$
declare others jsonb;
begin
  e := ww.v_correction_work_guard(e);
  select jsonb_object_agg(entity_id, ww.next_voucher(entity_id, e.fiscal_year)) into others
    from (select distinct entity_id from ww.postings
           where ward_id = e.ward_id and event_seq = (e.payload->>'corrects_seq')::bigint and entity_id <> e.entity_id) o;
  if others is not null then e.payload := e.payload || jsonb_build_object('counter_vouchers', others); end if;
  if e.payload->>'corrects_type' = 'surplus.allocated' then perform ww.reject('a year-end allocation is corrected by the auditor''s adjusting entry, not reversed'); end if;
  return e;
end $$;

create or replace function ww.p_correction(e ww.events) returns void
language plpgsql as $$
declare target ww.events; p ww.postings; v int;
begin
  select * into target from ww.events where ward_id = e.ward_id and seq = (e.payload->>'corrects_seq')::bigint;
  insert into ww.corrections values (target.seq, e.ward_id, e.seq);
  for p in select * from ww.postings where ward_id = e.ward_id and event_seq = target.seq loop
    v := case when p.entity_id = e.entity_id then (e.payload->>'voucher_no')::int
              else (e.payload->'counter_vouchers'->>p.entity_id)::int end;
    perform ww.post_to(e, p.entity_id, v, p.account_code, p.credit, p.debit, 'सच्याइएको: ' || (e.payload->>'reason_np'));
  end loop;
  case target.type
    when 'payment.released' then
      update ww.expenses set status = 'reversed', status_seq = e.seq where id = (target.payload->>'expense_id')::uuid;
      delete from ww.wage_links where expense_id = (target.payload->>'expense_id')::uuid;
    when 'expense.recorded' then
      update ww.expenses set status = 'cancelled', status_seq = e.seq where recorded_seq = target.seq;
      delete from ww.wage_links where expense_id = (target.payload->>'expense_id')::uuid;
    when 'budget.approved' then
      update ww.budget_lines set cancelled_seq = e.seq where approved_seq = target.seq;
    when 'work.logged' then
      update ww.work_logs set status = 'cancelled', status_seq = e.seq where logged_seq = target.seq;
    when 'work.approved' then
      update ww.work_logs set status = 'pending', approved_by = null, status_seq = e.seq
       where id = (target.payload->>'work_id')::uuid;
    when 'parma.exchanged' then
      update ww.parma set cancelled = true where event_seq = target.seq;
    else null;  -- shares, loans, grants and benefits are computed from uncorrected events
  end case;
end $$;

-- a correction must not reverse work that is already paid
create or replace function ww.v_correction_paid_work(e ww.events) returns ww.events
language plpgsql as $$
declare target ww.events;
begin
  e := ww.v_correction_mpc(e);
  select * into target from ww.events where ward_id = e.ward_id and seq = (e.payload->>'corrects_seq')::bigint;
  if target.type in ('work.logged', 'work.approved') and exists (
       select 1 from ww.wage_links l join ww.work_logs w on w.id = l.work_id
        where w.id = coalesce((target.payload->>'work_id')::uuid, (select id from ww.work_logs where logged_seq = target.seq))) then
    perform ww.reject('these hours are already paid: correct the wage payment first');
  end if;
  return e;
end $$;

update ww.event_types set validator = 'ww.v_correction_paid_work(ww.events)' where type = 'correction';
update ww.event_types set validator = 'ww.v_income_recorded_mpc(ww.events)'  where type = 'income.recorded';
update ww.event_types set validator = 'ww.v_expense_recorded_mpc(ww.events)', projector = 'ww.p_expense_recorded_mpc(ww.events)' where type = 'expense.recorded';
update ww.event_types set validator = 'ww.v_payment_released_mpc(ww.events)', projector = 'ww.p_payment_released_mpc(ww.events)' where type = 'payment.released';

-- payee.registered may now name another body
create or replace function ww.v_payee_registered_mpc(e ww.events) returns ww.events
language plpgsql as $$
begin
  e := ww.v_payee_registered(e);
  if e.payload ? 'entity_ref' then
    if e.payload->>'kind' <> 'organisation' then perform ww.reject('another body is registered as an organisation'); end if;
    if e.payload->>'entity_ref' = e.entity_id or not exists
       (select 1 from ww.entities where id = e.payload->>'entity_ref' and ward_id = e.ward_id) then
      perform ww.reject('unknown body');
    end if;
  end if;
  return e;
end $$;

create or replace function ww.p_payee_registered_mpc(e ww.events) returns void
language plpgsql as $$
begin
  perform ww.p_payee_registered(e);
  update ww.payees set entity_ref = e.payload->>'entity_ref' where id = (e.payload->>'payee_id')::uuid;
end $$;

update ww.event_types set validator = 'ww.v_payee_registered_mpc(ww.events)', projector = 'ww.p_payee_registered_mpc(ww.events)'
 where type = 'payee.registered';

insert into ww.event_types (type, allowed_roles, needs_fy, validator, projector, description) values
 ('member.admitted',    array['secretary'], false, 'ww.v_member_admitted(ww.events)',    'ww.p_member_admitted(ww.events)',    'The board admits a member (self-declaration on file)'),
 ('member.left',        array['secretary'], false, 'ww.v_member_left(ww.events)',        'ww.p_member_left(ww.events)',        'A member leaves after their shares are refunded'),
 ('shares.purchased',   array['treasurer','ledger_keeper'], true, 'ww.v_shares_purchased(ww.events)', 'ww.p_shares_purchased(ww.events)', 'A member buys shares'),
 ('shares.refunded',    array['treasurer'], true, 'ww.v_shares_refunded(ww.events)',     'ww.p_shares_refunded(ww.events)',    'Shares refunded at face value'),
 ('loan.received',      array['treasurer'], true, 'ww.v_loan_received(ww.events)',       'ww.p_loan_received(ww.events)',      'A loan under a written agreement, interest capped'),
 ('loan.repaid',        array['treasurer'], true, 'ww.v_loan_repaid(ww.events)',         'ww.p_loan_repaid(ww.events)',        'Loan principal and interest repaid'),
 ('grant.received',     array['treasurer'], true, 'ww.v_grant_received(ww.events)',      'ww.p_grant_received(ww.events)',     'A restricted grant under a written agreement'),
 ('enterprise.approved',array['secretary'], false, 'ww.v_enterprise_approved(ww.events)', 'ww.p_enterprise_approved(ww.events)', 'The assembly approves an enterprise plan'),
 ('surplus.allocated',  array['secretary'], true, 'ww.v_surplus_allocated(ww.events)',   'ww.p_surplus_allocated(ww.events)',  'After the audit, the year''s surplus goes to the funds and to members'),
 ('benefit.paid',       array['treasurer','chair','secretary'], true, 'ww.v_benefit_paid(ww.events)', 'ww.p_benefit_paid(ww.events)', 'A member''s benefit is paid out');

-- ---------------------------------------------------------------------------
-- Ledger views: leave out year-end closing; the Forest Act shares are for the CFUG only
-- ---------------------------------------------------------------------------
create or replace view ww.v_ledger_by_head as
select p.entity_id, p.fiscal_year, p.account_code, a.directive_code, a.name_np, a.kind,
       date_trunc('month', p.occurred_on)::date as month,
       sum(case when a.kind = 'income' then p.credit - p.debit else p.debit - p.credit end) as amount
from ww.postings p
join ww.accounts a on a.entity_kind = ww.entity_kind(p.entity_id) and a.code = p.account_code
join ww.events ev on ev.ward_id = p.ward_id and ev.seq = p.event_seq
where a.kind in ('income', 'expense') and ev.type <> 'surplus.allocated'
group by 1, 2, 3, 4, 5, 6, 7;

create or replace view ww.v_spending_shares as
with inc as (
  select entity_id, fiscal_year, sum(credit - debit) as income
  from ww.postings where account_code like 'IN-%' and account_code not in ('IN-1.01', 'IN-1.02', 'IN-6.00')
    and ww.entity_kind(entity_id) = 'cfug'
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

create or replace view ww.v_enterprise_results as
with inc as (
  select (ev.payload->>'enterprise_id')::uuid as enterprise_id, ev.fiscal_year, sum((ev.payload->>'amount')::numeric) as income
  from ww.events ev where ev.type = 'income.recorded' and ev.payload ? 'enterprise_id' and not ww.is_corrected(ev.ward_id, ev.seq)
  group by 1, 2),
spend as (
  select enterprise_id, fiscal_year, sum(amount) as spending,
         sum(amount) filter (where account_code = 'EX-WAGES') as wages,
         sum((select sum(w.hours) from ww.work_logs w where w.id = any (x.work_ids))) as paid_hours
  from ww.expenses x where enterprise_id is not null and status = 'paid' group by 1, 2)
select en.entity_id, en.id as enterprise_id, en.name_np, coalesce(inc.fiscal_year, spend.fiscal_year) as fiscal_year,
       coalesce(inc.income, 0) as income, coalesce(spend.spending, 0) as spending,
       coalesce(inc.income, 0) - coalesce(spend.spending, 0) as net,
       coalesce(spend.wages, 0) as wages, coalesce(spend.paid_hours, 0) as paid_hours,
       case when coalesce(spend.paid_hours, 0) > 0
            then round((coalesce(spend.wages, 0) + greatest(coalesce(inc.income, 0) - coalesce(spend.spending, 0), 0)) / spend.paid_hours, 2)
       end as earnings_per_hour
from ww.enterprises en
join (select enterprise_id, fiscal_year from inc union select enterprise_id, fiscal_year from spend) fy on fy.enterprise_id = en.id
left join inc on inc.enterprise_id = en.id and inc.fiscal_year = fy.fiscal_year
left join spend on spend.enterprise_id = en.id and spend.fiscal_year = fy.fiscal_year;
