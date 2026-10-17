-- Fôlego — Flexible Budget 1.0
-- Separates the global monthly flexible-spending ceiling from per-category
-- limits while preserving the previous value for already configured months.

alter table public.budgets
  add column if not exists flexible_limit numeric;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.budgets'::regclass
      and conname = 'budgets_flexible_limit_nonnegative'
  ) then
    alter table public.budgets
      add constraint budgets_flexible_limit_nonnegative
      check (flexible_limit is null or flexible_limit >= 0);
  end if;
end $$;

update public.budgets b
set flexible_limit = x.flexible_total,
    updated_at = now()
from (
  select bi.budget_id, coalesce(sum(bi.planned_amount), 0)::numeric as flexible_total
  from public.budget_items bi
  join public.categories c
    on c.id = bi.category_id
   and c.space_id = bi.space_id
  where coalesce(c.essential, false) = false
  group by bi.budget_id
) x
where x.budget_id = b.id
  and b.flexible_limit is null;

create or replace function public.get_flexible_budget_overview(
  p_space_id uuid,
  p_period_month date
)
returns table(
  period_month date,
  configured boolean,
  explicit_limit boolean,
  limit_amount numeric,
  used_amount numeric,
  remaining_amount numeric,
  exceeded_amount numeric,
  category_limits_total numeric
)
language sql
stable
set search_path to ''
as $function$
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
  where g.parent_id is not null
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
   and not exists (
     select 1
     from public.financial_events fe
     where fe.id = fi.event_id
       and fe.space_id = fi.space_id
       and fe.event_type = 'benefit_expense'
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
$function$;

grant execute on function public.get_flexible_budget_overview(uuid,date) to authenticated;
revoke execute on function public.get_flexible_budget_overview(uuid,date) from anon;

create or replace function public.set_flexible_budget_limit(
  p_space_id uuid,
  p_period_month date,
  p_limit numeric
)
returns boolean
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_month date := date_trunc('month', p_period_month)::date;
begin
  if auth.uid() is null or not private.can_write_space(p_space_id) then
    raise exception 'write_access_denied' using errcode = '42501';
  end if;

  if p_limit is null or p_limit < 0 then
    raise exception 'invalid_flexible_limit' using errcode = '22023';
  end if;

  insert into public.budgets(space_id, period_month, status, flexible_limit)
  values (p_space_id, v_month, 'active', p_limit)
  on conflict (space_id, period_month)
  do update set flexible_limit = excluded.flexible_limit,
                updated_at = now();

  return true;
end;
$function$;

grant execute on function public.set_flexible_budget_limit(uuid,date,numeric) to authenticated;
revoke execute on function public.set_flexible_budget_limit(uuid,date,numeric) from anon;

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
      (
        r.frequency='monthly'
        and (
          extract(day from c.d)::int = any(coalesce(r.monthly_days,'{}'::integer[]))
          or (
            r.monthly_last_day
            and c.d::date = (date_trunc('month',c.d) + interval '1 month - 1 day')::date
          )
          or (
            cardinality(coalesce(r.monthly_days,'{}'::integer[])) = 0
            and not r.monthly_last_day
            and r.day_of_month is not null
            and extract(day from c.d)::int = least(
              r.day_of_month,
              extract(day from date_trunc('month',c.d)+interval '1 month - 1 day')::int
            )
          )
        )
      )
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
      (
        r.frequency='monthly'
        and (
          extract(day from c.d)::int = any(coalesce(r.monthly_days,'{}'::integer[]))
          or (
            r.monthly_last_day
            and c.d::date = (date_trunc('month',c.d) + interval '1 month - 1 day')::date
          )
          or (
            cardinality(coalesce(r.monthly_days,'{}'::integer[])) = 0
            and not r.monthly_last_day
            and r.day_of_month is not null
            and extract(day from c.d)::int = least(
              r.day_of_month,
              extract(day from date_trunc('month',c.d)+interval '1 month - 1 day')::int
            )
          )
        )
      )
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
  select f.limit_amount as planned,
         f.configured
  from params p
  join month_window mw on true
  cross join lateral public.get_flexible_budget_overview(p.space_id, mw.month_start) f
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
   and not exists (
     select 1
     from public.financial_events fe
     where fe.id = fi.event_id
       and fe.space_id = fi.space_id
       and fe.event_type = 'benefit_expense'
   )
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

create or replace function public.get_daily_summary_push_candidates(
  p_now timestamptz default now(),
  p_limit integer default 100
)
returns table(
  user_id uuid,
  space_id uuid,
  stable_key text,
  kind text,
  title text,
  body text,
  route text
)
language plpgsql
security definer
set search_path to ''
as $function$
declare
  pref record;
  snap record;
  wallet jsonb;
  today_local date;
  scheduled_at timestamptz;
  candidate_key text;
  candidate_body text;
  details text;
  category_attention_count integer;
  card_attention_count integer;
  tomorrow_count integer;
  overdue_count integer;
  emitted integer := 0;
begin
  p_limit := least(greatest(coalesce(p_limit, 100), 1), 500);

  for pref in
    select np.*, fs.timezone
    from public.notification_preferences np
    join public.financial_spaces fs on fs.id = np.space_id
    where np.financial_reminders_enabled
      and np.daily_summary_enabled
      and exists (
        select 1 from public.space_members sm
        where sm.space_id = np.space_id and sm.user_id = np.user_id
      )
      and exists (
        select 1 from public.web_push_subscriptions ws
        where ws.user_id = np.user_id and ws.disabled_at is null
      )
    order by np.updated_at, np.space_id
  loop
    perform set_config('request.jwt.claim.sub', pref.user_id::text, true);
    today_local := (p_now at time zone pref.timezone)::date;
    scheduled_at := (today_local::timestamp + pref.daily_summary_time) at time zone pref.timezone;

    if scheduled_at > p_now then continue; end if;
    if private.is_web_push_quiet(
      p_now, pref.timezone, pref.quiet_hours_enabled,
      pref.quiet_hours_start, pref.quiet_hours_end
    ) then continue; end if;

    candidate_key := 'daily_summary:' || pref.space_id::text || ':' || today_local::text;
    if exists (
      select 1 from public.web_push_delivery_log dl
      where dl.user_id = pref.user_id and dl.stable_key = candidate_key
    ) then continue; end if;

    select * into snap
    from public.get_folego_snapshot(pref.space_id, today_local)
    limit 1;

    select count(*)::integer into category_attention_count
    from public.get_budget_overview(pref.space_id, date_trunc('month', today_local)::date) b
    where b.planned_amount > 0
      and b.budget_source <> 'aggregate'
      and b.usage_ratio >= b.warning_threshold;

    wallet := public.get_wallet_overview(pref.space_id);
    select count(*)::integer into card_attention_count
    from jsonb_array_elements(coalesce(wallet->'cards', '[]'::jsonb)) as c(value)
    where coalesce(nullif(c.value->>'invoice_balance', '')::numeric, 0) > 0
      and coalesce(
        nullif(c.value->>'personal_limit', '')::numeric,
        nullif(c.value->>'issuer_limit', '')::numeric,
        0
      ) > 0
      and (
        coalesce(nullif(c.value->>'invoice_balance', '')::numeric, 0)
        /
        coalesce(
          nullif(c.value->>'personal_limit', '')::numeric,
          nullif(c.value->>'issuer_limit', '')::numeric,
          1
        )
      ) >= 0.70;

    select count(*)::integer into tomorrow_count
    from public.get_upcoming_events(pref.space_id, today_local + 1, today_local + 1, 200) u
    where u.due_date = today_local + 1;

    select count(*)::integer into overdue_count
    from public.get_upcoming_events(pref.space_id, today_local - 30, today_local, 200) u
    where u.overdue;

    if coalesce(snap.budget_configured, false)
       and coalesce(snap.monthly_budget_used, 0) > coalesce(snap.monthly_budget_planned, 0) then
      candidate_body := 'Você tem '
        || private.format_brl(coalesce(snap.liquid_balance, 0))
        || ' disponíveis • orçamento flexível excedido em '
        || private.format_brl(coalesce(snap.monthly_budget_used, 0) - coalesce(snap.monthly_budget_planned, 0));
    else
      candidate_body := private.format_brl(coalesce(snap.spendable_pool, 0))
        || ' livres • '
        || private.format_brl(coalesce(snap.daily_folego, 0))
        || '/dia';
    end if;

    details := concat_ws(
      ' • ',
      case when category_attention_count > 0 then
        category_attention_count::text || ' ' ||
        case when category_attention_count = 1 then 'categoria em atenção' else 'categorias em atenção' end
      end,
      case when card_attention_count > 0 then
        card_attention_count::text || ' ' ||
        case when card_attention_count = 1 then 'cartão em atenção' else 'cartões em atenção' end
      end,
      case when tomorrow_count > 0 then
        tomorrow_count::text || ' ' ||
        case when tomorrow_count = 1 then 'movimento amanhã' else 'movimentos amanhã' end
      end,
      case when overdue_count > 0 then
        overdue_count::text || ' ' ||
        case when overdue_count = 1 then 'item atrasado' else 'itens atrasados' end
      end
    );

    if coalesce(details, '') <> '' then
      candidate_body := candidate_body || E'\n' || details;
    end if;

    user_id := pref.user_id;
    space_id := pref.space_id;
    stable_key := candidate_key;
    kind := 'dailySummary';
    title := '☀️ Seu Fôlego de hoje';
    body := candidate_body;
    route := case
      when coalesce(snap.budget_configured, false)
       and coalesce(snap.monthly_budget_used, 0) > coalesce(snap.monthly_budget_planned, 0)
      then '/plan'
      else '/'
    end;
    return next;
    emitted := emitted + 1;
    if emitted >= p_limit then exit; end if;
  end loop;

  perform set_config('request.jwt.claim.sub', '', true);
end;
$function$;
