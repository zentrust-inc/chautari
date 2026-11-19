-- चौतारी — 0009: the cooperative follows draft bylaws v4.15 (मंसिर २०८३)
--
-- v4.15 replaces every earlier draft. What changes in the database:
--   s.6   members from age 16 (self-declaration)
--   s.7   every member holds exactly one share of Rs 100
--   s.8   members lend to the cooperative only as project loans (परियोजना ऋण) under a written
--         agreement, all at one rate set by the assembly (now 10%), fixed for the agreement;
--         up to Rs 1 lakh: repaid with interest on 3 months' notice; above Rs 1 lakh: a fixed
--         term of 3 to 5 years; loans from others at most 10%, no exception
--   s.10  officers stand aside from their own interests (the public register flags these loans)
--   s.14  the 30% share is the protected capital return fund (संरक्षित पूँजी फिर्ता कोष)
-- Unchanged: no savings-and-credit business and the cooperative never lends (s.4).

-- rules ------------------------------------------------------------------------
update ww.rule_defaults set value = '1', purpose_np = 'हरेक सदस्यको एक कित्ता शेयर हुन्छ।', purpose_en = 'Every member holds one share.',
       source = 'Draft MPC bylaws v4.15 s.7(1)' where key = 'min_shares';
update ww.rule_defaults set source = 'Draft MPC bylaws v4.15 s.7(1)' where key = 'share_price';
delete from ww.rule_defaults d where key in ('max_share_pct', 'share_cap_applies_from')
   and not exists (select 1 from ww.rules_current r where r.key = d.key);
update ww.rule_defaults set purpose_np = 'अरूबाट लिने ऋणको ब्याज बढीमा वार्षिक १०% (शून्य पनि हुन सक्छ)।',
       purpose_en = 'Loans from others cost at most 10% a year (zero is allowed).', source = 'Draft MPC bylaws v4.15 s.8(5)'
 where key = 'loan_rate_cap';
update ww.rule_defaults set source = 'Draft MPC bylaws v4.15 s.13(1) (assembly sets; never below the legal minimum)' where key = 'hourly_rate';
update ww.rule_defaults set source = 'Draft MPC bylaws v4.15 s.14(1)' where key in ('reserve_pct', 'promotion_pct');
update ww.rule_defaults set source = 'Draft MPC bylaws v4.15 s.14(2)' where key = 'split_community_pct';
update ww.rule_defaults set purpose_np = 'बाँडफाँडयोग्य बचतको ३०% संरक्षित पूँजी फिर्ता कोषमा (सक्रिय सदस्यलाई काम घण्टाअनुसार)।',
       purpose_en = '30% of the distributable surplus to the protected capital return fund (to active members by hours worked).',
       source = 'Draft MPC bylaws v4.15 s.14(2)' where key = 'split_member_pct';
update ww.rule_defaults set source = 'Design Principles v0.3 (bylaws v4.15 does not define an active member yet)' where key = 'active_min_hours';
insert into ww.rule_defaults (key, value, purpose_np, purpose_en, source) values
 ('max_shares',       '1',      'एक सदस्यको एक कित्ताभन्दा बढी शेयर हुँदैन।', 'No member holds more than one share.', 'Draft MPC bylaws v4.15 s.7(1)'),
 ('member_loan_rate', '10',     'सदस्यको परियोजना ऋणमा सबैलाई एउटै ब्याजदर, हाल वार्षिक १०%; सम्झौताको पूरा अवधि कायम।', 'Members'' project loans all earn one rate, now 10% a year, fixed for the agreement.', 'Draft MPC bylaws v4.15 s.8(1)'),
 ('notice_loan_max',  '100000', 'रु १ लाखसम्मको परियोजना ऋण सूचना दिएर ब्याजसहित फिर्ता लिन सकिन्छ।', 'Project loans up to Rs 1 lakh are repaid with interest on notice.', 'Draft MPC bylaws v4.15 s.8(2)'),
 ('notice_days',      '90',     'फिर्ता लिन ३ महिनाअघि सूचना दिनुपर्छ।', 'Three months'' notice to withdraw.', 'Draft MPC bylaws v4.15 s.8(2)'),
 ('fixed_term_min_months', '36', 'रु १ लाखभन्दा बढीको परियोजना ऋण कम्तीमा ३ वर्षको।', 'Project loans above Rs 1 lakh run at least 3 years.', 'Draft MPC bylaws v4.15 s.8(3)'),
 ('fixed_term_max_months', '60', 'रु १ लाखभन्दा बढीको परियोजना ऋण बढीमा ५ वर्षको।', 'Project loans above Rs 1 lakh run at most 5 years.', 'Draft MPC bylaws v4.15 s.8(3)')
