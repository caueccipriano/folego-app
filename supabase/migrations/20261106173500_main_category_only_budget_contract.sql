-- Main-category-only planning. Subcategories remain transaction classifications.
-- Preserve historical child rows for audit; never treat them as independent budgets.
-- Future/current effective parent budgets were consolidated separately and are
-- preferred over legacy child fallback by get_budget_overview.
--
-- This migration makes *all* consuming surfaces receive zero subcategory limits
-- without touching financial events, paid invoices or balance reconciliation.

CREATE OR REPLACE FUNCTION private.set_budget_limit_impl(p_space_id uuid, p_period_month date, p_category_id uuid, p_planned_amount numeric, p_scope text, p_warning_threshold numeric DEFAULT 0.70, p_critical_threshold numeric DEFAULT 0.90)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_month date := date_trunc('month',p_period_month)::date;
  v_current_month date;
  v_previous_month date;
  v_budget_id uuid;
  v_has_recurring boolean := false;
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if not private.can_write_space(p_space_id) then
    raise exception 'write_access_denied' using errcode='42501';
  end if;
  if p_planned_amount is null or p_planned_amount < 0 then
    raise exception 'budget_amount_cannot_be_negative';
  end if;
  if p_scope not in ('month','from_month','cancel_from_month') then
    raise exception 'invalid_budget_scope';
  end if;
  if p_warning_threshold <= 0 or p_warning_threshold > 1 or p_critical_threshold <= 0 or p_critical_threshold > 1 or p_critical_threshold < p_warning_threshold then
    raise exception 'invalid_budget_thresholds';
  end if;
  if not exists(
    select 1
    from public.categories c
    where c.id=p_category_id
      and c.space_id=p_space_id
      and c.kind='expense'
      and c.active
      and c.category_role='economic'
      and c.parent_id is null
  ) then
    raise exception 'budget_requires_main_category';
  end if;

  select date_trunc('month',(now() at time zone coalesce(fs.timezone,'America/Sao_Paulo'))::date)::date
    into v_current_month
  from public.financial_spaces fs
  where fs.id=p_space_id;

  if p_scope in ('from_month','cancel_from_month') and v_month < v_current_month then
    raise exception 'historical_recurring_budget_is_immutable';
  end if;

  select exists(
    select 1
    from public.budget_recurring_rules r
    where r.space_id=p_space_id
      and r.category_id=p_category_id
      and r.effective_from <= v_month
      and (r.effective_until is null or r.effective_until >= v_month)
  ) into v_has_recurring;

  if p_scope='month' then
    if p_planned_amount=0 and not v_has_recurring then
      delete from public.budget_items bi
      using public.budgets b
      where bi.budget_id=b.id
        and bi.space_id=p_space_id
        and b.space_id=p_space_id
        and b.period_month=v_month
        and bi.category_id=p_category_id;
      return true;
    end if;

    insert into public.budgets(space_id,period_month,status)
    values(p_space_id,v_month,'active')
    on conflict(space_id,period_month) do update set status='active',updated_at=now()
    returning id into v_budget_id;

    insert into public.budget_items(space_id,budget_id,category_id,planned_amount,warning_threshold,critical_threshold)
    values(p_space_id,v_budget_id,p_category_id,p_planned_amount,p_warning_threshold,p_critical_threshold)
    on conflict(budget_id,category_id) do update
      set planned_amount=excluded.planned_amount,
          warning_threshold=excluded.warning_threshold,
          critical_threshold=excluded.critical_threshold,
          updated_at=now();
    return true;
  end if;

  v_previous_month := (v_month-interval '1 month')::date;

  delete from public.budget_recurring_rules r
  where r.space_id=p_space_id
    and r.category_id=p_category_id
    and r.effective_from >= v_month;

  update public.budget_recurring_rules r
  set effective_until=v_previous_month,updated_at=now()
  where r.space_id=p_space_id
    and r.category_id=p_category_id
    and r.effective_from < v_month
    and (r.effective_until is null or r.effective_until >= v_month);

  if p_scope='cancel_from_month' then return true; end if;
  if p_planned_amount <= 0 then raise exception 'recurring_budget_amount_must_be_positive'; end if;

  insert into public.budget_recurring_rules(
    space_id,category_id,planned_amount,warning_threshold,critical_threshold,effective_from,effective_until
  ) values (
    p_space_id,p_category_id,p_planned_amount,p_warning_threshold,p_critical_threshold,v_month,null
  );

  insert into public.budgets(space_id,period_month,status)
  values(p_space_id,v_month,'active')
  on conflict(space_id,period_month) do update set status='active',updated_at=now()
  returning id into v_budget_id;

  insert into public.budget_items(space_id,budget_id,category_id,planned_amount,warning_threshold,critical_threshold)
  values(p_space_id,v_budget_id,p_category_id,p_planned_amount,p_warning_threshold,p_critical_threshold)
  on conflict(budget_id,category_id) do update
    set planned_amount=excluded.planned_amount,
        warning_threshold=excluded.warning_threshold,
        critical_threshold=excluded.critical_threshold,
        updated_at=now();

  return true;
