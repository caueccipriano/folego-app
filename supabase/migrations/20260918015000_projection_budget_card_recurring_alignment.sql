-- Align ProjectionEngine with actual card cycles and effective remaining budgets.
-- Future known installments are already reflected in get_budget_overview.remaining_amount,
-- so they must not be counted again as generic budget spending.

create or replace function private.projection_card_due_date(
  p_purchase_date date,
  p_closing_day integer,
  p_due_day integer
)
returns date
language plpgsql
immutable
set search_path = ''
as $helper$
declare
  v_closing date;
  v_due_candidate date;
begin
  v_closing := private.card_date_in_month(p_purchase_date, p_closing_day);

  if p_purchase_date > v_closing then
    v_closing := private.card_date_in_month(
      (date_trunc('month', p_purchase_date) + interval '1 month')::date,
      p_closing_day
    );
  end if;

  v_due_candidate := private.card_date_in_month(v_closing, p_due_day);

  if v_due_candidate <= v_closing then
    return private.card_date_in_month(
      (date_trunc('month', v_closing) + interval '1 month')::date,
      p_due_day
    );
  end if;

  return v_due_candidate;
end;
$helper$;

CREATE OR REPLACE FUNCTION public.get_projection(p_space_id uuid, p_horizon_months integer DEFAULT 12, p_adjustments jsonb DEFAULT '[]'::jsonb, p_disabled_variable_income_keys text[] DEFAULT '{}'::text[])
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_timezone text;
  v_today date;
  v_start_month date;
  v_end_month date;
  v_end_date date;
  v_horizon integer;
  v_current_balance numeric := 0;
  v_result jsonb;