on conflict (key) do nothing;

update ww.accounts set name_np = 'संरक्षित पूँजी फिर्ता कोष', name_en = 'Protected capital return fund' where code = 'EQ-MEMBER';
update ww.accounts set name_np = 'परियोजना ऋण तथा अन्य ऋण', name_en = 'Project loans and other loans payable' where code = 'LI-LOAN';

-- members: 16+ ----------------------------------------------------------------
create or replace function ww.v_member_admitted(e ww.events) returns ww.events
language plpgsql as $$
declare pid uuid := ww.req_uuid(e.private, 'person_id');
begin
  perform ww.require_mpc(e);
  perform ww.req_text(e.payload, 'decision_ref');
  if (e.payload->>'member_no') !~ '^[0-9]+$' then perform ww.reject('"member_no" must be a number'); end if;
  if coalesce((e.private->>'self_declaration')::boolean, false) is not true then
    perform ww.reject('the person''s signed self-declaration (16+, Nepali citizen, living in the working area, accepts the bylaws) is required');
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

-- shares: exactly one ---------------------------------------------------------
create or replace function ww.v_shares_purchased(e ww.events) returns ww.events
language plpgsql as $$
declare pid uuid := ww.req_uuid(e.private, 'person_id');
        k int; amt numeric := ww.req_amount(e.payload, 'amount');
        price numeric := (ww.rule(e.entity_id, 'share_price'))::numeric; held int;
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
    perform ww.reject(format('a member holds at least %s share(s)', ww.rule(e.entity_id, 'min_shares')));
  end if;
  if held > (ww.rule(e.entity_id, 'max_shares'))::int then
    perform ww.reject(format('every member holds exactly %s share; to earn interest, make a project loan instead', ww.rule(e.entity_id, 'max_shares')));
  end if;
  return ww.with_voucher(e);
end $$;

-- loans: project loans from members, capped loans from others ------------------
-- loan.received payload adds "withdrawal": 'notice' (members, up to Rs 1 lakh) or 'fixed' (term set)
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
             and not ww.is_corrected(r.ward_id, r.seq)), ev.occurred_on) as last_paid_on,
       coalesce(ev.payload->>'withdrawal', 'fixed') as withdrawal,
       n.occurred_on as notice_given_on,
       (n.payload->>'repay_from')::date as repay_due_on,
       (n.payload->>'amount')::numeric as notice_amount
from ww.events ev
left join lateral (
  select nv.occurred_on, nv.payload from ww.events nv
   where nv.type = 'loan.notice_given' and nv.entity_id = ev.entity_id and nv.payload->>'loan_id' = ev.payload->>'loan_id'
     and not ww.is_corrected(nv.ward_id, nv.seq)
     and not exists (select 1 from ww.events r where r.type = 'loan.repaid' and r.entity_id = nv.entity_id
                      and r.payload->>'loan_id' = nv.payload->>'loan_id' and r.seq > nv.seq
                      and coalesce((r.payload->>'principal')::numeric, 0) > 0 and not ww.is_corrected(r.ward_id, r.seq))
   order by nv.seq desc limit 1) n on true
where ev.type = 'loan.received' and not ww.is_corrected(ev.ward_id, ev.seq);