end;
$function$


CREATE OR REPLACE FUNCTION private.onboarding_set_budget_item_impl(p_space_id uuid, p_period_month date, p_category_id uuid, p_planned_amount numeric, p_warning_threshold numeric DEFAULT 0.70, p_critical_threshold numeric DEFAULT 0.90)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_budget_id uuid;
  v_item_id uuid;
  v_month date;
begin
  if not private.can_write_space(p_space_id) then
    raise exception 'Not allowed to write this financial space' using errcode='42501';
  end if;
  if p_planned_amount < 0 then raise exception 'Budget amount cannot be negative'; end if;
  if p_warning_threshold <= 0 or p_warning_threshold > 1 or p_critical_threshold <= 0 or p_critical_threshold > 1 or p_critical_threshold < p_warning_threshold then
    raise exception 'Invalid budget thresholds';
  end if;
  if not exists(
    select 1
    from public.categories c
    where c.id=p_category_id
      and c.space_id=p_space_id
      and c.kind='expense'
      and c.active
      and c.category_role='economic'
      and c.parent_id is null
  ) then
    raise exception 'Budget requires an expense main category';
  end if;

  v_month := date_trunc('month',p_period_month)::date;
  insert into public.budgets(space_id,period_month,status)
  values(p_space_id,v_month,'active')
  on conflict(space_id,period_month) do update set status='active',updated_at=now()
  returning id into v_budget_id;

  insert into public.budget_items(space_id,budget_id,category_id,planned_amount,warning_threshold,critical_threshold)
  values(p_space_id,v_budget_id,p_category_id,p_planned_amount,p_warning_threshold,p_critical_threshold)
  on conflict(budget_id,category_id) do update
    set planned_amount=excluded.planned_amount,
        warning_threshold=excluded.warning_threshold,
        critical_threshold=excluded.critical_threshold,
        updated_at=now()
  returning id into v_item_id;

  return v_item_id;
end;
$function$


