-- Regression tests for Transactions 2.0 canonical actions.
-- Fixtures are isolated in a transaction and rolled back.

begin;

do $test$
declare
  v_user uuid;
  v_space uuid := gen_random_uuid();
  v_account_a uuid := gen_random_uuid();
  v_account_b uuid := gen_random_uuid();
  v_benefit uuid := gen_random_uuid();
  v_card uuid := gen_random_uuid();
  v_category uuid := gen_random_uuid();
  v_category_2 uuid := gen_random_uuid();
  v_purchase uuid;
  v_purchase_event uuid;
  v_invoice uuid;
  v_benefit_event uuid;
  v_transfer_event uuid := gen_random_uuid();
  v_payment_event uuid;
  v_count integer;
  v_value numeric;
begin
  select owner_id into v_user from public.financial_spaces order by created_at limit 1;
  if v_user is null then raise exception 'test_setup_no_user'; end if;
  perform set_config('request.jwt.claim.sub', v_user::text, true);

  insert into public.financial_spaces(id,owner_id,name,type,currency,timezone)
  values(v_space,v_user,'Transactions 2 test','personal','BRL','America/Sao_Paulo');
  insert into public.space_members(space_id,user_id,role) values(v_space,v_user,'owner');
  insert into public.accounts(id,space_id,name,type,available_for_spending,active) values
    (v_account_a,v_space,'Conta A','checking',true,true),
    (v_account_b,v_space,'Conta B','checking',true,true),
    (v_benefit,v_space,'Benefício','benefit',false,true);
  insert into public.categories(id,space_id,name,kind,active) values
    (v_category,v_space,'Categoria A','expense',true),
    (v_category_2,v_space,'Categoria B','expense',true);
  insert into public.credit_cards(id,space_id,name,closing_day,due_day,payment_account_id,active)
  values(v_card,v_space,'Cartão teste',20,27,v_account_a,true);

  -- Card purchase update keeps card semantics and existing installment structure.
  v_purchase := public.register_card_purchase(
    v_space,v_card,100,'Compra original',2,v_category,
    '2026-10-10 12:00:00-03'::timestamptz,'Loja original','app',null
  );
  select event_id into v_purchase_event from public.card_purchases where id=v_purchase;

  perform public.update_card_purchase(
    v_space,v_purchase_event,120,'Compra editada',v_category_2,'Loja nova',v_card,
    '2026-10-10 12:00:00-03'::timestamptz
  );

  if not exists(select 1 from public.financial_events where id=v_purchase_event and amount=120 and description='Compra editada' and category_id=v_category_2 and status='confirmed') then
    raise exception 'card_purchase_event_update_failed';
  end if;
  if not exists(select 1 from public.card_purchases where id=v_purchase and total_amount=120 and merchant='Loja nova' and installments_count=2 and card_id=v_card) then
    raise exception 'card_purchase_backing_update_failed';
  end if;
  select count(*) into v_count from public.card_installments where purchase_id=v_purchase;
  if v_count <> 2 then raise exception 'card_purchase_installments_rewritten'; end if;
  select coalesce(sum(amount),0) into v_value from public.card_installments where purchase_id=v_purchase;
  if v_value <> 120 then raise exception 'card_purchase_installment_total_invalid'; end if;
  if exists(select 1 from public.financial_impacts where event_id=v_purchase_event and dimension='cash') then raise exception 'card_purchase_cash_created'; end if;
  select coalesce(sum(amount),0) into v_value from public.financial_impacts where event_id=v_purchase_event and dimension='economic';
  if v_value <> -120 then raise exception 'card_purchase_economic_invalid'; end if;
  select coalesce(sum(amount),0) into v_value from public.financial_impacts where event_id=v_purchase_event and dimension='budget';
  if v_value <> -120 then raise exception 'card_purchase_budget_invalid'; end if;

  perform public.cancel_card_purchase(v_space,v_purchase_event);
  if not exists(select 1 from public.financial_events where id=v_purchase_event and status='cancelled') then raise exception 'card_purchase_event_not_cancelled'; end if;
  if not exists(select 1 from public.card_purchases where id=v_purchase and status='cancelled') then raise exception 'card_purchase_backing_not_cancelled'; end if;
  if exists(select 1 from public.financial_impacts where event_id=v_purchase_event) then raise exception 'card_purchase_cancel_impacts_remain'; end if;

  -- Benefit supports retroactive date, canonical update and cancellation with cash=0.
  v_benefit_event := public.register_benefit_at(
    v_space,v_benefit,35,'Benefício retroativo',false,v_category,
    '2026-07-10 12:00:00-03'::timestamptz
  );
  if not exists(select 1 from public.financial_events where id=v_benefit_event and event_type='benefit_expense' and competence_date='2026-07-10') then raise exception 'retroactive_benefit_date_failed'; end if;
  perform public.update_benefit_expense(
    v_space,v_benefit_event,v_benefit,50,'Benefício editado',v_category_2,
    '2026-07-11 12:00:00-03'::timestamptz
  );
  if exists(select 1 from public.financial_impacts where event_id=v_benefit_event and dimension='cash') then raise exception 'benefit_cash_created'; end if;
  select coalesce(sum(amount),0) into v_value from public.financial_impacts where event_id=v_benefit_event and dimension='benefit';
  if v_value <> -50 then raise exception 'benefit_dimension_invalid'; end if;
  select coalesce(sum(amount),0) into v_value from public.financial_impacts where event_id=v_benefit_event and dimension='economic';
  if v_value <> -50 then raise exception 'benefit_economic_invalid'; end if;
  select coalesce(sum(amount),0) into v_value from public.financial_impacts where event_id=v_benefit_event and dimension='budget';
  if v_value <> -50 then raise exception 'benefit_budget_invalid'; end if;
  perform public.cancel_benefit_expense(v_space,v_benefit_event);
  if exists(select 1 from public.financial_impacts where event_id=v_benefit_event) then raise exception 'benefit_cancel_impacts_remain'; end if;

  -- Canonical transfer always stays cash zero-sum and has no economic/budget impacts.
  insert into public.financial_events(id,space_id,event_type,description,amount,currency,occurred_at,competence_date,status,source,metadata)
  values(v_transfer_event,v_space,'transfer','Transferência',40,'BRL','2026-10-12 12:00:00-03','2026-10-12','confirmed','app',jsonb_build_object('from_account_id',v_account_a,'to_account_id',v_account_b));
  insert into public.financial_impacts(space_id,event_id,dimension,amount,account_id,effective_date) values
    (v_space,v_transfer_event,'cash',-40,v_account_a,'2026-10-12'),
    (v_space,v_transfer_event,'cash',40,v_account_b,'2026-10-12');
  perform public.update_transfer_transaction(v_space,v_transfer_event,v_account_b,v_account_a,75,'Transferência editada','2026-10-13 12:00:00-03');
  select coalesce(sum(amount),0) into v_value from public.financial_impacts where event_id=v_transfer_event and dimension='cash';
  if v_value <> 0 then raise exception 'transfer_cash_not_zero_sum'; end if;
  if (select count(*) from public.financial_impacts where event_id=v_transfer_event and dimension='cash') <> 2 then raise exception 'transfer_cash_legs_invalid'; end if;
  if exists(select 1 from public.financial_impacts where event_id=v_transfer_event and dimension in ('economic','budget')) then raise exception 'transfer_economic_or_budget_created'; end if;
  perform public.cancel_transfer_transaction(v_space,v_transfer_event);
  if exists(select 1 from public.financial_impacts where event_id=v_transfer_event) then raise exception 'transfer_cancel_impacts_remain'; end if;

  -- Canonical card payment reversal restores cash and invoice outstanding without economic/budget.
  v_purchase := public.register_card_purchase(
    v_space,v_card,80,'Compra para pagamento',1,v_category,
    '2026-11-10 12:00:00-03'::timestamptz,null,'app',null
  );
  select ci.invoice_id into v_invoice from public.card_installments ci where ci.purchase_id=v_purchase limit 1;
  perform public.pay_card_invoice(
    v_space,v_invoice,v_account_a,20,'payment','2026-11-20 12:00:00-03'::timestamptz,'app',null
  );
  select cp.event_id into v_payment_event from public.card_payments cp
  where cp.space_id=v_space and cp.invoice_id=v_invoice and cp.amount=20 and cp.status='confirmed'
  order by cp.created_at desc limit 1;
  if v_payment_event is null then raise exception 'card_payment_fixture_missing'; end if;
  if exists(select 1 from public.financial_impacts where event_id=v_payment_event and dimension in ('economic','budget')) then raise exception 'card_payment_has_economic_or_budget'; end if;
  select coalesce(sum(amount),0) into v_value from public.financial_impacts where event_id=v_payment_event and dimension='cash';
  if v_value <> -20 then raise exception 'card_payment_cash_invalid'; end if;

  perform public.reverse_card_payment(v_space,v_payment_event);
  if not exists(select 1 from public.financial_events where id=v_payment_event and status='cancelled') then raise exception 'card_payment_event_not_cancelled'; end if;
  if not exists(select 1 from public.card_payments where event_id=v_payment_event and status='cancelled') then raise exception 'card_payment_backing_not_cancelled'; end if;
  if exists(select 1 from public.financial_impacts where event_id=v_payment_event) then raise exception 'card_payment_cash_not_restored'; end if;
  if not exists(select 1 from public.card_invoices where id=v_invoice and status in ('open','closed','overdue')) then raise exception 'card_payment_invoice_status_not_restored'; end if;
end;
$test$;

rollback;
