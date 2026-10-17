-- Applied to Supabase as migration 20260914202913_protect_cash_from_benefit_accounts.
-- Scope: block normal income from benefit accounts and keep Fôlego cash defensive.
-- No historical data is rewritten.

create or replace function private.register_income_impl(
  p_space_id uuid,
  p_account_id uuid,
  p_amount numeric,
  p_description text,
  p_category_id uuid,
  p_occurred_at timestamptz,
  p_competence_date date,
  p_source text,
  p_external_id text
)
returns uuid
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_event_id uuid;
  v_timezone text;
  v_effective_date date;
  v_account_type text;
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if not private.can_write_space(p_space_id) then raise exception 'write_access_denied'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'amount_must_be_positive'; end if;
  if nullif(btrim(p_description),'') is null then raise exception 'description_required'; end if;

  select fs.timezone into v_timezone
  from public.financial_spaces fs
  where fs.id=p_space_id;

  select a.type into v_account_type
  from public.accounts a
  where a.id=p_account_id
    and a.space_id=p_space_id
    and a.active;

  if v_account_type is null then raise exception 'invalid_account'; end if;
  if v_account_type='benefit' then raise exception 'benefit_account_requires_benefit_operation'; end if;

  if p_category_id is not null and not exists (
    select 1
    from public.categories c
    where c.id=p_category_id
      and c.space_id=p_space_id
      and c.active
      and c.kind='income'
  ) then raise exception 'invalid_income_category'; end if;

  v_effective_date := coalesce(
    p_competence_date,
    (coalesce(p_occurred_at,now()) at time zone coalesce(v_timezone,'America/Sao_Paulo'))::date
  );

  insert into public.financial_events(
    space_id,event_type,description,amount,currency,occurred_at,competence_date,category_id,status,source,external_id,metadata
  )
  select p_space_id,'income',btrim(p_description),round(p_amount,2),fs.currency,coalesce(p_occurred_at,now()),v_effective_date,p_category_id,
         'confirmed',coalesce(nullif(btrim(p_source),''),'manual'),p_external_id,'{}'::jsonb
  from public.financial_spaces fs
  where fs.id=p_space_id
  returning id into v_event_id;

  insert into public.financial_impacts(
    event_id,space_id,dimension,amount,account_id,category_id,effective_date
  )
  values
    (v_event_id,p_space_id,'cash',round(p_amount,2),p_account_id,null,v_effective_date),
    (v_event_id,p_space_id,'economic',round(p_amount,2),null,p_category_id,v_effective_date);

  return v_event_id;
end;
$function$;

