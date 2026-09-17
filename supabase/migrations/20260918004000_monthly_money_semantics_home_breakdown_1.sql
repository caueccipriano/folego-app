-- Fôlego — Monthly Money Semantics + Home Spending Breakdown 1.0
-- Central read model for monthly money semantics.
-- It does not mutate financial events, impacts, balances, categories, cards or sync data.

create or replace function public.get_monthly_money_summary(
  p_space_id uuid,
  p_period_month date
)
returns table(
  period_month date,
  income_amount numeric,
  spending_account numeric,
  spending_cards numeric,
  spending_benefits numeric,
  refunds_amount numeric,
  spending_net numeric,
  income_minus_spending numeric,
  competence_cards_total numeric,
  competence_direct numeric,
  competence_benefits numeric,
  competence_refunds numeric,
  competence_net numeric,
  competence_cards jsonb,
  cash_inflow numeric,
  cash_outflow numeric,
  cash_net numeric,
  movement_card_payments numeric,
  movement_transfers numeric,
  movement_reserve_investment numeric,
  movement_reconciliation numeric
)
language plpgsql
stable
security definer
set search_path to ''
as $function$
declare
  v_month date := date_trunc('month', p_period_month)::date;
begin
  if auth.uid() is null or not private.is_space_member(p_space_id) then
    raise exception 'access_denied' using errcode = '42501';
  end if;

  return query
  with
  params as (
    select
      v_month as month_start,
      (v_month + interval '1 month')::date as next_month,
      fs.timezone
    from public.financial_spaces fs
    where fs.id = p_space_id
  ),
  valid_events as (
    select e.*
    from public.financial_events e
    where e.space_id = p_space_id
      and e.status not in ('ignored', 'cancelled', 'error')
  ),
  account_spending as (
    select coalesce(sum(-fi.amount), 0)::numeric as amount
    from valid_events e
    cross join params p
    join public.financial_impacts fi
      on fi.event_id = e.id
     and fi.space_id = e.space_id
     and fi.dimension = 'economic'
     and fi.amount < 0
    where e.event_type in ('expense', 'debt_payment')
      and (e.occurred_at at time zone p.timezone)::date >= p.month_start
      and (e.occurred_at at time zone p.timezone)::date < p.next_month
  ),
  card_spending as (
    select coalesce(sum(e.amount), 0)::numeric as amount
    from valid_events e
    cross join params p
    where e.event_type = 'card_purchase'
      and (e.occurred_at at time zone p.timezone)::date >= p.month_start
      and (e.occurred_at at time zone p.timezone)::date < p.next_month
  ),
  benefit_spending as (
    select coalesce(sum(-fi.amount), 0)::numeric as amount
    from valid_events e
    cross join params p
    join public.financial_impacts fi
      on fi.event_id = e.id
     and fi.space_id = e.space_id
     and fi.dimension = 'economic'
     and fi.amount < 0
    where e.event_type = 'benefit_expense'
      and (e.occurred_at at time zone p.timezone)::date >= p.month_start
      and (e.occurred_at at time zone p.timezone)::date < p.next_month
  ),
  refunds_made as (
    select coalesce(sum(fi.amount), 0)::numeric as amount
    from valid_events e
    cross join params p
    join public.financial_impacts fi
      on fi.event_id = e.id
     and fi.space_id = e.space_id
     and fi.dimension = 'economic'
     and fi.amount > 0
    where e.event_type in ('refund', 'reimbursement')
      and (e.occurred_at at time zone p.timezone)::date >= p.month_start
      and (e.occurred_at at time zone p.timezone)::date < p.next_month
  ),
  monthly_income as (
    select coalesce(sum(fi.amount), 0)::numeric as amount
    from valid_events e
    cross join params p
    join public.financial_impacts fi
      on fi.event_id = e.id
     and fi.space_id = e.space_id
     and fi.dimension = 'economic'
     and fi.amount > 0
     and fi.effective_date >= p.month_start
     and fi.effective_date < p.next_month
    where e.event_type = 'income'
  ),
  competence_card_rows as (
    select
      cc.id as card_id,
      coalesce(cc.name, 'Cartão histórico') as card_name,
      coalesce(sum(-fi.amount), 0)::numeric as amount
    from valid_events e
    cross join params p
    join public.financial_impacts fi
      on fi.event_id = e.id
     and fi.space_id = e.space_id
     and fi.dimension = 'economic'
     and fi.amount < 0
     and fi.effective_date >= p.month_start
     and fi.effective_date < p.next_month
    left join public.card_purchases cp
      on cp.event_id = e.id
     and cp.space_id = e.space_id
    left join public.credit_cards cc
      on cc.id = cp.card_id
     and cc.space_id = cp.space_id
    where e.event_type = 'card_purchase'
    group by cc.id, cc.name
  ),
  competence_cards_agg as (
    select
      coalesce(sum(r.amount), 0)::numeric as total,
      coalesce(
        jsonb_agg(
          jsonb_build_object(
            'card_id', r.card_id,
            'name', r.card_name,
            'amount', round(r.amount, 2)
          )
          order by r.amount desc, r.card_name
        ),
        '[]'::jsonb
      ) as cards
    from competence_card_rows r
  ),
  competence_direct as (
    select coalesce(sum(-fi.amount), 0)::numeric as amount
    from valid_events e
    cross join params p
    join public.financial_impacts fi
      on fi.event_id = e.id
     and fi.space_id = e.space_id
     and fi.dimension = 'economic'
     and fi.amount < 0
     and fi.effective_date >= p.month_start
     and fi.effective_date < p.next_month
    where e.event_type in ('expense', 'debt_payment')
  ),
  competence_benefits as (
    select coalesce(sum(-fi.amount), 0)::numeric as amount
    from valid_events e
    cross join params p
    join public.financial_impacts fi
      on fi.event_id = e.id
     and fi.space_id = e.space_id
     and fi.dimension = 'economic'
     and fi.amount < 0
     and fi.effective_date >= p.month_start
     and fi.effective_date < p.next_month
    where e.event_type = 'benefit_expense'
  ),
  competence_refunds as (
    select coalesce(sum(fi.amount), 0)::numeric as amount
    from valid_events e
    cross join params p
    join public.financial_impacts fi
      on fi.event_id = e.id
     and fi.space_id = e.space_id
     and fi.dimension = 'economic'
     and fi.amount > 0
     and fi.effective_date >= p.month_start
     and fi.effective_date < p.next_month
    where e.event_type in ('refund', 'reimbursement')
  ),
  cash_totals as (
    select
      coalesce(sum(fi.amount) filter (where fi.amount > 0), 0)::numeric as inflow,
      coalesce(sum(-fi.amount) filter (where fi.amount < 0), 0)::numeric as outflow
    from valid_events e
    cross join params p
    join public.financial_impacts fi
      on fi.event_id = e.id
     and fi.space_id = e.space_id
     and fi.dimension = 'cash'
     and fi.effective_date >= p.month_start
     and fi.effective_date < p.next_month
  ),
  cash_event_rollup as (
    select
      e.id,
      e.event_type,
      greatest(
        coalesce(max(fi.amount) filter (where fi.amount > 0), 0),
        coalesce(max(-fi.amount) filter (where fi.amount < 0), 0)
      )::numeric as moved_amount,
      bool_or(coalesce(a.type in ('reserve', 'investment'), false)) as touches_reserve_or_investment
    from valid_events e
    cross join params p
    join public.financial_impacts fi
      on fi.event_id = e.id
     and fi.space_id = e.space_id
     and fi.dimension = 'cash'
     and fi.effective_date >= p.month_start
     and fi.effective_date < p.next_month
    left join public.accounts a
      on a.id = fi.account_id
     and a.space_id = fi.space_id
    group by e.id, e.event_type
  ),
  nonspending_movements as (
    select
      coalesce(sum(moved_amount) filter (
        where event_type = 'card_payment'
      ), 0)::numeric as card_payments,
      coalesce(sum(moved_amount) filter (
        where event_type = 'transfer'
          and not touches_reserve_or_investment
      ), 0)::numeric as transfers,
      coalesce(sum(moved_amount) filter (
        where event_type = 'reserve_transfer'
           or (event_type = 'transfer' and touches_reserve_or_investment)
      ), 0)::numeric as reserve_investment,
      coalesce(sum(moved_amount) filter (
        where event_type in ('adjustment', 'opening_balance')
      ), 0)::numeric as reconciliation
    from cash_event_rollup
  )
  select
    v_month,
    round(inc.amount, 2),
    round(acc.amount, 2),
    round(cards.amount, 2),
    round(benefits.amount, 2),
    round(refunds.amount, 2),
    round(acc.amount + cards.amount + benefits.amount - refunds.amount, 2),
    round(inc.amount - (acc.amount + cards.amount + benefits.amount - refunds.amount), 2),
    round(card_comp.total, 2),
    round(comp_direct.amount, 2),
    round(comp_benefits.amount, 2),
    round(comp_refunds.amount, 2),
    round(card_comp.total + comp_direct.amount + comp_benefits.amount - comp_refunds.amount, 2),
    card_comp.cards,
    round(cash.inflow, 2),
    round(cash.outflow, 2),
    round(cash.inflow - cash.outflow, 2),
    round(mov.card_payments, 2),
    round(mov.transfers, 2),
    round(mov.reserve_investment, 2),
    round(mov.reconciliation, 2)
  from monthly_income inc
  cross join account_spending acc
  cross join card_spending cards
  cross join benefit_spending benefits
  cross join refunds_made refunds
  cross join competence_cards_agg card_comp
  cross join competence_direct comp_direct
  cross join competence_benefits comp_benefits
  cross join competence_refunds comp_refunds
  cross join cash_totals cash
  cross join nonspending_movements mov;
end;
$function$;

revoke all on function public.get_monthly_money_summary(uuid,date) from public;
grant execute on function public.get_monthly_money_summary(uuid,date) to authenticated;

comment on function public.get_monthly_money_summary(uuid,date) is
'Canonical monthly read model. Spending made uses occurred_at; economic competence uses financial_impacts/effective_date; cash movement is reported separately. Card payments, transfers, reserve movements, opening balances and adjustments never become income or economic expense here.';