create or replace function ww.v_loan_received(e ww.events) returns ww.events
language plpgsql as $$
declare cap numeric := (ww.rule(e.entity_id, 'loan_rate_cap'))::numeric;
        member_rate numeric := (ww.rule(e.entity_id, 'member_loan_rate'))::numeric;
        notice_max numeric := (ww.rule(e.entity_id, 'notice_loan_max'))::numeric;
        tmin int := (ww.rule(e.entity_id, 'fixed_term_min_months'))::int;
        tmax int := (ww.rule(e.entity_id, 'fixed_term_max_months'))::int;
        amt numeric; rate numeric; term int; pid uuid; related boolean := false; kind text;
begin
  perform ww.require_mpc(e);
  perform ww.req_uuid(e.payload, 'loan_id');
  amt := ww.req_amount(e.payload, 'amount');
  perform ww.req_text(e.payload, 'decision_ref');
  if exists (select 1 from ww.v_loans where loan_id = (e.payload->>'loan_id')::uuid) then perform ww.reject('this loan already exists'); end if;
  begin rate := (e.payload->>'rate_pct')::numeric; exception when others then rate := null; end;
  if rate is null or rate < 0 then perform ww.reject('"rate_pct" must be zero or more (fees included)'); end if;
  if coalesce(e.payload->>'term_months', '') <> '' and (e.payload->>'term_months') !~ '^[1-9][0-9]*$' then
    perform ww.reject('"term_months" must be a whole number of months');
  end if;
  term := nullif(e.payload->>'term_months', '')::int;
  case e.payload->>'lender_kind'
    when 'member' then
      pid := ww.req_uuid(e.private, 'person_id');
      if not exists (select 1 from ww.members where entity_id = e.entity_id and person_id = pid and left_seq is null) then
        perform ww.reject('a person lending must be a member');
      end if;
      if e.payload ? 'lender_name' then perform ww.reject('a member''s name goes in the private part'); end if;
      if rate <> member_rate then
        perform ww.reject(format('every member''s project loan earns the same rate: %s%% a year', member_rate));
      end if;
      if amt <= notice_max then
        kind := case when term is null then 'notice' else 'fixed' end;
        if term is not null and (term < tmin or term > tmax) then
          perform ww.reject(format('a fixed project loan runs %s to %s months', tmin, tmax));
        end if;
      else
        kind := 'fixed';
        if term is null or term < tmin or term > tmax then
          perform ww.reject(format('a project loan above Rs %s runs a fixed %s to %s months', notice_max, tmin, tmax));
        end if;
      end if;
      -- officers and their households stand aside from deciding it (s.10(3)); the register shows it
      related := exists (select 1 from ww.role_terms rt join ww.persons p on p.id = rt.person_id
                          join ww.persons l on l.id = pid
                          where rt.entity_id = e.entity_id and rt.to_seq is null
                            and (p.id = l.id or p.household_id = l.household_id));
    when 'organisation', 'bank' then
      perform ww.req_text(e.payload, 'lender_name');
      if term is null then perform ww.reject('"term_months" is required'); end if;
      if rate > cap then perform ww.reject(format('interest above %s%% is not allowed', cap)); end if;
      kind := 'fixed';
    else perform ww.reject('lender_kind must be member, organisation or bank');
  end case;
  perform ww.req_method(e.payload);
  e.payload := e.payload || jsonb_build_object('related_party', related, 'withdrawal', kind);
  return ww.with_voucher(e);
end $$;

