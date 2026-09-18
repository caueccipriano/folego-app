-- Card invoice semantics 1.0
-- Distinguishes cycle purchases, credits, payments and amount due from
-- monthly card competence.

create or replace function public.get_card_invoice_semantics(
  p_space_id uuid,
  p_card_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_result jsonb;
begin
  if auth.uid() is null or not private.is_space_member(p_space_id) then
    raise exception 'read_access_denied' using errcode='42501';
  end if;

  if not exists(
    select 1
    from public.credit_cards c
    where c.id = p_card_id
      and c.space_id = p_space_id
  ) then
    raise exception 'card_not_found';
  end if;

  with current_invoice as (
    select ci.*
    from public.card_invoices ci
    where ci.space_id = p_space_id
      and ci.card_id = p_card_id
      and ci.status not in ('paid','cancelled')
    order by ci.due_date asc
    limit 1
  ),
  totals as (
    select
      ci.id as invoice_id,
      ci.reference_month,
      ci.closing_date,
      ci.due_date,
      ci.opening_balance,
      coalesce(sum(inst.amount) filter (
        where inst.status <> 'cancelled'
      ),0::numeric) as gross_purchases,
      coalesce(sum(inst.amount) filter (
        where inst.status = 'refunded'
      ),0::numeric) as credits,
      coalesce((
        select sum(cp.amount)
        from public.card_payments cp
        where cp.invoice_id = ci.id
          and cp.space_id = ci.space_id
          and cp.status = 'confirmed'
      ),0::numeric) as payments
    from current_invoice ci
    left join public.card_installments inst
      on inst.invoice_id = ci.id
     and inst.space_id = ci.space_id
    group by ci.id, ci.reference_month, ci.closing_date, ci.due_date,
             ci.opening_balance, ci.space_id
  )
  select case
    when not exists(select 1 from totals) then
      jsonb_build_object(
        'invoice_id', null,
        'gross_purchases', 0,
        'credits', 0,
        'payments', 0,
        'amount_due', 0,
        'due_date', null,
        'closing_date', null,
        'reference_month', null
      )
    else (
      select jsonb_build_object(
        'invoice_id', t.invoice_id,
        'gross_purchases', round(t.gross_purchases,2),
        'credits', round(t.credits,2),
        'payments', round(t.payments,2),
        'amount_due', round(greatest(
          t.opening_balance + t.gross_purchases - t.credits - t.payments,
          0::numeric
        ),2),
        'due_date', t.due_date,
        'closing_date', t.closing_date,
        'reference_month', t.reference_month
      )
      from totals t
    )
  end into v_result;

  return v_result;
end;
$function$;

revoke all on function public.get_card_invoice_semantics(uuid,uuid)
  from public, anon;
grant execute on function public.get_card_invoice_semantics(uuid,uuid)
  to authenticated, service_role;