CREATE OR REPLACE FUNCTION public.get_budget_overview(p_space_id uuid, p_period_month date)
 RETURNS TABLE(category_id uuid, category_name text, parent_id uuid, parent_name text, color_hex text, essential boolean, planned_amount numeric, actual_amount numeric, remaining_amount numeric, warning_threshold numeric, critical_threshold numeric, usage_ratio numeric, status text, budget_source text, is_recurring boolean)
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
with access as (
  select private.is_space_member(p_space_id) as allowed
),
period as (
  select date_trunc('month',p_period_month)::date as month_start,
         (date_trunc('month',p_period_month)+interval '1 month')::date as next_month
),
selected_budget as (
  select b.id
  from public.budgets b,period p,access a
  where a.allowed and b.space_id=p_space_id and b.period_month=p.month_start
  order by b.created_at desc
  limit 1
),
monthly_values as (
  select bi.category_id,bi.planned_amount,bi.warning_threshold,bi.critical_threshold
  from public.budget_items bi
  join selected_budget sb on sb.id=bi.budget_id
  where bi.space_id=p_space_id
),
recurring_values as (
  select distinct on (r.category_id)
    r.category_id,r.planned_amount,r.warning_threshold,r.critical_threshold,r.id
  from public.budget_recurring_rules r
  cross join period p
  cross join access a
  where a.allowed
    and r.space_id=p_space_id
    and r.effective_from <= p.month_start
    and (r.effective_until is null or r.effective_until >= p.month_start)
  order by r.category_id,r.effective_from desc,r.created_at desc
),
effective_values as (
  select c.id as category_id,
    case when mv.category_id is not null then mv.planned_amount else coalesce(rv.planned_amount,0::numeric) end as planned_amount,
    case when mv.category_id is not null then mv.warning_threshold else coalesce(rv.warning_threshold,0.70::numeric) end as warning_threshold,
    case when mv.category_id is not null then mv.critical_threshold else coalesce(rv.critical_threshold,0.90::numeric) end as critical_threshold,
    case
      when mv.category_id is not null and rv.category_id is not null then 'override'::text
      when mv.category_id is not null then 'month'::text
      when rv.category_id is not null then 'recurring'::text
      else 'none'::text
    end as budget_source,
    (rv.category_id is not null) as is_recurring
  from public.categories c
  left join monthly_values mv on mv.category_id=c.id
  left join recurring_values rv on rv.category_id=c.id
  cross join access a
  where a.allowed
    and c.space_id=p_space_id
    and c.kind='expense'
    and c.active
    and c.category_role='economic'
),
budget_postings as (
  -- Economic spending remains the source of all regular budget usage.
  select coalesce(i.category_id,e.category_id) as category_id,
         i.amount::numeric as signed_amount
  from public.financial_impacts i
  join public.financial_events e on e.id=i.event_id and e.space_id=i.space_id
  cross join period p
  cross join access a
  where a.allowed and i.space_id=p_space_id and i.dimension='budget'
    and i.effective_date>=p.month_start and i.effective_date<p.next_month
    and e.status='confirmed'
    and coalesce(i.category_id,e.category_id) is not null

  union all

  -- Paying down an existing debt is a cash obligation, NOT an additional
  -- economic expense. Budget tracking still must consume the loan limit.
  -- Never write a new cash/economic impact, and avoid double counting
  -- if a legacy debt event already owns a budget impact.
  select coalesce(i.category_id,e.category_id,
    (select c.id from public.categories c
     where c.space_id=p_space_id and c.system_key='expense.debt.loans'
       and c.kind='expense' and c.active and c.category_role='economic'
     limit 1)) as category_id,
    i.amount::numeric as signed_amount
  from public.financial_impacts i
  join public.financial_events e on e.id=i.event_id and e.space_id=i.space_id
  cross join period p
  cross join access a
  where a.allowed and i.space_id=p_space_id and i.dimension='cash'
    and i.amount<0 and e.event_type='debt_payment' and e.status='confirmed'
    and i.effective_date>=p.month_start and i.effective_date<p.next_month
    and exists (
      select 1 from public.debt_payments dp where dp.space_id=e.space_id
        and dp.event_id=e.id and dp.status='confirmed')
    and not exists (
      select 1 from public.financial_impacts b where b.space_id=e.space_id
        and b.event_id=e.id and b.dimension='budget')
),
actuals_direct as (
  select bp.category_id,
         greatest(0::numeric,-sum(bp.signed_amount)) as actual_amount
  from budget_postings bp
  where bp.category_id is not null
  group by bp.category_id
),
rows as (
  select c.id as category_id,c.name as category_name,c.parent_id,pc.name as parent_name,c.color_hex,c.essential,
    case when c.parent_id is null then case when ev.budget_source <> 'none' then ev.planned_amount else coalesce((
      select sum(ev_child.planned_amount)
      from public.categories child
      join effective_values ev_child on ev_child.category_id=child.id
      where child.space_id=p_space_id
        and child.parent_id=c.id
        and child.active
        and child.category_role='economic'
    ),0::numeric) end else 0::numeric end as planned_amount,
    (coalesce(ad.actual_amount,0::numeric)+case when c.parent_id is null then coalesce((
      select sum(child_actual.actual_amount)
      from public.categories child
      join actuals_direct child_actual on child_actual.category_id=child.id
      where child.space_id=p_space_id
        and child.parent_id=c.id
        and child.active
        and child.category_role='economic'
    ),0::numeric) else 0::numeric end) as actual_amount,
    coalesce(ev.warning_threshold,0.70::numeric) as warning_threshold,
    coalesce(ev.critical_threshold,0.90::numeric) as critical_threshold,
    case when c.category_role='pending' then 'pending'::text
         when c.parent_id is not null then 'none'::text
         when ev.budget_source='none' then 'aggregate'::text
         else coalesce(ev.budget_source,'none'::text) end as budget_source,
    case when c.parent_id is null then coalesce(ev.is_recurring,false) else false end as is_recurring
  from public.categories c
  left join public.categories pc on pc.id=c.parent_id and pc.space_id=c.space_id
  left join effective_values ev on ev.category_id=c.id
  left join actuals_direct ad on ad.category_id=c.id
  cross join access a
  where a.allowed
    and c.space_id=p_space_id
    and c.kind='expense'
    and c.active
    and c.category_role in ('economic','pending')
)
select r.category_id,r.category_name,r.parent_id,r.parent_name,r.color_hex,r.essential,
       r.planned_amount,r.actual_amount,
       (r.planned_amount-r.actual_amount) as remaining_amount,
       r.warning_threshold,r.critical_threshold,
       case when r.planned_amount>0 then r.actual_amount/r.planned_amount else 0::numeric end as usage_ratio,
       case
         when r.planned_amount<=0 then 'none'::text
         when (r.actual_amount/r.planned_amount)>1 then 'exceeded'::text
         when (r.actual_amount/r.planned_amount)>=r.warning_threshold then 'warning'::text
         else 'ok'::text
       end as status,
       r.budget_source,r.is_recurring