begin
  if auth.uid() is null or not private.is_space_member(p_space_id) then
    raise exception 'read_access_denied' using errcode = '42501';
  end if;

  v_horizon := case
    when p_horizon_months in (3, 6, 12, 24) then p_horizon_months
    else 12
  end;

  if p_adjustments is null or jsonb_typeof(p_adjustments) <> 'array' then
    raise exception 'invalid_projection_adjustments';
  end if;

  if jsonb_array_length(p_adjustments) > 40 then
    raise exception 'too_many_projection_adjustments';
  end if;

  select coalesce(fs.timezone, 'America/Sao_Paulo')
    into v_timezone
  from public.financial_spaces fs
  where fs.id = p_space_id;

  if v_timezone is null then
    raise exception 'financial_space_not_found';
  end if;

  v_today := (now() at time zone v_timezone)::date;
  v_start_month := date_trunc('month', v_today)::date;
  v_end_month := (v_start_month + make_interval(months => v_horizon - 1))::date;
  v_end_date := (v_end_month + interval '1 month - 1 day')::date;

  select coalesce(sum(fi.amount), 0)
    into v_current_balance
  from public.financial_impacts fi
  join public.accounts a
    on a.id = fi.account_id
   and a.space_id = fi.space_id
  where fi.space_id = p_space_id
    and fi.dimension = 'cash'
    and fi.effective_date <= v_today
    and a.active
    and a.type <> 'benefit'
    and a.available_for_spending;

  with recursive
  months as (
    select
      gs::date as month_start,
      (gs + interval '1 month - 1 day')::date as month_end,
      row_number() over(order by gs)::integer as rn
    from generate_series(
      v_start_month::timestamp,
      v_end_month::timestamp,
      interval '1 month'
    ) gs
  ),
  calendar as (
    select gs::date as d
    from generate_series(
      v_today::timestamp,
      v_end_date::timestamp,
      interval '1 day'
    ) gs
  ),
  recurring_occurrences as (
    select
      r.id,
      r.name,
      r.item_type,
      r.amount::numeric,
      r.category_id,
      ccat.name as category_name,
      r.account_id,
      r.card_id,
      r.certainty,
      r.recurrence_kind,
      a.type as account_type,
      cc.closing_day,
      cc.due_day,
      c.d,
      date_trunc('month', c.d)::date as month_start,
      case
        when r.card_id is not null and cc.id is not null then
          date_trunc(
            'month',
            private.projection_card_due_date(
              c.d,
              cc.closing_day,
              cc.due_day
            )
          )::date
        else date_trunc('month', c.d)::date
      end as projection_month_start,
      ('recurring:' || r.id::text)::text as variable_key
    from public.recurring_items r
    join calendar c
      on c.d >= greatest(r.starts_on, v_today)
     and (r.ends_on is null or c.d <= r.ends_on)
    left join public.recurring_occurrences ro
      on ro.recurring_item_id = r.id
     and ro.space_id = r.space_id
     and ro.due_date = c.d
    left join public.accounts a
      on a.id = r.account_id
     and a.space_id = r.space_id
    left join public.credit_cards cc
      on cc.id = r.card_id
     and cc.space_id = r.space_id
    left join public.categories ccat
      on ccat.id = r.category_id
     and ccat.space_id = r.space_id
    where r.space_id = p_space_id
      and r.active
      and r.certainty in ('confirmed', 'expected')
      and coalesce(ro.status, 'pending') = 'pending'
      and (
        (
          r.frequency = 'monthly'
          and (
            extract(day from c.d)::int = any(coalesce(r.monthly_days, '{}'::integer[]))
            or (
              r.monthly_last_day
              and c.d = (date_trunc('month', c.d) + interval '1 month - 1 day')::date
            )
            or (
              cardinality(coalesce(r.monthly_days, '{}'::integer[])) = 0
              and not r.monthly_last_day
              and r.day_of_month is not null
              and extract(day from c.d)::int = least(
                r.day_of_month,
                extract(day from date_trunc('month', c.d) + interval '1 month - 1 day')::int
              )
            )
          )
        )
        or (
          r.frequency = 'weekly'
          and extract(dow from c.d)::int = r.weekday
        )
        or (
          r.frequency = 'biweekly'
          and c.d >= r.starts_on
          and ((c.d - r.starts_on) % 14) = 0
        )
        or (
          r.frequency = 'yearly'
          and extract(month from c.d)::int = r.month_of_year
          and extract(day from c.d)::int = least(
            r.day_of_month,
            extract(day from date_trunc('month', c.d) + interval '1 month - 1 day')::int
          )
        )
      )
  ),
  recurring_monthly as (
    select
      m.month_start,
      coalesce(sum(ro.amount) filter (
        where ro.item_type = 'income'
          and ro.certainty = 'confirmed'
      ), 0)::numeric as guaranteed_income,
      coalesce(sum(ro.amount) filter (
        where ro.item_type = 'income'
          and ro.certainty <> 'confirmed'
          and not (ro.variable_key = any(coalesce(p_disabled_variable_income_keys, '{}'::text[])))
      ), 0)::numeric as variable_income,
      coalesce(sum(ro.amount) filter (
        where ro.item_type = 'expense'
          and ro.card_id is null
          and coalesce(ro.account_type, '') <> 'benefit'
      ), 0)::numeric as recurring_expenses,
      coalesce(sum(ro.amount) filter (
        where ro.item_type = 'expense'
          and ro.account_type = 'benefit'
      ), 0)::numeric as benefit_expenses
    from months m
    left join recurring_occurrences ro on ro.month_start = m.month_start
    group by m.month_start
  ),
  recurring_card_monthly as (
    select
      m.month_start,
      coalesce(sum(ro.amount), 0)::numeric as card_recurring
    from months m
    left join recurring_occurrences ro
      on ro.projection_month_start = m.month_start
     and ro.item_type = 'expense'
     and ro.card_id is not null
    group by m.month_start
  ),
  recurring_by_category as (
    select
      ro.projection_month_start as month_start,
      ro.category_id,
      coalesce(ro.category_name, 'Recorrências') as category_name,
      sum(ro.amount)::numeric as amount
    from recurring_occurrences ro
    where ro.item_type = 'expense'
    group by
      ro.projection_month_start,
      ro.category_id,
      coalesce(ro.category_name, 'Recorrências')
  ),
  budget_rows as (
    select
      m.month_start,
      bo.category_id,
      bo.category_name,
      greatest(bo.remaining_amount, 0::numeric)::numeric as planned_remaining
    from months m
    cross join lateral public.get_budget_overview(p_space_id, m.month_start) bo
    where bo.parent_id is not null
      and bo.planned_amount > 0
  ),
  direct_budget_rows as (
    select
      b.month_start,
      b.category_id,
      b.category_name,
      greatest(
        b.planned_remaining - coalesce(r.amount, 0::numeric),
        0::numeric
      )::numeric as amount
    from budget_rows b
    left join recurring_by_category r
      on r.month_start = b.month_start
     and r.category_id = b.category_id
  ),
  direct_budget_monthly as (
    select
      m.month_start,
      coalesce(sum(d.amount), 0)::numeric as direct_expenses
    from months m
    left join direct_budget_rows d on d.month_start = m.month_start
    group by m.month_start
  ),
  invoice_rows as (
    select
      ci.id as invoice_id,
      ci.card_id,
      cc.name as card_name,
      ci.due_date,
      date_trunc('month', ci.due_date)::date as month_start,
      greatest(
        ci.opening_balance
        + coalesce(sum(inst.amount) filter (
            where inst.status not in ('cancelled', 'refunded')
          ), 0::numeric)
        - coalesce((
            select sum(cp.amount)
            from public.card_payments cp
            where cp.invoice_id = ci.id
              and cp.space_id = ci.space_id
              and cp.status = 'confirmed'
          ), 0::numeric),
        0::numeric
      )::numeric as amount_due
    from public.card_invoices ci
    join public.credit_cards cc
      on cc.id = ci.card_id
     and cc.space_id = ci.space_id
    left join public.card_installments inst
      on inst.invoice_id = ci.id
     and inst.space_id = ci.space_id
    where ci.space_id = p_space_id
      and ci.status not in ('paid', 'cancelled')
      and ci.due_date >= v_today
      and ci.due_date <= v_end_date
    group by
      ci.id, ci.card_id, cc.name, ci.due_date, ci.opening_balance, ci.space_id
  ),
  card_invoice_monthly as (
    select
      m.month_start,
      coalesce(sum(ir.amount_due), 0)::numeric as invoice_amount
    from months m
    left join invoice_rows ir on ir.month_start = m.month_start
    group by m.month_start
  ),
  card_monthly as (
    select
      m.month_start,
      (
        coalesce(cim.invoice_amount, 0)
        + coalesce(rcm.card_recurring, 0)
      )::numeric as card_installments
    from months m
    left join card_invoice_monthly cim on cim.month_start = m.month_start
    left join recurring_card_monthly rcm on rcm.month_start = m.month_start
  ),
  card_category_rows as (
    select
      date_trunc('month', inv.due_date)::date as month_start,
      coalesce(cat.name, 'Cartões') as category_name,
      sum(inst.amount)::numeric as amount
    from public.card_installments inst
    join public.card_invoices inv
      on inv.id = inst.invoice_id
     and inv.space_id = inst.space_id
    join invoice_rows active_inv on active_inv.invoice_id = inv.id
    join public.card_purchases p
      on p.id = inst.purchase_id
     and p.space_id = inst.space_id
    left join public.categories cat
      on cat.id = p.category_id
     and cat.space_id = p.space_id
    where inst.space_id = p_space_id
      and inst.status not in ('cancelled', 'refunded')
    group by date_trunc('month', inv.due_date)::date, coalesce(cat.name, 'Cartões')
  ),
  debt_rows as (
    select
      date_trunc('month', di.due_date)::date as month_start,
      d.name,
      greatest(di.planned_amount - di.paid_amount, 0::numeric)::numeric as amount
    from public.debt_installments di
    join public.debts d
      on d.id = di.debt_id
     and d.space_id = di.space_id
    where di.space_id = p_space_id
      and d.status = 'active'
      and d.archived_at is null
      and di.status in ('pending', 'partially_paid', 'overdue')
      and di.due_date >= v_today
      and di.due_date <= v_end_date
  ),
  debt_monthly as (
    select
      m.month_start,
      coalesce(sum(d.amount), 0)::numeric as debts
    from months m
    left join debt_rows d on d.month_start = m.month_start
    group by m.month_start
  ),
  planned_occurrences as (
    select
      pi.id,
      pi.name,
      pi.component,
      pi.amount_delta,
      pi.category_id,
      coalesce(cat.name, case
        when pi.component = 'reserve' then 'Reservas / metas'
        when pi.component = 'investment' then 'Investimentos'
        when pi.component = 'debt' then 'Dívidas / financiamentos'
        else 'Planejamento'
      end) as category_name,
      pi.variable_income,
      c.d,
      date_trunc('month', c.d)::date as month_start,
      ('planned:' || pi.id::text)::text as variable_key
    from public.projection_planned_items pi
    join calendar c
      on c.d >= greatest(pi.starts_on, v_today)
     and (pi.ends_on is null or c.d <= pi.ends_on)
    left join public.categories cat
      on cat.id = pi.category_id
     and cat.space_id = pi.space_id
    where pi.space_id = p_space_id
      and pi.active
      and (
        (pi.frequency = 'once' and c.d = pi.starts_on)
        or (
          pi.frequency = 'monthly'
          and extract(day from c.d)::int = least(
            extract(day from pi.starts_on)::int,
            extract(day from date_trunc('month', c.d) + interval '1 month - 1 day')::int
          )
        )
        or (
          pi.frequency = 'yearly'
          and extract(month from c.d)::int = extract(month from pi.starts_on)::int
          and extract(day from c.d)::int = least(
            extract(day from pi.starts_on)::int,
            extract(day from date_trunc('month', c.d) + interval '1 month - 1 day')::int
          )
        )
      )
  ),
  adjustment_rows as (
    select
      coalesce(nullif(btrim(j ->> 'id'), ''), gen_random_uuid()::text) as id,
      coalesce(nullif(btrim(j ->> 'name'), ''), 'Simulação') as name,
      nullif(btrim(j ->> 'component'), '') as component,
      coalesce(nullif(j ->> 'amount_delta', '')::numeric, 0::numeric) as amount_delta,
      coalesce(nullif(btrim(j ->> 'frequency'), ''), 'once') as frequency,
      coalesce(nullif(j ->> 'starts_on', '')::date, v_today) as starts_on,
      nullif(j ->> 'ends_on', '')::date as ends_on,
      nullif(btrim(j ->> 'category_name'), '') as category_name,
      coalesce((j ->> 'variable_income')::boolean, false) as variable_income
    from jsonb_array_elements(coalesce(p_adjustments, '[]'::jsonb)) j
    where nullif(btrim(j ->> 'component'), '') in (
      'income','direct_expense','recurring_expense','card_installment',
      'debt','reserve','investment','other_inflow','other_outflow'
    )
      and coalesce(nullif(j ->> 'amount_delta', '')::numeric, 0::numeric) <> 0
  ),
  adjustment_occurrences as (
    select
      a.id,
      a.name,
      a.component,
      a.amount_delta,
      coalesce(a.category_name, case
        when a.component = 'reserve' then 'Reservas / metas'
        when a.component = 'investment' then 'Investimentos'
        when a.component = 'debt' then 'Dívidas / financiamentos'
        else 'Simulação'
      end) as category_name,
      a.variable_income,
      c.d,
      date_trunc('month', c.d)::date as month_start,
      ('adjustment:' || a.id)::text as variable_key
    from adjustment_rows a
    join calendar c
      on c.d >= greatest(a.starts_on, v_today)
     and (a.ends_on is null or c.d <= a.ends_on)
    where
      (a.frequency = 'once' and c.d = a.starts_on)
      or (
        a.frequency = 'monthly'
        and extract(day from c.d)::int = least(
          extract(day from a.starts_on)::int,
          extract(day from date_trunc('month', c.d) + interval '1 month - 1 day')::int
        )
      )
      or (
        a.frequency = 'yearly'
        and extract(month from c.d)::int = extract(month from a.starts_on)::int
        and extract(day from c.d)::int = least(
          extract(day from a.starts_on)::int,
          extract(day from date_trunc('month', c.d) + interval '1 month - 1 day')::int
        )
      )
  ),
  planned_monthly as (
    select
      m.month_start,
      coalesce(sum(po.amount_delta) filter (
        where po.component = 'income'
          and not po.variable_income
      ), 0)::numeric as guaranteed_income,
      coalesce(sum(po.amount_delta) filter (
        where po.component = 'income'
          and po.variable_income
          and not (po.variable_key = any(coalesce(p_disabled_variable_income_keys, '{}'::text[])))
      ), 0)::numeric as variable_income,
      coalesce(sum(po.amount_delta) filter (where po.component = 'direct_expense'), 0)::numeric as direct_expenses,
      coalesce(sum(po.amount_delta) filter (where po.component = 'recurring_expense'), 0)::numeric as recurring_expenses,
      coalesce(sum(po.amount_delta) filter (where po.component = 'card_installment'), 0)::numeric as card_installments,
      coalesce(sum(po.amount_delta) filter (where po.component = 'debt'), 0)::numeric as debts,
      coalesce(sum(po.amount_delta) filter (where po.component = 'reserve'), 0)::numeric as reserve_transfers,
      coalesce(sum(po.amount_delta) filter (where po.component = 'investment'), 0)::numeric as investments,
      coalesce(sum(po.amount_delta) filter (where po.component = 'other_inflow'), 0)::numeric as other_inflows,
      coalesce(sum(po.amount_delta) filter (where po.component = 'other_outflow'), 0)::numeric as other_outflows
    from months m
    left join planned_occurrences po on po.month_start = m.month_start
    group by m.month_start
  ),
  adjustment_monthly as (
    select
      m.month_start,
      coalesce(sum(ao.amount_delta) filter (
        where ao.component = 'income'
          and not ao.variable_income
      ), 0)::numeric as guaranteed_income,
      coalesce(sum(ao.amount_delta) filter (
        where ao.component = 'income'
          and ao.variable_income
          and not (ao.variable_key = any(coalesce(p_disabled_variable_income_keys, '{}'::text[])))
      ), 0)::numeric as variable_income,
      coalesce(sum(ao.amount_delta) filter (where ao.component = 'direct_expense'), 0)::numeric as direct_expenses,
      coalesce(sum(ao.amount_delta) filter (where ao.component = 'recurring_expense'), 0)::numeric as recurring_expenses,
      coalesce(sum(ao.amount_delta) filter (where ao.component = 'card_installment'), 0)::numeric as card_installments,
      coalesce(sum(ao.amount_delta) filter (where ao.component = 'debt'), 0)::numeric as debts,
      coalesce(sum(ao.amount_delta) filter (where ao.component = 'reserve'), 0)::numeric as reserve_transfers,
      coalesce(sum(ao.amount_delta) filter (where ao.component = 'investment'), 0)::numeric as investments,
      coalesce(sum(ao.amount_delta) filter (where ao.component = 'other_inflow'), 0)::numeric as other_inflows,
      coalesce(sum(ao.amount_delta) filter (where ao.component = 'other_outflow'), 0)::numeric as other_outflows
    from months m
    left join adjustment_occurrences ao on ao.month_start = m.month_start
    group by m.month_start
  ),
  components as (
    select
      m.rn,
      m.month_start,
      m.month_end,
      (coalesce(r.guaranteed_income, 0)
        + coalesce(p.guaranteed_income, 0)
        + coalesce(a.guaranteed_income, 0))::numeric as guaranteed_income,
      (coalesce(r.variable_income, 0)
        + coalesce(p.variable_income, 0)
        + coalesce(a.variable_income, 0))::numeric as variable_income,
      greatest(
        coalesce(b.direct_expenses, 0)
        + coalesce(p.direct_expenses, 0)
        + coalesce(a.direct_expenses, 0),
        0::numeric
      )::numeric as direct_expenses,
      greatest(
        coalesce(r.recurring_expenses, 0)
        + coalesce(p.recurring_expenses, 0)
        + coalesce(a.recurring_expenses, 0),
        0::numeric
      )::numeric as recurring_expenses,
      greatest(
        coalesce(c.card_installments, 0)
        + coalesce(p.card_installments, 0)
        + coalesce(a.card_installments, 0),
        0::numeric
      )::numeric as card_installments,
      greatest(
        coalesce(d.debts, 0)
        + coalesce(p.debts, 0)
        + coalesce(a.debts, 0),
        0::numeric
      )::numeric as debts,
      greatest(
        coalesce(p.reserve_transfers, 0)
        + coalesce(a.reserve_transfers, 0),
        0::numeric
      )::numeric as reserve_transfers,
      greatest(
        coalesce(p.investments, 0)
        + coalesce(a.investments, 0),
        0::numeric
      )::numeric as investments,
      (coalesce(p.other_inflows, 0) + coalesce(a.other_inflows, 0))::numeric as other_inflows,
      greatest(
        coalesce(p.other_outflows, 0)
        + coalesce(a.other_outflows, 0),
        0::numeric
      )::numeric as other_outflows,
      coalesce(r.benefit_expenses, 0)::numeric as benefit_expenses
    from months m
    left join recurring_monthly r on r.month_start = m.month_start
    left join direct_budget_monthly b on b.month_start = m.month_start
    left join card_monthly c on c.month_start = m.month_start
    left join debt_monthly d on d.month_start = m.month_start
    left join planned_monthly p on p.month_start = m.month_start
    left join adjustment_monthly a on a.month_start = m.month_start
  ),
  projection as (
    select
      c.rn,
      c.month_start,
      c.month_end,
      v_current_balance::numeric as opening_balance,
      c.guaranteed_income,
      c.variable_income,
      c.direct_expenses,
      c.recurring_expenses,
      c.card_installments,
      c.debts,
      c.reserve_transfers,
      c.investments,
      c.other_inflows,
      c.other_outflows,
      c.benefit_expenses,
      (
        v_current_balance
        + c.guaranteed_income
        + c.variable_income
        + c.other_inflows
        - c.direct_expenses
        - c.recurring_expenses
        - c.card_installments
        - c.debts
        - c.reserve_transfers
        - c.investments
        - c.other_outflows
      )::numeric as closing_balance
    from components c
    where c.rn = 1

    union all

    select
      c.rn,
      c.month_start,
      c.month_end,
      p.closing_balance as opening_balance,
      c.guaranteed_income,
      c.variable_income,
      c.direct_expenses,
      c.recurring_expenses,
      c.card_installments,
      c.debts,
      c.reserve_transfers,
      c.investments,
      c.other_inflows,
      c.other_outflows,
      c.benefit_expenses,
      (
        p.closing_balance
        + c.guaranteed_income
        + c.variable_income
        + c.other_inflows
        - c.direct_expenses
        - c.recurring_expenses
        - c.card_installments
        - c.debts
        - c.reserve_transfers
        - c.investments
        - c.other_outflows
      )::numeric as closing_balance
    from projection p
    join components c on c.rn = p.rn + 1
  ),
  category_rows as (
    select d.month_start, d.category_name, d.amount
    from direct_budget_rows d
    where d.amount <> 0
    union all
    select r.month_start, r.category_name, r.amount
    from recurring_by_category r
    where r.amount <> 0
    union all
    select c.month_start, c.category_name, c.amount
    from card_category_rows c
    where c.amount <> 0
    union all
    select d.month_start, 'Dívidas / financiamentos'::text, sum(d.amount)::numeric
    from debt_rows d
    group by d.month_start
    union all
    select po.month_start, po.category_name, po.amount_delta::numeric
    from planned_occurrences po
    where po.component in (
      'direct_expense','recurring_expense','card_installment',
      'debt','reserve','investment','other_outflow'
    )
    union all
    select ao.month_start, ao.category_name, ao.amount_delta::numeric
    from adjustment_occurrences ao
    where ao.component in (
      'direct_expense','recurring_expense','card_installment',
      'debt','reserve','investment','other_outflow'
    )
  ),
  categories_by_month as (
    select
      m.month_start,
      coalesce(
        (
          select jsonb_agg(
            jsonb_build_object(
              'name', x.category_name,
              'amount', round(x.amount, 2)
            )
            order by x.amount desc, x.category_name
          )
          from (
            select cr.category_name, sum(cr.amount)::numeric as amount
            from category_rows cr
            where cr.month_start = m.month_start
            group by cr.category_name
            having sum(cr.amount) <> 0
          ) x
        ),
        '[]'::jsonb
      ) as categories
    from months m
  ),
  projection_rows as (
    select
      p.*,
      cbm.categories,
      (
        p.guaranteed_income
        + p.variable_income
        + p.other_inflows
        - p.direct_expenses
        - p.recurring_expenses
        - p.card_installments
        - p.debts
        - p.reserve_transfers
        - p.investments
        - p.other_outflows
      )::numeric as net_change
    from projection p
    left join categories_by_month cbm on cbm.month_start = p.month_start
  ),
  variable_income_rows as (
    select distinct
      ro.variable_key as key,
      ro.name,
      ro.amount,
      ro.certainty,
      not (ro.variable_key = any(coalesce(p_disabled_variable_income_keys, '{}'::text[]))) as enabled
    from recurring_occurrences ro
    where ro.item_type = 'income'
      and ro.certainty <> 'confirmed'
    union all
    select distinct
      po.variable_key as key,
      po.name,
      abs(po.amount_delta)::numeric as amount,
      'planned'::text as certainty,
      not (po.variable_key = any(coalesce(p_disabled_variable_income_keys, '{}'::text[]))) as enabled
    from planned_occurrences po
    where po.component = 'income'
      and po.variable_income
  ),
  summary as (
    select
      (select closing_balance from projection_rows order by rn desc limit 1) as ending_balance,
      min(closing_balance) as minimum_balance,
      max(closing_balance) as maximum_balance,
      sum(reserve_transfers + investments) as projected_savings,
      (
        select pr.month_start
        from projection_rows pr
        where pr.closing_balance < 0
        order by pr.rn
        limit 1
      ) as critical_month
    from projection_rows
  ),
  has_inputs as (
    select (
      exists(
        select 1 from public.recurring_items r
        where r.space_id = p_space_id and r.active
      )
      or exists(
        select 1
        from public.card_invoices ci
        where ci.space_id = p_space_id
          and ci.status not in ('paid','cancelled')
          and ci.due_date >= v_today
      )
      or exists(
        select 1
        from public.debt_installments di
        join public.debts d on d.id = di.debt_id and d.space_id = di.space_id
        where di.space_id = p_space_id
          and d.status = 'active'
          and di.status in ('pending','partially_paid','overdue')
          and di.due_date >= v_today
      )
      or exists(
        select 1
        from public.projection_planned_items pi
        where pi.space_id = p_space_id and pi.active
      )
    ) as value
  )
  select jsonb_build_object(
    'scenario', 'current',
    'horizon_months', v_horizon,
    'as_of_date', v_today,
    'opening_balance', round(v_current_balance, 2),
    'has_projection_inputs', (select value from has_inputs),
    'summary', jsonb_build_object(
      'ending_balance', round(coalesce(s.ending_balance, v_current_balance), 2),
      'minimum_balance', round(coalesce(s.minimum_balance, v_current_balance), 2),
      'maximum_balance', round(coalesce(s.maximum_balance, v_current_balance), 2),
      'projected_savings', round(coalesce(s.projected_savings, 0), 2),
      'critical_month', s.critical_month
    ),
    'variable_incomes', coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'key', vir.key,
            'name', vir.name,
            'amount', round(vir.amount, 2),
            'enabled', vir.enabled
          )
          order by vir.name, vir.key
        )
        from variable_income_rows vir
      ),
      '[]'::jsonb
    ),
    'months', coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'month', pr.month_start,
            'opening_balance', round(pr.opening_balance, 2),
            'guaranteed_income', round(pr.guaranteed_income, 2),
            'variable_income', round(pr.variable_income, 2),
            'income', round(pr.guaranteed_income + pr.variable_income, 2),
            'direct_expenses', round(pr.direct_expenses, 2),
            'recurring_expenses', round(pr.recurring_expenses, 2),
            'card_installments', round(pr.card_installments, 2),
            'debts', round(pr.debts, 2),
            'reserve_transfers', round(pr.reserve_transfers, 2),
            'investments', round(pr.investments, 2),
            'other_inflows', round(pr.other_inflows, 2),
            'other_outflows', round(pr.other_outflows, 2),
            'planned_movements', round(pr.other_outflows - pr.other_inflows, 2),
            'benefit_expenses', round(pr.benefit_expenses, 2),
            'net_change', round(pr.net_change, 2),
            'closing_balance', round(pr.closing_balance, 2),
            'realized_to_date', case
              when pr.rn = 1 then round(v_current_balance, 2)
              else null
            end,
            'still_expected', case
              when pr.rn = 1 then round(pr.net_change, 2)
              else null
            end,
            'closing_projected', round(pr.closing_balance, 2),
            'categories', coalesce(pr.categories, '[]'::jsonb)
          )
          order by pr.rn
        )
        from projection_rows pr
      ),
      '[]'::jsonb
    )
  )
  into v_result
  from summary s;

  return v_result;
end;
$function$
;

revoke all on function private.projection_card_due_date(date,integer,integer)
  from public, anon, authenticated;
