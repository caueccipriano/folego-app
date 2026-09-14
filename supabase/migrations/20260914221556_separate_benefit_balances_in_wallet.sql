create or replace function public.get_wallet_overview(p_space_id uuid)
returns jsonb
language sql
stable
set search_path to ''
as $function$
with account_rows as (
  select
    a.id,
    a.name,
    a.institution,
    a.type,
    a.available_for_spending,
    coalesce(
      sum(i.amount) filter (
        where i.dimension = case when a.type = 'benefit' then 'benefit' else 'cash' end
      ),
      0::numeric
    ) as balance
  from public.accounts a
  left join public.financial_impacts i
    on i.account_id = a.id
   and i.space_id = a.space_id
  where a.space_id = p_space_id
    and a.active
  group by a.id, a.name, a.institution, a.type, a.available_for_spending
),
card_rows as (
  select
    c.id,
    c.name,
    c.issuer,
    c.brand,
    c.last_four,
    c.closing_day,
    c.due_day,
    c.personal_limit,
    c.issuer_limit,
    c.payment_account_id,
    inv.invoice_id,
    inv.due_date,
    coalesce(inv.invoice_balance, 0::numeric) as invoice_balance,
    case
      when coalesce(c.personal_limit, c.issuer_limit) is null then null
      else greatest(coalesce(c.personal_limit, c.issuer_limit) - coalesce(inv.invoice_balance, 0::numeric), 0::numeric)
    end as available_limit
  from public.credit_cards c
  left join lateral (
    select
      ci.id as invoice_id,
      ci.due_date,
      greatest(
        ci.opening_balance
        + coalesce((
          select sum(x.amount)
          from public.card_installments x
          where x.invoice_id = ci.id
            and x.space_id = ci.space_id
            and x.status not in ('cancelled','refunded')
        ), 0::numeric)
        - coalesce((
          select sum(p.amount)
          from public.card_payments p
          where p.invoice_id = ci.id
            and p.space_id = ci.space_id
            and p.status = 'confirmed'
        ), 0::numeric),
        0::numeric
      ) as invoice_balance
    from public.card_invoices ci
    where ci.card_id = c.id
      and ci.space_id = c.space_id
      and ci.status not in ('paid','cancelled')
    order by ci.due_date asc
    limit 1
  ) inv on true
  where c.space_id = p_space_id
    and c.active
),
debt_rows as (
  select
    d.id,
    d.name,
    d.creditor,
    d.original_amount,
    d.opening_balance,
    d.total_installments,
    d.payment_account_id,
    coalesce(sum(greatest(di.planned_amount - di.paid_amount, 0::numeric))
      filter (where di.status in ('pending','partially_paid','overdue')), 0::numeric) as remaining_balance,
    min(di.due_date) filter (where di.status in ('pending','partially_paid','overdue')) as next_due_date,
    coalesce((array_agg(greatest(di.planned_amount - di.paid_amount, 0::numeric)
      order by di.due_date) filter (where di.status in ('pending','partially_paid','overdue')))[1], 0::numeric) as next_amount,
    count(*) filter (where di.status = 'paid')::int as paid_installments
  from public.debts d
  left join public.debt_installments di
    on di.debt_id = d.id
   and di.space_id = d.space_id
  where d.space_id = p_space_id
    and d.status = 'active'
  group by d.id, d.name, d.creditor, d.original_amount, d.opening_balance, d.total_installments, d.payment_account_id
),
installment_rows as (
  select
    p.id,
    p.description,
    p.merchant,
    p.total_amount,
    p.installments_count,
    p.card_id,
    c.name as card_name,
    count(ci.id) filter (
      where ci.status not in ('cancelled','refunded')
        and inv.status not in ('paid','cancelled')
    )::int as remaining_installments,
    coalesce(sum(ci.amount) filter (
      where ci.status not in ('cancelled','refunded')
        and inv.status not in ('paid','cancelled')
    ), 0::numeric) as remaining_amount,
    min(inv.due_date) filter (
      where ci.status not in ('cancelled','refunded')
        and inv.status not in ('paid','cancelled')
    ) as next_due_date
  from public.card_purchases p
  join public.credit_cards c
    on c.id = p.card_id
   and c.space_id = p.space_id
  left join public.card_installments ci
    on ci.purchase_id = p.id
   and ci.space_id = p.space_id
  left join public.card_invoices inv
    on inv.id = ci.invoice_id
   and inv.space_id = p.space_id
  where p.space_id = p_space_id
    and p.status not in ('cancelled','refunded')
    and p.installments_count > 1
  group by p.id, p.description, p.merchant, p.total_amount, p.installments_count, p.card_id, c.name
),
summary as (
  select
    coalesce((select sum(balance) from account_rows where type <> 'benefit'), 0::numeric) as total_cash,
    coalesce((select sum(balance) from account_rows where type <> 'benefit' and available_for_spending), 0::numeric) as available_cash,
    coalesce((select sum(balance) from account_rows where type = 'benefit'), 0::numeric) as total_benefit,
    coalesce((select sum(invoice_balance) from card_rows), 0::numeric) as total_card_invoice,
    coalesce((select sum(remaining_balance) from debt_rows), 0::numeric) as total_debt_remaining
)
select jsonb_build_object(
  'summary', (select to_jsonb(summary) from summary),
  'accounts', coalesce((select jsonb_agg(to_jsonb(account_rows) order by name) from account_rows), '[]'::jsonb),
  'cards', coalesce((select jsonb_agg(to_jsonb(card_rows) order by name) from card_rows), '[]'::jsonb),
  'debts', coalesce((select jsonb_agg(to_jsonb(debt_rows) order by name) from debt_rows), '[]'::jsonb),
  'installments', coalesce((select jsonb_agg(to_jsonb(installment_rows) order by next_due_date nulls last, description) from installment_rows where remaining_installments > 0), '[]'::jsonb)
);
$function$;