from rows r
order by coalesce(r.parent_name,r.category_name),case when r.parent_id is null then 0 else 1 end,r.category_name;
$function$


CREATE OR REPLACE FUNCTION public.get_flexible_budget_overview(p_space_id uuid, p_period_month date)
 RETURNS TABLE(period_month date, configured boolean, explicit_limit boolean, limit_amount numeric, used_amount numeric, remaining_amount numeric, exceeded_amount numeric, category_limits_total numeric)
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
with
access as (
  select private.is_space_member(p_space_id) as allowed
),
period as (
  select date_trunc('month', p_period_month)::date as month_start,
         (date_trunc('month', p_period_month) + interval '1 month')::date as next_month
),
selected_budget as (
  select b.flexible_limit
  from public.budgets b
  cross join period p
  cross join access a
  where a.allowed
    and b.space_id = p_space_id
    and b.period_month = p.month_start
    and b.status in ('draft','active','closed')
  order by b.created_at desc
  limit 1
),
category_limits as (
  select coalesce(sum(g.planned_amount), 0)::numeric as total
  from period p
  cross join access a
  left join lateral public.get_budget_overview(p_space_id, p.month_start) g
    on a.allowed
  where g.parent_id is null
    and coalesce(g.essential, false) = false
),
usage as (
  select greatest(
    -coalesce(sum(fi.amount) filter (where coalesce(c.essential, false) = false), 0),
    0
  )::numeric as used
  from period p
  cross join access a
  left join public.financial_impacts fi
    on a.allowed
   and fi.space_id = p_space_id
   and fi.dimension = 'budget'
   and fi.effective_date >= p.month_start
   and fi.effective_date < p.next_month
   and exists (
     select 1
     from public.financial_events fe
     where fe.id = fi.event_id
       and fe.space_id = fi.space_id
       and fe.status = 'confirmed'
       and fe.event_type <> 'benefit_expense'
   )
  left join public.categories c on c.id = fi.category_id
),
resolved as (
  select p.month_start,
         sb.flexible_limit,
         cl.total as category_total,
         u.used,
         coalesce(sb.flexible_limit, cl.total, 0)::numeric as effective_limit,
         (sb.flexible_limit is not null or cl.total > 0) as is_configured
  from period p
  cross join category_limits cl
  cross join usage u
  left join selected_budget sb on true
)
select
  r.month_start,
  r.is_configured,
  (r.flexible_limit is not null),
  round(r.effective_limit, 2),
  round(r.used, 2),
  round(greatest(r.effective_limit - r.used, 0), 2),
  round(greatest(r.used - r.effective_limit, 0), 2),
  round(r.category_total, 2)
from resolved r;
$function$


-- In this contract, only main-category planned_amount can be nonzero. Any
-- historical child-budget amounts stay stored but are never offered as limits.
