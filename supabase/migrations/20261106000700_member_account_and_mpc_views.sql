-- Chautari — 0007: the member's account (मेरो खाता) and the cooperative's public views

-- helpers the public views call run as their owner (see 0005)
alter function ww.is_corrected(text, bigint)   security definer set search_path = '';
alter function ww.share_capital(text)          security definer set search_path = '';
do $$ begin
  if exists (select 1 from pg_roles where rolname = 'anon') then
    execute 'grant execute on function ww.is_corrected(text, bigint), ww.share_capital(text) to anon, authenticated';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- The world: the cooperative in totals
-- ---------------------------------------------------------------------------
create or replace view public.mpc_summary as
select en.id as entity_id,
       (select count(*) from ww.members m where m.entity_id = en.id and m.left_seq is null) as members,
       ww.share_capital(en.id) as share_capital,
       coalesce((select sum(outstanding) from ww.v_loans l where l.entity_id = en.id), 0) as loans_outstanding,
       coalesce((select sum(amount - used) from ww.v_grants g where g.entity_id = en.id), 0) as grants_unspent,
       -ww.balance(en.id, 'EQ-RESERVE')   as reserve_fund,
       -ww.balance(en.id, 'EQ-PROMO')     as promotion_fund,
       -ww.balance(en.id, 'EQ-COMMUNITY') as community_fund,
       -ww.balance(en.id, 'EQ-MEMBER')    as member_benefit_fund,
       -ww.balance(en.id, 'EQ-CAPITAL')   as capital_fund,
       ww.balance(en.id, 'BS-BANK') as in_bank, ww.balance(en.id, 'BS-CASH') as cash_in_hand,
       (ww.rule(en.id, 'hourly_rate'))::numeric as hourly_rate
from ww.entities en where en.kind = 'mpc';

-- the loan register is read at every assembly (s.24(8)); a member lender is named only to members
create or replace view public.loan_register as
select entity_id, loan_id, lender_kind,
       case when lender_kind = 'member' then null else lender_name end as lender_name,
       amount, rate_pct, term_months, outstanding, interest_paid, related_party, decision_ref, received_on
from ww.v_loans;

create or replace view public.grant_register as
select entity_id, grant_id, donor, purpose_np, amount, used, amount - used as unspent, agreement_ref, received_on
from ww.v_grants;

create or replace view public.enterprise_results as select * from ww.v_enterprise_results;

create or replace view public.surplus_allocations as
select entity_id, fiscal_year, occurred_on, (payload->>'net')::numeric as net, (payload->>'reserve')::numeric as reserve,
       (payload->>'promotion')::numeric as promotion, (payload->>'community')::numeric as community,
       (payload->>'member')::numeric as member, (payload->>'capital')::numeric as capital,
       (payload->>'active_members')::int as active_members, (payload->>'active_hours')::numeric as active_hours,
       payload->>'decision_ref' as decision_ref, payload->>'audit_ref' as audit_ref
from ww.events where type = 'surplus.allocated' and not ww.is_corrected(ward_id, seq);

do $$
declare v text;
begin
  foreach v in array array['mpc_summary', 'loan_register', 'grant_register', 'enterprise_results', 'surplus_allocations'] loop
    execute format('revoke all on public.%I from public', v);
    if exists (select 1 from pg_roles where rolname = 'anon') then
      execute format('revoke all on public.%I from anon, authenticated', v);
      execute format('grant select on public.%I to anon, authenticated', v);
    end if;
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- A member: my account, like a bank app — only my own money in the cooperative
-- ---------------------------------------------------------------------------
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
           'term_months', term_months, 'received_on', received_on, 'outstanding', outstanding, 'interest_paid', interest_paid)), '[]'),
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
                'price', ww.rule(p_entity, 'share_price'), 'min', ww.rule(p_entity, 'min_shares')),
    'work', jsonb_build_object('approved_paid_hours', appr_paid_h, 'pending_hours', pend_h, 'paid_hours', paid_h,
                'wages_paid', wages_paid, 'wages_due', wages_due),
    'loans', loans, 'loans_outstanding', loan_out,
    'benefits', benefits, 'benefit_due', benefit_due,
    'benefit_estimate', est,
    'statement', statement);
end $$;

-- Officers: the share register with names (board and accounts committee)
create or replace function public.officer_share_register(p_entity text)
returns table (member_no int, name text, house_no int, kitta int, value numeric, since date, active boolean)
language plpgsql stable security definer set search_path = '' as $$
begin
  perform ww.require_office(p_entity, array['chair', 'secretary', 'treasurer', 'accounts_committee']);
  return query
  select m.member_no, p.display_name, h.house_no, ww.shares_held(p_entity, m.person_id),
         coalesce((select sum(amount) from ww.v_share_moves s where s.entity_id = p_entity and s.person_id = m.person_id), 0),
         m.admitted_on, m.left_seq is null
  from ww.members m join ww.persons p on p.id = m.person_id left join ww.households h on h.id = p.household_id
  where m.entity_id = p_entity order by m.member_no;
end $$;

do $$
declare f text;
begin
  foreach f in array array['public.my_account(text, text)', 'public.officer_share_register(text)'] loop
    execute format('revoke all on function %s from public', f);
    if exists (select 1 from pg_roles where rolname = 'authenticated') then
      execute format('grant execute on function %s to authenticated', f);
    end if;
  end loop;
end $$;