-- loan.notice_given: payload {loan_id, amount?} — the lender gives notice in चौतारी (s.8(2), s.9(3))
create or replace function ww.v_loan_notice_given(e ww.events) returns ww.events
language plpgsql as $$
declare l ww.v_loans; amt numeric;
begin
  perform ww.require_mpc(e);
  select * into l from ww.v_loans where loan_id = ww.req_uuid(e.payload, 'loan_id') and entity_id = e.entity_id;
  if not found then perform ww.reject('unknown loan'); end if;
  if l.lender_kind <> 'member' or l.lender_person_id is distinct from e.actor then
    perform ww.reject('only the member who made the loan can give notice');
  end if;
  if l.withdrawal <> 'notice' then
    perform ww.reject('this project loan has a fixed term; it is repaid when the term ends');
  end if;
  if l.outstanding <= 0 then perform ww.reject('nothing is outstanding on this loan'); end if;
  if l.notice_given_on is not null then perform ww.reject('notice is already given and not yet repaid'); end if;
  amt := coalesce(nullif(e.payload->>'amount', '')::numeric, l.outstanding);
  if amt <= 0 or amt > l.outstanding then perform ww.reject(format('notice can be for up to Rs %s', l.outstanding)); end if;
  e.payload := e.payload || jsonb_build_object('amount', amt,
                 'repay_from', e.occurred_on + (ww.rule(e.entity_id, 'notice_days'))::int);
  return e;
end $$;

insert into ww.event_types (type, allowed_roles, needs_fy, validator, projector, description) values
 ('loan.notice_given', null, false, 'ww.v_loan_notice_given(ww.events)', null,
  'A member gives 3 months'' notice to withdraw a project loan')
on conflict (type) do nothing;

-- the public register (s.8; read at every assembly) ----------------------------
create or replace view public.loan_register as
select entity_id, loan_id, lender_kind,
       case when lender_kind = 'member' then null else lender_name end as lender_name,
       amount, rate_pct, term_months, outstanding, interest_paid, related_party, decision_ref, received_on,
       withdrawal, notice_given_on, repay_due_on, notice_amount
from ww.v_loans;
revoke all on public.loan_register from public;
do $$ begin
  if exists (select 1 from pg_roles where rolname = 'anon') then
    execute 'revoke all on public.loan_register from anon, authenticated';
    execute 'grant select on public.loan_register to anon, authenticated';
  end if;
end $$;

-- a member's account shows the notice and the dates ----------------------------
create or replace function public.my_account(p_entity text, p_fiscal_year text default null)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  me ww.persons; m ww.members; fy text; rate numeric; pay_ids uuid[];
  shares_kitta int; shares_value numeric;
  appr_paid_h numeric; pend_h numeric; paid_h numeric; wages_due numeric; wages_paid numeric;
  loans jsonb; loan_out numeric; benefit_due numeric; benefits jsonb;
  est jsonb; my_h numeric; all_h numeric; statement jsonb;
