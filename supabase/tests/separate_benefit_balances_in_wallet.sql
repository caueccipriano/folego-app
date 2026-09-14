-- Integration regression tests for Wallet cash/benefit separation.
-- The entire test runs inside a transaction and rolls back all created data.

begin;

do $test$
declare
  v_user uuid;
  v_space uuid := gen_random_uuid();
  v_checking_a uuid := gen_random_uuid();
  v_checking_b uuid := gen_random_uuid();
  v_benefit uuid := gen_random_uuid();
  v_card uuid := gen_random_uuid();
  v_invoice uuid := gen_random_uuid();
  v_event uuid;
  v_wallet jsonb;
  v_value numeric;
begin
  select owner_id into v_user
  from public.financial_spaces
  order by created_at
  limit 1;

  if v_user is null then
    raise exception 'test_setup_no_user';
  end if;

  perform set_config('request.jwt.claim.sub', v_user::text, true);

  insert into public.financial_spaces(id, owner_id, name, type, currency, timezone)
  values(v_space, v_user, 'Wallet benefit separation test', 'personal', 'BRL', 'America/Sao_Paulo');

  insert into public.space_members(space_id, user_id, role)
  values(v_space, v_user, 'owner');

  insert into public.accounts(id, space_id, name, type, available_for_spending, active)
  values
    (v_checking_a, v_space, 'Santander', 'checking', true, true),
    (v_checking_b, v_space, 'Bradesco', 'checking', true, true),
    (v_benefit, v_space, 'Flash Alimentação', 'benefit', true, true);

  -- A. checking cash +500 -> Wallet balance = 500.
  insert into public.financial_events(
    space_id,event_type,description,amount,currency,occurred_at,competence_date,status,source
  ) values (
    v_space,'opening_balance','Santander',500,'BRL',now(),current_date,'confirmed','test'
  ) returning id into v_event;

  insert into public.financial_impacts(event_id,space_id,dimension,amount,account_id,effective_date)
  values(v_event,v_space,'cash',500,v_checking_a,current_date);

  insert into public.financial_events(
    space_id,event_type,description,amount,currency,occurred_at,competence_date,status,source
  ) values (
    v_space,'opening_balance','Bradesco',100,'BRL',now(),current_date,'confirmed','test'
  ) returning id into v_event;

  insert into public.financial_impacts(event_id,space_id,dimension,amount,account_id,effective_date)
  values(v_event,v_space,'cash',100,v_checking_b,current_date);

  -- B/C. benefit +300 -80 -> Wallet benefit balance = 220.
  insert into public.financial_events(
    space_id,event_type,description,amount,currency,occurred_at,competence_date,status,source
  ) values (
    v_space,'benefit_credit','Flash credit',300,'BRL',now(),current_date,'confirmed','test'
  ) returning id into v_event;

  insert into public.financial_impacts(event_id,space_id,dimension,amount,account_id,effective_date)
  values(v_event,v_space,'benefit',300,v_benefit,current_date);

  insert into public.financial_events(
    space_id,event_type,description,amount,currency,occurred_at,competence_date,status,source
  ) values (
    v_space,'benefit_expense','Flash expense',80,'BRL',now(),current_date,'confirmed','test'
  ) returning id into v_event;

  insert into public.financial_impacts(event_id,space_id,dimension,amount,account_id,effective_date)
  values(v_event,v_space,'benefit',-80,v_benefit,current_date);

  -- D. Legacy/wrong cash on benefit must not inflate either benefit balance or normal cash totals.
  insert into public.financial_events(
    space_id,event_type,description,amount,currency,occurred_at,competence_date,status,source
  ) values (
    v_space,'opening_balance','Legacy wrong benefit cash',300,'BRL',now(),current_date,'confirmed','test'
  ) returning id into v_event;

  insert into public.financial_impacts(event_id,space_id,dimension,amount,account_id,effective_date)
  values(v_event,v_space,'cash',300,v_benefit,current_date);

  -- F. Card/invoice output must remain intact.
  insert into public.credit_cards(
    id,space_id,name,issuer,brand,last_four,closing_day,due_day,payment_account_id,active
  ) values (
    v_card,v_space,'AMEX Gold','Bradesco','American Express','1234',10,15,v_checking_a,true
  );

  insert into public.card_invoices(
    id,space_id,card_id,reference_month,closing_date,due_date,opening_balance,status
  ) values (
    v_invoice,v_space,v_card,date_trunc('month',current_date)::date,current_date,current_date + 5,75,'open'
  );

  v_wallet := public.get_wallet_overview(v_space);

  if (v_wallet #>> '{summary,total_cash}')::numeric <> 600 then
    raise exception 'wallet_total_cash_failed: %', v_wallet #>> '{summary,total_cash}';
  end if;

  if (v_wallet #>> '{summary,available_cash}')::numeric <> 600 then
    raise exception 'wallet_available_cash_failed: %', v_wallet #>> '{summary,available_cash}';
  end if;

  if (v_wallet #>> '{summary,total_benefit}')::numeric <> 220 then
    raise exception 'wallet_total_benefit_failed: %', v_wallet #>> '{summary,total_benefit}';
  end if;

  select (item->>'balance')::numeric into v_value
  from jsonb_array_elements(v_wallet->'accounts') item
  where item->>'id' = v_checking_a::text;

  if v_value <> 500 then
    raise exception 'wallet_checking_balance_failed: %', v_value;
  end if;

  select (item->>'balance')::numeric into v_value
  from jsonb_array_elements(v_wallet->'accounts') item
  where item->>'id' = v_benefit::text;

  if v_value <> 220 then
    raise exception 'wallet_benefit_balance_failed: %', v_value;
  end if;

  -- E. The backward-compatible accounts collection still carries type so Flutter can separate it safely.
  if not exists (
    select 1
    from jsonb_array_elements(v_wallet->'accounts') item
    where item->>'id' = v_benefit::text
      and item->>'type' = 'benefit'
  ) then
    raise exception 'wallet_benefit_type_missing';
  end if;

  if not exists (
    select 1
    from jsonb_array_elements(v_wallet->'cards') item
    where item->>'id' = v_card::text
      and item->>'invoice_id' = v_invoice::text
      and (item->>'invoice_balance')::numeric = 75
  ) then
    raise exception 'wallet_card_invoice_regression_failed';
  end if;
end;
$test$;

rollback;

select 'ok' as separate_benefit_balances_in_wallet_tests;
