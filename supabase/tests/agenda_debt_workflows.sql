-- Agenda + Debt 2.0 regression coverage. Fixtures are isolated and rolled back.
begin;

do $test$
declare
  v_user uuid;
  v_space uuid := gen_random_uuid();
  v_account uuid := gen_random_uuid();
  v_card uuid := gen_random_uuid();
  v_category uuid := gen_random_uuid();
  v_recurring_account uuid := gen_random_uuid();
  v_recurring_card uuid := gen_random_uuid();
  v_recurring_income uuid := gen_random_uuid();
  v_today date := (now() at time zone 'America/Sao_Paulo')::date;
  v_purchase uuid;
  v_invoice uuid;
  v_debt uuid;
  v_close_debt uuid;
  v_installment uuid;
  v_event uuid;
  v_before_events bigint;
  v_before_impacts bigint;
  v_count bigint;
  v_amount numeric;
begin
  select owner_id into v_user from public.financial_spaces order by created_at limit 1;
  if v_user is null then raise exception 'test_setup_no_user'; end if;
  perform set_config('request.jwt.claim.sub', v_user::text, true);

  insert into public.financial_spaces(id, owner_id, name, type, currency, timezone)
  values(v_space, v_user, 'Agenda Debt test', 'personal', 'BRL', 'America/Sao_Paulo');
  insert into public.space_members(space_id, user_id, role) values(v_space, v_user, 'owner');
  insert into public.accounts(id, space_id, name, type, available_for_spending, active)
  values(v_account, v_space, 'Conta teste', 'checking', true, true);
  insert into public.categories(id, space_id, name, kind, active)
  values(v_category, v_space, 'Teste agenda', 'expense', true);
  insert into public.credit_cards(id, space_id, name, closing_day, due_day, payment_account_id, active)
  values(v_card, v_space, 'Cartão teste', 20, 27, v_account, true);

  insert into public.recurring_items(id,space_id,name,item_type,amount,frequency,weekday,category_id,account_id,starts_on,certainty,active)
  values(v_recurring_account,v_space,'Conta recorrente','expense',40,'weekly',extract(dow from v_today)::int,v_category,v_account,v_today-7,'confirmed',true);
  insert into public.recurring_items(id,space_id,name,item_type,amount,frequency,weekday,category_id,card_id,starts_on,certainty,active)
  values(v_recurring_card,v_space,'Cartão recorrente','expense',25,'weekly',extract(dow from v_today)::int,v_category,v_card,v_today-7,'confirmed',true);
  insert into public.recurring_items(id,space_id,name,item_type,amount,frequency,weekday,account_id,starts_on,certainty,active)
  values(v_recurring_income,v_space,'Receita recorrente','income',500,'weekly',extract(dow from v_today)::int,v_account,v_today-7,'confirmed',true);

  v_purchase := public.register_card_purchase(v_space,v_card,90,'Compra parcelada teste',3,v_category,now(),'Loja teste','test',null);
  select invoice_id into v_invoice from public.card_installments where purchase_id=v_purchase order by installment_number limit 1;
  update public.card_invoices set due_date=v_today-1 where id=v_invoice;

  select count(*) into v_before_events from public.financial_events where space_id=v_space;
  select count(*) into v_before_impacts from public.financial_impacts where space_id=v_space;
  v_debt := public.create_debt_v2(v_space,'Dívida teste','Credor teste',100,3,v_today-2,v_account,v_today-30,1.5,'loan','nota inicial');
  if (select count(*) from public.financial_events where space_id=v_space)<>v_before_events then raise exception 'debt_create_created_financial_event'; end if;
  if (select count(*) from public.financial_impacts where space_id=v_space)<>v_before_impacts then raise exception 'debt_create_created_financial_impact'; end if;

  select count(*),sum(planned_amount) into v_count,v_amount from public.debt_installments where debt_id=v_debt;
  if v_count<>3 or v_amount<>100 then raise exception 'debt_schedule_total_invalid'; end if;
  if not exists(select 1 from public.debt_installments where debt_id=v_debt and installment_number=3 and planned_amount=33.34) then raise exception 'debt_last_cent_adjustment_invalid'; end if;

  perform public.update_debt_v2(v_space,v_debt,'Dívida teste','Credor teste',120,4,v_today-2,v_account,v_today-30,1.5,'loan','reestruturada antes de pagar');
  if (select count(*) from public.debt_installments where debt_id=v_debt)<>4 then raise exception 'debt_pre_payment_restructure_failed'; end if;

  select id into v_installment from public.debt_installments where debt_id=v_debt order by installment_number limit 1;
  v_event := public.pay_debt_installment_v2(v_space,v_installment,v_account,10,now());
  if (select count(*) from public.financial_impacts where event_id=v_event)<>1 then raise exception 'debt_payment_impact_count_invalid'; end if;
  if not exists(select 1 from public.financial_impacts where event_id=v_event and dimension='cash' and amount=-10 and account_id=v_account) then raise exception 'debt_payment_cash_missing'; end if;
  if exists(select 1 from public.financial_impacts where event_id=v_event and dimension in ('economic','budget')) then raise exception 'debt_payment_duplicated_expense'; end if;
  if not exists(select 1 from public.debt_payments where event_id=v_event and debt_id=v_debt and installment_id=v_installment and amount=10) then raise exception 'debt_payment_backing_missing'; end if;
  if not exists(select 1 from public.debt_installments where id=v_installment and paid_amount=10 and status='partially_paid') then raise exception 'debt_partial_payment_invalid'; end if;

  begin
    perform public.update_debt_v2(v_space,v_debt,'Dívida teste','Credor teste',120,6,v_today-2,v_account,v_today-30,1.5,'loan','tentativa inválida');
    raise exception 'debt_restructure_after_payment_not_blocked';
  exception when others then
    if sqlerrm='debt_restructure_after_payment_not_blocked' then raise; end if;
    if position('debt_restructure_after_payment' in sqlerrm)=0 then raise; end if;
  end;

  perform public.update_debt_v2(v_space,v_debt,'Dívida renomeada','Credor atualizado',120,4,v_today-2,v_account,v_today-30,2.0,'financing','nota administrativa');
  if not exists(select 1 from public.debts where id=v_debt and name='Dívida renomeada' and creditor='Credor atualizado' and debt_type='financing' and notes='nota administrativa' and interest_rate_monthly=2.0) then raise exception 'debt_admin_update_failed'; end if;

  perform public.archive_debt(v_space,v_debt);
  if not exists(select 1 from public.debts where id=v_debt and archived_at is not null) then raise exception 'debt_archive_failed'; end if;
  perform public.reopen_debt(v_space,v_debt);
  if not exists(select 1 from public.debts where id=v_debt and archived_at is null and status='active') then raise exception 'debt_reopen_failed'; end if;

  begin
    perform public.close_debt(v_space,v_debt);
    raise exception 'debt_close_open_balance_not_blocked';
  exception when others then
    if sqlerrm='debt_close_open_balance_not_blocked' then raise; end if;
    if position('debt_has_open_balance' in sqlerrm)=0 then raise; end if;
  end;

  v_close_debt := public.create_debt_v2(v_space,'Dívida para fechar','Credor',20,1,v_today+20,v_account,v_today,null,'other',null);
  update public.debt_installments set status='cancelled' where debt_id=v_close_debt;
  perform public.close_debt(v_space,v_close_debt);
  if not exists(select 1 from public.debts where id=v_close_debt and status='paid' and closed_at is not null) then raise exception 'debt_close_failed'; end if;

  if not exists(select 1 from public.get_upcoming_events(v_space,v_today-7,v_today+60,200) where source='recurring' and source_id=v_recurring_account and due_date=v_today and direction='outflow' and cash_obligation and not overdue) then raise exception 'agenda_account_recurring_invalid'; end if;
  if not exists(select 1 from public.get_upcoming_events(v_space,v_today-7,v_today+60,200) where source='recurring' and source_id=v_recurring_card and due_date=v_today and direction='informational' and not cash_obligation and not overdue) then raise exception 'agenda_card_recurring_invalid'; end if;
  if not exists(select 1 from public.get_upcoming_events(v_space,v_today-7,v_today+60,200) where source='recurring' and source_id=v_recurring_income and due_date=v_today and direction='income' and not overdue) then raise exception 'agenda_income_recurring_invalid'; end if;
  if not exists(select 1 from public.get_upcoming_events(v_space,v_today-7,v_today+60,200) where source='invoice' and invoice_id=v_invoice and overdue and cash_obligation) then raise exception 'agenda_overdue_invoice_invalid'; end if;
  if not exists(select 1 from public.get_upcoming_events(v_space,v_today-7,v_today+60,200) where source='debt' and debt_id=v_debt and cash_obligation) then raise exception 'agenda_debt_missing'; end if;
  if exists(select 1 from public.get_upcoming_events(v_space,v_today-7,v_today+60,200) where card_id=v_card and cash_obligation and source<>'invoice') then raise exception 'agenda_card_cash_double_count'; end if;
  if exists(select 1 from public.get_upcoming_events(v_space,v_today-7,v_today+60,200) where source='card_installment') then raise exception 'agenda_exposed_card_installment_as_cash'; end if;

  if not exists(select 1 from public.get_upcoming_events(p_space_id=>v_space,p_from=>v_today-7,p_until=>v_today+60) where source='invoice' and id=v_invoice) then raise exception 'agenda_compatibility_wrapper_failed'; end if;

  perform set_config('request.jwt.claim.sub',gen_random_uuid()::text,true);
  begin
    perform 1 from public.get_upcoming_events(v_space,v_today,v_today+7,20);
    raise exception 'agenda_membership_not_enforced';
  exception when insufficient_privilege then null;
  end;
  perform set_config('request.jwt.claim.sub',v_user::text,true);
end
$test$;

rollback;
