-- Canonical transaction actions for Transactions 2.0.
-- Complex event types intentionally keep separate transactional RPCs.

create or replace function public.register_benefit_at(
  p_space_id uuid,
  p_account_id uuid,
  p_amount numeric,
  p_description text,
  p_is_credit boolean,
  p_category_id uuid,
  p_occurred_at timestamptz
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_event_id uuid;
  v_currency char(3);
  v_timezone text;
  v_occurred_at timestamptz;
  v_effective_date date;
  v_amount numeric;
begin
  if auth.uid() is null or not private.can_write_space(p_space_id) then
    raise exception 'write_access_denied';
  end if;
  if p_amount <= 0 or nullif(btrim(p_description), '') is null then
    raise exception 'invalid_amount_or_description';
  end if;
  if not exists (
    select 1 from public.accounts
    where id = p_account_id and space_id = p_space_id and active and type = 'benefit'
  ) then raise exception 'invalid_benefit_account'; end if;
  if p_category_id is not null and not exists (
    select 1 from public.categories
    where id = p_category_id and space_id = p_space_id
      and kind = case when p_is_credit then 'income' else 'expense' end
  ) then raise exception 'invalid_category'; end if;

  select currency, timezone into v_currency, v_timezone
  from public.financial_spaces where id = p_space_id;
  if v_timezone is null then raise exception 'financial_space_not_found'; end if;

  v_amount := round(p_amount, 2);
  v_occurred_at := coalesce(p_occurred_at, now());
  v_effective_date := (v_occurred_at at time zone v_timezone)::date;

  insert into public.financial_events(
    space_id,event_type,description,amount,currency,occurred_at,
    competence_date,category_id,status,source
  ) values (
    p_space_id,
    case when p_is_credit then 'benefit_credit' else 'benefit_expense' end,
    btrim(p_description),v_amount,v_currency,v_occurred_at,
    v_effective_date,p_category_id,'confirmed','app'
  ) returning id into v_event_id;

  if p_is_credit then
    insert into public.financial_impacts(
      space_id,event_id,dimension,amount,account_id,effective_date
    ) values (p_space_id,v_event_id,'benefit',v_amount,p_account_id,v_effective_date);
  else
    insert into public.financial_impacts(
      space_id,event_id,dimension,amount,account_id,category_id,effective_date
    ) values
      (p_space_id,v_event_id,'benefit',-v_amount,p_account_id,null,v_effective_date),
      (p_space_id,v_event_id,'economic',-v_amount,null,p_category_id,v_effective_date),
      (p_space_id,v_event_id,'budget',-v_amount,null,p_category_id,v_effective_date);
  end if;
  return v_event_id;
end;
$$;

create or replace function public.update_benefit_expense(
  p_space_id uuid,
  p_event_id uuid,
  p_account_id uuid,
  p_amount numeric,
  p_description text,
  p_category_id uuid,
  p_occurred_at timestamptz
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_timezone text;
  v_effective_date date;
  v_amount numeric;
  v_event public.financial_events%rowtype;
begin
  if auth.uid() is null or not private.can_write_space(p_space_id) then raise exception 'write_access_denied'; end if;
  select * into v_event from public.financial_events
  where id=p_event_id and space_id=p_space_id for update;
  if v_event.id is null or v_event.event_type <> 'benefit_expense' or v_event.status <> 'confirmed' then
    raise exception 'benefit_expense_not_editable';
  end if;
  if coalesce((v_event.metadata->>'legacy_exception')::boolean,false) then raise exception 'legacy_event_read_only'; end if;
  if p_amount <= 0 or nullif(btrim(p_description),'') is null then raise exception 'invalid_amount_or_description'; end if;
  if not exists(select 1 from public.accounts where id=p_account_id and space_id=p_space_id and active and type='benefit') then
    raise exception 'invalid_benefit_account';
  end if;
  if p_category_id is not null and not exists(select 1 from public.categories where id=p_category_id and space_id=p_space_id and kind='expense') then
    raise exception 'invalid_category';
  end if;
  select timezone into v_timezone from public.financial_spaces where id=p_space_id;
  v_effective_date := (coalesce(p_occurred_at,v_event.occurred_at) at time zone v_timezone)::date;
  v_amount := round(p_amount,2);

  update public.financial_events set
    description=btrim(p_description), amount=v_amount,
    occurred_at=coalesce(p_occurred_at,v_event.occurred_at),
    competence_date=v_effective_date, category_id=p_category_id, updated_at=now()
  where id=p_event_id and space_id=p_space_id;

  delete from public.financial_impacts where event_id=p_event_id and space_id=p_space_id;
  insert into public.financial_impacts(
    space_id,event_id,dimension,amount,account_id,category_id,effective_date
  ) values
    (p_space_id,p_event_id,'benefit',-v_amount,p_account_id,null,v_effective_date),
    (p_space_id,p_event_id,'economic',-v_amount,null,p_category_id,v_effective_date),
    (p_space_id,p_event_id,'budget',-v_amount,null,p_category_id,v_effective_date);
  return p_event_id;
end;
$$;

create or replace function public.cancel_benefit_expense(p_space_id uuid,p_event_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare v_event public.financial_events%rowtype;
begin
  if auth.uid() is null or not private.can_write_space(p_space_id) then raise exception 'write_access_denied'; end if;
  select * into v_event from public.financial_events where id=p_event_id and space_id=p_space_id for update;
  if v_event.id is null or v_event.event_type <> 'benefit_expense' or v_event.status <> 'confirmed' then raise exception 'benefit_expense_not_cancellable'; end if;
  if coalesce((v_event.metadata->>'legacy_exception')::boolean,false) then raise exception 'legacy_event_read_only'; end if;
  update public.financial_events set status='cancelled',updated_at=now() where id=p_event_id;
  delete from public.financial_impacts where event_id=p_event_id and space_id=p_space_id;
  return p_event_id;
end;
$$;

create or replace function public.update_transfer_transaction(
  p_space_id uuid,
  p_event_id uuid,
  p_source_account_id uuid,
  p_destination_account_id uuid,
  p_amount numeric,
  p_description text,
  p_occurred_at timestamptz
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_event public.financial_events%rowtype;
  v_timezone text;
  v_effective_date date;
  v_amount numeric;
  v_cash_count integer;
  v_cash_sum numeric;
begin
  if auth.uid() is null or not private.can_write_space(p_space_id) then raise exception 'write_access_denied'; end if;
  select * into v_event from public.financial_events where id=p_event_id and space_id=p_space_id for update;
  if v_event.id is null or v_event.event_type <> 'transfer' or v_event.status <> 'confirmed' then raise exception 'transfer_not_editable'; end if;
  if coalesce((v_event.metadata->>'legacy_exception')::boolean,false) then raise exception 'legacy_event_read_only'; end if;
  if p_source_account_id = p_destination_account_id then raise exception 'transfer_same_account'; end if;
  if p_amount <= 0 or nullif(btrim(p_description),'') is null then raise exception 'invalid_amount_or_description'; end if;
  if (select count(*) from public.accounts where id in (p_source_account_id,p_destination_account_id) and space_id=p_space_id and active and type <> 'benefit') <> 2 then
    raise exception 'invalid_transfer_accounts';
  end if;
  select count(*),coalesce(sum(amount),0) into v_cash_count,v_cash_sum
  from public.financial_impacts where event_id=p_event_id and space_id=p_space_id and dimension='cash';
  if v_cash_count <> 2 or v_cash_sum <> 0 or exists(
    select 1 from public.financial_impacts where event_id=p_event_id and space_id=p_space_id and dimension in ('economic','budget','benefit')
  ) then raise exception 'transfer_not_canonical'; end if;

  select timezone into v_timezone from public.financial_spaces where id=p_space_id;
  v_effective_date := (coalesce(p_occurred_at,v_event.occurred_at) at time zone v_timezone)::date;
  v_amount := round(p_amount,2);
  update public.financial_events set
    description=btrim(p_description),amount=v_amount,
    occurred_at=coalesce(p_occurred_at,v_event.occurred_at),competence_date=v_effective_date,
    metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('from_account_id',p_source_account_id,'to_account_id',p_destination_account_id),
    updated_at=now()
  where id=p_event_id;
  delete from public.financial_impacts where event_id=p_event_id and space_id=p_space_id;
  insert into public.financial_impacts(space_id,event_id,dimension,amount,account_id,effective_date)
  values
    (p_space_id,p_event_id,'cash',-v_amount,p_source_account_id,v_effective_date),
    (p_space_id,p_event_id,'cash',v_amount,p_destination_account_id,v_effective_date);
  return p_event_id;
end;
$$;

create or replace function public.cancel_transfer_transaction(p_space_id uuid,p_event_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare v_event public.financial_events%rowtype; v_count integer; v_sum numeric;
begin
  if auth.uid() is null or not private.can_write_space(p_space_id) then raise exception 'write_access_denied'; end if;
  select * into v_event from public.financial_events where id=p_event_id and space_id=p_space_id for update;
  if v_event.id is null or v_event.event_type <> 'transfer' or v_event.status <> 'confirmed' then raise exception 'transfer_not_cancellable'; end if;
  if coalesce((v_event.metadata->>'legacy_exception')::boolean,false) then raise exception 'legacy_event_read_only'; end if;
  select count(*),coalesce(sum(amount),0) into v_count,v_sum from public.financial_impacts
  where event_id=p_event_id and space_id=p_space_id and dimension='cash';
  if v_count <> 2 or v_sum <> 0 or exists(select 1 from public.financial_impacts where event_id=p_event_id and dimension in ('economic','budget','benefit')) then
    raise exception 'transfer_not_canonical';
  end if;
  update public.financial_events set status='cancelled',updated_at=now() where id=p_event_id;
  delete from public.financial_impacts where event_id=p_event_id and space_id=p_space_id;
  return p_event_id;
end;
$$;

create or replace function public.update_card_purchase(
  p_space_id uuid,
  p_event_id uuid,
  p_total_amount numeric,
  p_description text,
  p_category_id uuid,
  p_merchant text,
  p_card_id uuid,
  p_purchase_at timestamptz
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_event public.financial_events%rowtype;
  v_purchase public.card_purchases%rowtype;
  v_financial_change boolean;
  v_installment public.card_installments%rowtype;
  v_piece numeric;
  v_remaining numeric;
  v_amount numeric;
  v_first_competence date;
begin
  if auth.uid() is null or not private.can_write_space(p_space_id) then raise exception 'write_access_denied'; end if;
  select * into v_event from public.financial_events where id=p_event_id and space_id=p_space_id for update;
  select * into v_purchase from public.card_purchases where event_id=p_event_id and space_id=p_space_id for update;
  if v_event.id is null or v_event.event_type <> 'card_purchase' or v_event.status <> 'confirmed' or v_purchase.id is null or v_purchase.status <> 'confirmed' then
    raise exception 'card_purchase_not_editable';
  end if;
  if coalesce((v_event.metadata->>'legacy_exception')::boolean,false) then raise exception 'legacy_event_read_only'; end if;
  if p_total_amount <= 0 or nullif(btrim(p_description),'') is null then raise exception 'invalid_amount_or_description'; end if;
  if p_category_id is not null and not exists(select 1 from public.categories where id=p_category_id and space_id=p_space_id and kind='expense') then raise exception 'invalid_category'; end if;
  if p_card_id is distinct from v_purchase.card_id or p_purchase_at is distinct from v_purchase.purchase_at then
    raise exception 'card_purchase_structure_locked';
  end if;
  if exists(select 1 from public.financial_impacts where event_id=p_event_id and space_id=p_space_id and dimension='cash') then
    raise exception 'card_purchase_has_invalid_cash_impact';
  end if;

  v_amount := round(p_total_amount,2);
  v_financial_change := v_amount is distinct from v_purchase.total_amount or p_category_id is distinct from v_purchase.category_id;
  if v_financial_change then
    if exists(
      select 1 from public.card_installments ci join public.card_invoices inv on inv.id=ci.invoice_id and inv.space_id=ci.space_id
      where ci.purchase_id=v_purchase.id and ci.space_id=p_space_id
        and (inv.status <> 'open' or ci.status in ('paid','cancelled','refunded'))
    ) then raise exception 'card_purchase_financial_history_locked'; end if;
    if exists(
      select 1 from public.card_installments ci join public.card_payments cp on cp.invoice_id=ci.invoice_id and cp.space_id=ci.space_id
      where ci.purchase_id=v_purchase.id and ci.space_id=p_space_id and cp.status <> 'cancelled'
    ) then raise exception 'card_purchase_invoice_has_payment'; end if;
  end if;

  update public.card_purchases set
    description=btrim(p_description),merchant=nullif(btrim(p_merchant),''),
    total_amount=v_amount,category_id=p_category_id,updated_at=now()
  where id=v_purchase.id;
  update public.financial_events set
    description=btrim(p_description),amount=v_amount,category_id=p_category_id,updated_at=now()
  where id=p_event_id;

  if v_financial_change then
    v_piece := round(v_amount / v_purchase.installments_count,2);
    v_remaining := v_amount;
    for v_installment in
      select * from public.card_installments where purchase_id=v_purchase.id and space_id=p_space_id order by installment_number for update
    loop
      if v_installment.installment_number = v_purchase.installments_count then
        v_piece := v_remaining;
      end if;
      update public.card_installments set amount=v_piece,updated_at=now() where id=v_installment.id;
      v_remaining := v_remaining - v_piece;
    end loop;

    delete from public.financial_impacts
    where event_id=p_event_id and space_id=p_space_id and dimension in ('economic','budget');
    insert into public.financial_impacts(space_id,event_id,dimension,amount,category_id,effective_date)
    select p_space_id,p_event_id,'economic',-ci.amount,p_category_id,ci.competence_date
    from public.card_installments ci where ci.purchase_id=v_purchase.id and ci.space_id=p_space_id
    union all
    select p_space_id,p_event_id,'budget',-ci.amount,p_category_id,ci.competence_date
    from public.card_installments ci where ci.purchase_id=v_purchase.id and ci.space_id=p_space_id;
    select min(competence_date) into v_first_competence from public.card_installments where purchase_id=v_purchase.id and space_id=p_space_id;
    update public.financial_events set competence_date=v_first_competence where id=p_event_id;
  end if;
  return p_event_id;
end;
$$;

create or replace function public.cancel_card_purchase(p_space_id uuid,p_event_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare v_event public.financial_events%rowtype; v_purchase public.card_purchases%rowtype;
begin
  if auth.uid() is null or not private.can_write_space(p_space_id) then raise exception 'write_access_denied'; end if;
  select * into v_event from public.financial_events where id=p_event_id and space_id=p_space_id for update;
  select * into v_purchase from public.card_purchases where event_id=p_event_id and space_id=p_space_id for update;
  if v_event.id is null or v_event.event_type <> 'card_purchase' or v_event.status <> 'confirmed' or v_purchase.id is null or v_purchase.status <> 'confirmed' then raise exception 'card_purchase_not_cancellable'; end if;
  if coalesce((v_event.metadata->>'legacy_exception')::boolean,false) then raise exception 'legacy_event_read_only'; end if;
  if exists(
    select 1 from public.card_installments ci join public.card_invoices inv on inv.id=ci.invoice_id and inv.space_id=ci.space_id
    where ci.purchase_id=v_purchase.id and ci.space_id=p_space_id
      and (inv.status <> 'open' or ci.status in ('paid','refunded','cancelled'))
  ) then raise exception 'card_purchase_reversal_locked_history'; end if;
  if exists(
    select 1 from public.card_installments ci join public.card_payments cp on cp.invoice_id=ci.invoice_id and cp.space_id=ci.space_id
    where ci.purchase_id=v_purchase.id and ci.space_id=p_space_id and cp.status <> 'cancelled'
  ) then raise exception 'card_purchase_invoice_has_payment'; end if;
  if exists(select 1 from public.financial_impacts where event_id=p_event_id and dimension='cash') then raise exception 'card_purchase_has_invalid_cash_impact'; end if;

  update public.financial_events set status='cancelled',updated_at=now() where id=p_event_id;
  update public.card_purchases set status='cancelled',updated_at=now() where id=v_purchase.id;
  update public.card_installments set status='cancelled',updated_at=now() where purchase_id=v_purchase.id and space_id=p_space_id;
  delete from public.financial_impacts where event_id=p_event_id and space_id=p_space_id;
  update public.recurring_occurrences set status='pending',event_id=null,actual_amount=null,realized_at=null,updated_at=now()
  where event_id=p_event_id and space_id=p_space_id and status='realized';
  return p_event_id;
end;
$$;

create or replace function public.reverse_card_payment(p_space_id uuid,p_event_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_event public.financial_events%rowtype;
  v_payment public.card_payments%rowtype;
  v_invoice public.card_invoices%rowtype;
  v_charges numeric;
  v_payments numeric;
  v_outstanding numeric;
  v_new_status text;
begin
  if auth.uid() is null or not private.can_write_space(p_space_id) then raise exception 'write_access_denied'; end if;
  select * into v_event from public.financial_events where id=p_event_id and space_id=p_space_id for update;
  if v_event.id is null or v_event.event_type <> 'card_payment' or v_event.status <> 'confirmed' then raise exception 'card_payment_not_reversible'; end if;
  if coalesce((v_event.metadata->>'legacy_exception')::boolean,false) then raise exception 'legacy_event_read_only'; end if;
  select * into v_payment from public.card_payments where event_id=p_event_id and space_id=p_space_id for update;
  if v_payment.id is null or v_payment.status <> 'confirmed' then raise exception 'card_payment_backing_missing'; end if;
  select * into v_invoice from public.card_invoices where id=v_payment.invoice_id and space_id=p_space_id for update;
  if v_invoice.id is null then raise exception 'card_payment_invoice_missing'; end if;
  if exists(
    select 1 from public.card_invoices later
    where later.space_id=p_space_id and later.card_id=v_invoice.card_id
      and later.reference_month > v_invoice.reference_month
      and later.opening_balance <> 0
  ) then raise exception 'card_payment_has_later_carryover'; end if;
  if exists(select 1 from public.financial_impacts where event_id=p_event_id and dimension in ('economic','budget')) then raise exception 'card_payment_invalid_economic_impact'; end if;

  update public.card_payments set status='cancelled',updated_at=now() where id=v_payment.id;
  update public.financial_events set status='cancelled',updated_at=now() where id=p_event_id;
  delete from public.financial_impacts where event_id=p_event_id and space_id=p_space_id;

  select v_invoice.opening_balance + coalesce(sum(ci.amount),0) into v_charges
  from public.card_installments ci
  where ci.invoice_id=v_invoice.id and ci.space_id=p_space_id and ci.status not in ('cancelled','refunded');
  select coalesce(sum(cp.amount),0) into v_payments
  from public.card_payments cp where cp.invoice_id=v_invoice.id and cp.space_id=p_space_id and cp.status='confirmed';
  v_outstanding := v_charges - v_payments;
  v_new_status := case
    when v_outstanding <= 0 then 'paid'
    when v_payments > 0 then 'partially_paid'
    when v_invoice.due_date < current_date then 'overdue'
    when v_invoice.closing_date < current_date then 'closed'
    else 'open'
  end;
  update public.card_invoices set status=v_new_status,updated_at=now() where id=v_invoice.id;
  return p_event_id;
end;
$$;

revoke all on function public.register_benefit_at(uuid,uuid,numeric,text,boolean,uuid,timestamptz) from public;
revoke all on function public.update_benefit_expense(uuid,uuid,uuid,numeric,text,uuid,timestamptz) from public;
revoke all on function public.cancel_benefit_expense(uuid,uuid) from public;
revoke all on function public.update_transfer_transaction(uuid,uuid,uuid,uuid,numeric,text,timestamptz) from public;
revoke all on function public.cancel_transfer_transaction(uuid,uuid) from public;
revoke all on function public.update_card_purchase(uuid,uuid,numeric,text,uuid,text,uuid,timestamptz) from public;
revoke all on function public.cancel_card_purchase(uuid,uuid) from public;
revoke all on function public.reverse_card_payment(uuid,uuid) from public;

grant execute on function public.register_benefit_at(uuid,uuid,numeric,text,boolean,uuid,timestamptz) to authenticated;
grant execute on function public.update_benefit_expense(uuid,uuid,uuid,numeric,text,uuid,timestamptz) to authenticated;
grant execute on function public.cancel_benefit_expense(uuid,uuid) to authenticated;
grant execute on function public.update_transfer_transaction(uuid,uuid,uuid,uuid,numeric,text,timestamptz) to authenticated;
grant execute on function public.cancel_transfer_transaction(uuid,uuid) to authenticated;
grant execute on function public.update_card_purchase(uuid,uuid,numeric,text,uuid,text,uuid,timestamptz) to authenticated;
grant execute on function public.cancel_card_purchase(uuid,uuid) to authenticated;
grant execute on function public.reverse_card_payment(uuid,uuid) to authenticated;