begin
  select * into me from ww.persons where id = ww.current_person();
  if me.id is null then raise exception 'this login is not linked to a registered person'; end if;
  if ww.entity_kind(p_entity) is distinct from 'mpc' then raise exception 'unknown cooperative %', p_entity; end if;
  select * into m from ww.members where entity_id = p_entity and person_id = me.id;
  if m.person_id is null then
    return jsonb_build_object('member', false, 'name', me.display_name);
  end if;

  fy := coalesce(p_fiscal_year, (select max(fiscal_year) from ww.events where entity_id = p_entity));
  rate := (ww.rule(p_entity, 'hourly_rate'))::numeric;
  pay_ids := array(select id from ww.payees where entity_id = p_entity and person_id = me.id);

  shares_kitta := ww.shares_held(p_entity, me.id);
  select coalesce(sum(amount), 0) into shares_value from ww.v_share_moves where entity_id = p_entity and person_id = me.id;

  select coalesce(sum(w.hours) filter (where w.status = 'approved' and w.paid), 0),
         coalesce(sum(w.hours) filter (where w.status = 'pending'), 0),
         coalesce(sum(w.hours) filter (where w.status = 'approved' and w.paid and exists (
            select 1 from ww.wage_links l join ww.expenses x on x.id = l.expense_id where l.work_id = w.id and x.status = 'paid')), 0)
    into appr_paid_h, pend_h, paid_h
    from ww.work_logs w join ww.events ev on ev.ward_id = me.ward_id and ev.seq = w.logged_seq
   where w.entity_id = p_entity and w.person_id = me.id and coalesce(ev.fiscal_year, fy) = fy;
  -- approved paid hours not yet on a paid wage voucher
  select coalesce(sum(w.hours), 0) * rate into wages_due
    from ww.work_logs w
   where w.entity_id = p_entity and w.person_id = me.id and w.status = 'approved' and w.paid
     and not exists (select 1 from ww.wage_links l join ww.expenses x on x.id = l.expense_id
                      where l.work_id = w.id and x.status = 'paid');
  select coalesce(sum(amount), 0) into wages_paid from ww.expenses
   where entity_id = p_entity and payee_id = any (pay_ids) and account_code = 'EX-WAGES' and status = 'paid' and fiscal_year = fy;

  select coalesce(jsonb_agg(jsonb_build_object('loan_id', loan_id, 'amount', amount, 'rate_pct', rate_pct,
           'term_months', term_months, 'received_on', received_on, 'outstanding', outstanding, 'interest_paid', interest_paid,
           'withdrawal', withdrawal, 'notice_given_on', notice_given_on, 'repay_due_on', repay_due_on,
           'term_ends_on', case when term_months is not null then (received_on + make_interval(months => term_months))::date end)), '[]'),
         coalesce(sum(outstanding), 0)
    into loans, loan_out from ww.v_loans where entity_id = p_entity and lender_person_id = me.id;

  select coalesce(jsonb_agg(jsonb_build_object('fiscal_year', b.fiscal_year, 'hours', b.hours, 'amount', b.amount,
           'paid', exists (select 1 from ww.events ev where ev.entity_id = p_entity and ev.type = 'benefit.paid'
                             and ev.private->>'person_id' = me.id::text and ev.payload->>'benefit_year' = b.fiscal_year
                             and not ww.is_corrected(ev.ward_id, ev.seq)))), '[]')
    into benefits from ww.member_benefits b where b.entity_id = p_entity and b.person_id = me.id;
  select coalesce(sum((b->>'amount')::numeric) filter (where not (b->>'paid')::boolean), 0) into benefit_due
    from jsonb_array_elements(benefits) b;

  -- this year's member benefit, if the year ended today (an estimate until the audit)
  est := ww.split(p_entity, greatest(ww.net_surplus(p_entity, fy), 0));
  select coalesce(sum(hours) filter (where person_id = me.id), 0), coalesce(sum(hours), 0)
    into my_h, all_h from ww.member_hours(p_entity, fy);
  est := est || jsonb_build_object('my_hours', my_h, 'all_member_hours', all_h,
           'my_share', case when all_h > 0 then floor((est->>'member')::numeric * my_h / all_h) else 0 end,
           'active_min_hours', ww.rule(p_entity, 'active_min_hours'));

  select coalesce(jsonb_agg(s order by s->>'date' desc, (s->>'seq')::bigint desc), '[]') into statement from (
    select jsonb_build_object('seq', ev.seq, 'date', ev.occurred_on, 'kind', 'shares_bought', 'voucher_no', ev.payload->'voucher_no',
             'kitta', (ev.payload->>'kitta')::int, 'amount', (ev.payload->>'amount')::numeric, 'direction', 'in') s
      from ww.events ev where ev.entity_id = p_entity and ev.type = 'shares.purchased' and ev.private->>'person_id' = me.id::text
       and not ww.is_corrected(ev.ward_id, ev.seq)
    union all
    select jsonb_build_object('seq', ev.seq, 'date', ev.occurred_on, 'kind', 'shares_refunded', 'voucher_no', ev.payload->'voucher_no',
             'kitta', (ev.payload->>'kitta')::int, 'amount', (ev.payload->>'amount')::numeric, 'direction', 'to_me')
      from ww.events ev where ev.entity_id = p_entity and ev.type = 'shares.refunded' and ev.private->>'person_id' = me.id::text
       and not ww.is_corrected(ev.ward_id, ev.seq)
    union all
    select jsonb_build_object('seq', ev.seq, 'date', ev.occurred_on, 'kind', case x.account_code when 'EX-WAGES' then 'wages' else 'payment' end,
             'voucher_no', ev.payload->'voucher_no', 'amount', x.amount, 'memo_np', x.memo_np, 'direction', 'to_me',
             'hours', (select sum(w.hours) from ww.work_logs w where w.id = any (x.work_ids)))
      from ww.expenses x join ww.events ev on ev.ward_id = me.ward_id and ev.seq = x.status_seq
     where x.entity_id = p_entity and x.payee_id = any (pay_ids) and x.status = 'paid'
    union all
    select jsonb_build_object('seq', ev.seq, 'date', ev.occurred_on, 'kind', 'benefit', 'voucher_no', ev.payload->'voucher_no',
             'amount', (ev.payload->>'amount')::numeric, 'benefit_year', ev.payload->>'benefit_year', 'direction', 'to_me')
      from ww.events ev where ev.entity_id = p_entity and ev.type = 'benefit.paid' and ev.private->>'person_id' = me.id::text
       and not ww.is_corrected(ev.ward_id, ev.seq)
    union all
    select jsonb_build_object('seq', ev.seq, 'date', ev.occurred_on, 'kind', 'loan_given', 'voucher_no', ev.payload->'voucher_no',
             'amount', (ev.payload->>'amount')::numeric, 'rate_pct', (ev.payload->>'rate_pct')::numeric, 'direction', 'in')
      from ww.events ev where ev.entity_id = p_entity and ev.type = 'loan.received' and ev.private->>'person_id' = me.id::text
       and not ww.is_corrected(ev.ward_id, ev.seq)
    union all
    select jsonb_build_object('seq', ev.seq, 'date', ev.occurred_on, 'kind', 'loan_notice', 'amount', (ev.payload->>'amount')::numeric,
             'repay_from', ev.payload->>'repay_from', 'direction', 'note')
      from ww.events ev join ww.v_loans l on l.loan_id::text = ev.payload->>'loan_id'
     where ev.entity_id = p_entity and ev.type = 'loan.notice_given' and l.lender_person_id = me.id and not ww.is_corrected(ev.ward_id, ev.seq)
    union all
    select jsonb_build_object('seq', r.seq, 'date', r.occurred_on, 'kind', 'loan_repaid', 'voucher_no', r.payload->'voucher_no',
             'amount', coalesce((r.payload->>'principal')::numeric, 0) + coalesce((r.payload->>'interest')::numeric, 0),
             'principal', (r.payload->>'principal')::numeric, 'interest', (r.payload->>'interest')::numeric, 'direction', 'to_me')
      from ww.events r join ww.v_loans l on l.loan_id::text = r.payload->>'loan_id'
     where r.entity_id = p_entity and r.type = 'loan.repaid' and l.lender_person_id = me.id and not ww.is_corrected(r.ward_id, r.seq)
  ) q;

  return jsonb_build_object(
    'member', true,
    'name', me.display_name,
    'member_no', m.member_no,
    'since', m.admitted_on,
    'active', m.left_seq is null,
    'house_no', (select house_no from ww.households where id = me.household_id),
    'fiscal_year', fy,
    'hourly_rate', rate,
    'my_money', shares_value + loan_out + wages_due + benefit_due,
    'shares', jsonb_build_object('kitta', shares_kitta, 'value', shares_value,
                'price', ww.rule(p_entity, 'share_price'), 'min', ww.rule(p_entity, 'min_shares'), 'max', ww.rule(p_entity, 'max_shares')),
    'work', jsonb_build_object('approved_paid_hours', appr_paid_h, 'pending_hours', pend_h, 'paid_hours', paid_h,
                'wages_paid', wages_paid, 'wages_due', wages_due),
    'loans', loans, 'loans_outstanding', loan_out,
    'benefits', benefits, 'benefit_due', benefit_due,
    'benefit_estimate', est,
    'statement', statement);
end $$;


revoke all on function public.my_account(text, text) from public;
do $$ begin
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    execute 'grant execute on function public.my_account(text, text) to authenticated';
  end if;
end $$;