create or replace function public.get_folego_snapshot(p_space_id uuid, p_as_of_date date default null::date)
returns table(
  as_of_date date,
  next_income_date date,
  next_income_amount numeric,
  days_until_income integer,
  liquid_balance numeric,
  protected_balance numeric,
  mandatory_outflows_until_income numeric,
  cash_headroom numeric,
  monthly_budget_planned numeric,
  monthly_budget_used numeric,
  economic_headroom numeric,
  spendable_pool numeric,
  daily_folego numeric,
  shortfall numeric,
  limiting_factor text,
  status text,
  budget_configured boolean,
  needs_income_setup boolean
)
language sql
stable
set search_path to ''
as $function$
with
params as (
  select p_space_id as space_id,
         coalesce(
           p_as_of_date,
           (now() at time zone (select timezone from public.financial_spaces where id=p_space_id))::date
         ) as as_of_date
),
calendar as (
  select gs::date as d
  from params p,
       generate_series(p.as_of_date::timestamp, (p.as_of_date + 366)::timestamp, interval '1 day') gs
),
account_balances as (
  select
    a.id,
    a.available_for_spending,
    a.type,
    coalesce(
      sum(fi.amount) filter (
        where fi.dimension='cash'
          and fi.effective_date <= p.as_of_date
          and a.type <> 'benefit'
      ),
      0
    )::numeric as balance
  from params p
  join public.accounts a
    on a.space_id=p.space_id
   and a.active
  left join public.financial_impacts fi
    on fi.account_id=a.id
   and fi.space_id=a.space_id
  group by a.id,a.available_for_spending,a.type
),
balances as (
  select
    coalesce(sum(balance) filter (where available_for_spending and type <> 'benefit'),0)::numeric as liquid_balance,
    coalesce(sum(balance) filter (where not available_for_spending and type <> 'benefit'),0)::numeric as protected_balance
  from account_balances
),
income_occurrences as (
  select c.d as occurrence_date, r.amount
  from params p
  join public.recurring_items r on r.space_id=p.space_id
  join calendar c on c.d >= greatest(r.starts_on,p.as_of_date)
                 and (r.ends_on is null or c.d <= r.ends_on)
  where r.active
    and r.item_type='income'
    and r.certainty='confirmed'
    and not exists(
      select 1
      from public.recurring_occurrences ro
      where ro.recurring_item_id=r.id
        and ro.space_id=r.space_id
        and ro.due_date=c.d
        and ro.status in ('realized','skipped','cancelled')
    )
    and (
      (r.frequency='monthly' and extract(day from c.d)::int = least(r.day_of_month::int, extract(day from (date_trunc('month',c.d)+interval '1 month - 1 day'))::int))
      or (r.frequency='weekly' and extract(dow from c.d)::int=r.weekday)
      or (r.frequency='biweekly' and c.d >= r.starts_on and ((c.d-r.starts_on) % 14)=0)
      or (r.frequency='yearly' and extract(month from c.d)::int=r.month_of_year and extract(day from c.d)::int=least(r.day_of_month::int, extract(day from (date_trunc('month',c.d)+interval '1 month - 1 day'))::int))
    )
),
next_income_date_cte as (
  select min(occurrence_date) as income_date from income_occurrences
),
next_income as (
  select n.income_date, coalesce(sum(io.amount),0)::numeric as income_amount
  from next_income_date_cte n
  left join income_occurrences io on io.occurrence_date=n.income_date
  group by n.income_date
),
recurring_expense_occurrences as (
  select c.d as due_date,
         coalesce(ro.expected_amount,r.amount)::numeric as amount
  from params p
  join next_income ni on ni.income_date is not null
  join public.recurring_items r on r.space_id=p.space_id
  join calendar c on c.d >= greatest(r.starts_on,p.as_of_date)
                 and c.d < ni.income_date
                 and (r.ends_on is null or c.d <= r.ends_on)
  left join public.recurring_occurrences ro
    on ro.recurring_item_id=r.id
   and ro.space_id=r.space_id
   and ro.due_date=c.d
  where r.active
    and r.item_type='expense'
    and r.certainty in ('confirmed','expected')
    and coalesce(ro.status,'pending')='pending'
    and (
      (r.frequency='monthly' and extract(day from c.d)::int = least(r.day_of_month::int, extract(day from (date_trunc('month',c.d)+interval '1 month - 1 day'))::int))
      or (r.frequency='weekly' and extract(dow from c.d)::int=r.weekday)
      or (r.frequency='biweekly' and c.d >= r.starts_on and ((c.d-r.starts_on) % 14)=0)
      or (r.frequency='yearly' and extract(month from c.d)::int=r.month_of_year and extract(day from c.d)::int=least(r.day_of_month::int, extract(day from (date_trunc('month',c.d)+interval '1 month - 1 day'))::int))
    )
),
card_due as (
  select coalesce(sum(greatest(0,
    ci.opening_balance + coalesce(inst.installments_total,0) - coalesce(pay.payments_total,0)
  )),0)::numeric as amount
  from params p
  join next_income ni on ni.income_date is not null
  join public.card_invoices ci on ci.space_id=p.space_id
  left join lateral (
    select sum(cinst.amount)::numeric as installments_total
    from public.card_installments cinst
    where cinst.invoice_id=ci.id
      and cinst.status not in ('cancelled','refunded')
  ) inst on true
  left join lateral (
    select sum(cp.amount)::numeric as payments_total
    from public.card_payments cp
    where cp.invoice_id=ci.id
      and cp.status='confirmed'
  ) pay on true
  where ci.status not in ('paid','cancelled')
    and ci.due_date < ni.income_date
),
debt_due as (
  select coalesce(sum(greatest(di.planned_amount-di.paid_amount,0)),0)::numeric as amount
  from params p
  join next_income ni on ni.income_date is not null
  join public.debt_installments di on di.space_id=p.space_id
  where di.status in ('pending','partially_paid','overdue')
    and di.due_date < ni.income_date
),
recurring_due as (
  select coalesce(sum(amount),0)::numeric as amount from recurring_expense_occurrences
),
mandatory as (
  select (
    coalesce((select amount from card_due),0)
    + coalesce((select amount from debt_due),0)
    + coalesce((select amount from recurring_due),0)
  )::numeric as amount
),
month_window as (
  select date_trunc('month',p.as_of_date)::date as month_start,
         (date_trunc('month',p.as_of_date)+interval '1 month')::date as next_month
  from params p
),
budget_totals as (
  select
    coalesce(sum(bi.planned_amount) filter (where coalesce(c.essential,false)=false),0)::numeric as planned,
    (count(bi.id) filter (where coalesce(c.essential,false)=false) > 0) as configured
  from params p
  join month_window mw on true
  left join public.budgets b
    on b.space_id=p.space_id
   and b.period_month=mw.month_start
   and b.status in ('active','closed')
  left join public.budget_items bi on bi.budget_id=b.id
  left join public.categories c on c.id=bi.category_id
),
budget_used as (
  select greatest(
    -coalesce(sum(fi.amount) filter (where coalesce(c.essential,false)=false),0),
    0
  )::numeric as used
  from params p
  join month_window mw on true
  left join public.financial_impacts fi
    on fi.space_id=p.space_id
   and fi.dimension='budget'
   and fi.effective_date >= mw.month_start
   and fi.effective_date < mw.next_month
  left join public.categories c on c.id=fi.category_id
),
base as (
  select
    p.as_of_date,
    ni.income_date,
    ni.income_amount,
    case when ni.income_date is null then null else greatest(ni.income_date-p.as_of_date,1)::int end as days_until_income,
    b.liquid_balance,
    b.protected_balance,
    m.amount as mandatory_outflows,
    (b.liquid_balance-m.amount)::numeric as cash_headroom,
    bt.planned as budget_planned,
    bu.used as budget_used,
    bt.configured as budget_configured
  from params p
  cross join balances b
  cross join mandatory m
  cross join budget_totals bt
  cross join budget_used bu
  cross join next_income ni
),
calc as (
  select *,
    case when budget_configured then greatest(budget_planned-budget_used,0)::numeric
         else greatest(cash_headroom,0)::numeric end as economic_headroom,
    case when liquid_balance > 0 then cash_headroom/liquid_balance else 0 end as cash_ratio,
    case when budget_configured and budget_planned > 0 then greatest(budget_planned-budget_used,0)/budget_planned else 1 end as budget_ratio
  from base
),
final_calc as (
  select *,
    greatest(least(cash_headroom,economic_headroom),0)::numeric as spendable_pool_calc,
    least(cash_ratio,budget_ratio) as constraint_ratio
  from calc
)
select
  f.as_of_date,
  f.income_date,
  f.income_amount,
  f.days_until_income,
  round(f.liquid_balance,2),
  round(f.protected_balance,2),
  round(f.mandatory_outflows,2),
  round(f.cash_headroom,2),
  round(f.budget_planned,2),
  round(f.budget_used,2),
  round(f.economic_headroom,2),
  round(f.spendable_pool_calc,2),
  case when f.days_until_income is null then null else floor(f.spendable_pool_calc/f.days_until_income*100)/100 end,
  round(greatest(-f.cash_headroom,0),2),
  case
    when not f.budget_configured then 'cash'
    when f.cash_headroom <= f.economic_headroom then 'cash'
    else 'budget'
  end,
  case
    when f.income_date is null then 'configurar_recebimento'
    when f.cash_headroom < 0 then 'segure_gastos'
    when f.spendable_pool_calc <= 0 then 'sem_folga'
    when f.constraint_ratio < 0.15 then 'apertado'
    when f.constraint_ratio < 0.35 then 'atencao'
    else 'tranquilo'
  end,
  f.budget_configured,
  (f.income_date is null)
from final_calc f;
$function$;
