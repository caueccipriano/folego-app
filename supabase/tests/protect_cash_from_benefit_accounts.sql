-- Integration regression tests for normal cash flows vs benefit accounts.
-- The entire test runs inside a transaction and rolls back all created data.

begin;

do $test$
declare
  v_user uuid;
  v_space uuid := gen_random_uuid();
  v_snapshot_space uuid := gen_random_uuid();
  v_checking uuid := gen_random_uuid();
  v_benefit uuid := gen_random_uuid();
  v_checking_a uuid := gen_random_uuid();
  v_checking_b uuid := gen_random_uuid();
  v_snapshot_benefit uuid := gen_random_uuid();
  v_income_category uuid := gen_random_uuid();
  v_expense_category uuid := gen_random_uuid();
  v_event uuid;
  v_account uuid;
  v_count integer;
  v_liquid numeric;
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
  values
    (v_space, v_user, 'Protect benefit cash test', 'personal', 'BRL', 'America/Sao_Paulo'),
    (v_snapshot_space, v_user, 'Protect benefit snapshot test', 'personal', 'BRL', 'America/Sao_Paulo');

  insert into public.space_members(space_id, user_id, role)
  values
    (v_space, v_user, 'owner'),
    (v_snapshot_space, v_user, 'owner');

  insert into public.categories(id, space_id, name, kind, essential, active)
  values
    (v_income_category, v_space, 'Test income', 'income', false, true),
    (v_expense_category, v_space, 'Test expense', 'expense', false, true);

  insert into public.accounts(id, space_id, name, type, available_for_spending, active)
  values
    (v_checking, v_space, 'Checking', 'checking', true, true),
    (v_benefit, v_space, 'Benefit', 'benefit', true, true),
    (v_checking_a, v_snapshot_space, 'Checking A', 'checking', true, true),
    (v_checking_b, v_snapshot_space, 'Checking B', 'checking', true, true),
    (v_snapshot_benefit, v_snapshot_space, 'Legacy Benefit', 'benefit', true, true);

  -- A. Income in a checking account keeps cash + economic semantics.
  v_event := public.register_income(
    v_space,
    v_checking,
    100,
    'Checking income',
    v_income_category,
    now(),
    current_date,
    'test',
    'test:protect:checking-income'
  );

  if not exists (
    select 1 from public.financial_impacts
    where event_id = v_event
      and space_id = v_space
      and dimension = 'cash'
      and account_id = v_checking
      and amount = 100
  ) then
    raise exception 'test_checking_income_cash_failed';
  end if;

  if not exists (
    select 1 from public.financial_impacts
    where event_id = v_event
      and space_id = v_space
      and dimension = 'economic'
      and category_id = v_income_category
      and amount = 100
  ) then
    raise exception 'test_checking_income_economic_failed';
  end if;

  select count(*) into v_count
  from public.financial_impacts
  where event_id = v_event
    and space_id = v_space;

  if v_count <> 2 then
    raise exception 'test_checking_income_impact_count_failed';
  end if;

  -- B. Income in a benefit account must fail and create no event.
  begin
    perform public.register_income(
      v_space,
      v_benefit,
      100,
      'Invalid benefit income',
      v_income_category,
      now(),
      current_date,
      'test',
      'test:protect:benefit-income'
    );
    raise exception 'test_benefit_income_was_accepted';
  exception
    when others then
      if sqlerrm = 'test_benefit_income_was_accepted' then
        raise;
      end if;
      if position('benefit_account_requires_benefit_operation' in sqlerrm) = 0 then
        raise exception 'test_benefit_income_wrong_error: %', sqlerrm;
      end if;
  end;

  if exists (
    select 1 from public.financial_events
    where space_id = v_space
      and external_id = 'test:protect:benefit-income'
  ) then
    raise exception 'test_benefit_income_created_event';
  end if;

  -- C. Normal expense remains blocked for benefit accounts.
  begin
    perform public.register_expense(
      v_space,
      v_benefit,
      80,
      'Invalid benefit expense',
      v_expense_category,
      now(),
      current_date,
      'test',
      'test:protect:benefit-expense'
    );
    raise exception 'test_benefit_expense_was_accepted';
  exception
    when others then
      if sqlerrm = 'test_benefit_expense_was_accepted' then
        raise;
      end if;
      if position('benefit_account_requires_benefit_operation' in sqlerrm) = 0 then
        raise exception 'test_benefit_expense_wrong_error: %', sqlerrm;
      end if;
  end;

  -- D. Normal cash transfer cannot use a benefit account in either direction.
  begin
    perform public.register_transfer(
      v_space,
      v_benefit,
      v_checking,
      10,
      'Invalid transfer from benefit',
      now(),
      'test',
      'test:protect:transfer-from-benefit'
    );
    raise exception 'test_transfer_from_benefit_was_accepted';
  exception
    when others then
      if sqlerrm = 'test_transfer_from_benefit_was_accepted' then
        raise;
      end if;
      if position('benefit_account_requires_benefit_operation' in sqlerrm) = 0 then
        raise exception 'test_transfer_from_benefit_wrong_error: %', sqlerrm;
      end if;
  end;

  begin
    perform public.register_transfer(
      v_space,
      v_checking,
      v_benefit,
      10,
      'Invalid transfer to benefit',
      now(),
      'test',
      'test:protect:transfer-to-benefit'
    );
    raise exception 'test_transfer_to_benefit_was_accepted';
  exception
    when others then
      if sqlerrm = 'test_transfer_to_benefit_was_accepted' then
        raise;
      end if;
      if position('benefit_account_requires_benefit_operation' in sqlerrm) = 0 then
        raise exception 'test_transfer_to_benefit_wrong_error: %', sqlerrm;
      end if;
  end;

  -- G. Regression: canonical benefit credit/expense semantics remain intact.
  v_event := public.register_benefit(
    v_space,
    v_benefit,
    300,
    'Benefit credit',
    true,
    v_income_category
  );

  if not exists (
    select 1 from public.financial_impacts
    where event_id = v_event
      and space_id = v_space
      and dimension = 'benefit'
      and account_id = v_benefit
      and amount = 300
  ) then
    raise exception 'test_benefit_credit_regression_failed';
  end if;

  if exists (
    select 1 from public.financial_impacts
    where event_id = v_event
      and space_id = v_space
      and dimension in ('cash', 'economic', 'budget', 'commitment')
  ) then
    raise exception 'test_benefit_credit_unexpected_impact';
  end if;

  v_event := public.register_benefit(
    v_space,
    v_benefit,
    80,
    'Benefit expense',
    false,
    v_expense_category
  );

  if not exists (
    select 1 from public.financial_impacts
    where event_id = v_event
      and space_id = v_space
      and dimension = 'benefit'
      and account_id = v_benefit
      and amount = -80
  ) then
    raise exception 'test_benefit_expense_benefit_regression_failed';
  end if;

  if not exists (
    select 1 from public.financial_impacts
    where event_id = v_event
      and space_id = v_space
      and dimension = 'economic'
      and category_id = v_expense_category
      and amount = -80
  ) then
    raise exception 'test_benefit_expense_economic_regression_failed';
  end if;

  if not exists (
    select 1 from public.financial_impacts
    where event_id = v_event
      and space_id = v_space
      and dimension = 'budget'
      and category_id = v_expense_category
      and amount = -80
  ) then
    raise exception 'test_benefit_expense_budget_regression_failed';
  end if;

  if exists (
    select 1 from public.financial_impacts
    where event_id = v_event
      and space_id = v_space
      and dimension = 'cash'
  ) then
    raise exception 'test_benefit_expense_cash_regression_failed';
  end if;

  -- E. Snapshot: two checking balances total 600; benefit balance stays separate.
  insert into public.financial_events(
    space_id,event_type,description,amount,currency,occurred_at,competence_date,status,source
  ) values (
    v_snapshot_space,'opening_balance','Checking A balance',500,'BRL',now(),current_date,'confirmed','test'
  ) returning id into v_event;

  insert into public.financial_impacts(event_id,space_id,dimension,amount,account_id,effective_date)
  values(v_event,v_snapshot_space,'cash',500,v_checking_a,current_date);

  insert into public.financial_events(
    space_id,event_type,description,amount,currency,occurred_at,competence_date,status,source
  ) values (
    v_snapshot_space,'opening_balance','Checking B balance',100,'BRL',now(),current_date,'confirmed','test'
  ) returning id into v_event;

  insert into public.financial_impacts(event_id,space_id,dimension,amount,account_id,effective_date)
  values(v_event,v_snapshot_space,'cash',100,v_checking_b,current_date);

  insert into public.financial_events(
    space_id,event_type,description,amount,currency,occurred_at,competence_date,status,source
  ) values (
    v_snapshot_space,'opening_balance','Benefit balance',300,'BRL',now(),current_date,'confirmed','test'
  ) returning id into v_event;

  insert into public.financial_impacts(event_id,space_id,dimension,amount,account_id,effective_date)
  values(v_event,v_snapshot_space,'benefit',300,v_snapshot_benefit,current_date);

  select liquid_balance into v_liquid
  from public.get_folego_snapshot(v_snapshot_space, current_date);

  if v_liquid <> 600 then
    raise exception 'test_snapshot_benefit_exclusion_failed: %', v_liquid;
  end if;

  -- F. Defensive read: a legacy cash +300 on benefit must still not inflate liquid cash.
  insert into public.financial_events(
    space_id,event_type,description,amount,currency,occurred_at,competence_date,status,source
  ) values (
    v_snapshot_space,'opening_balance','Legacy wrong benefit cash',300,'BRL',now(),current_date,'confirmed','test'
  ) returning id into v_event;

  insert into public.financial_impacts(event_id,space_id,dimension,amount,account_id,effective_date)
  values(v_event,v_snapshot_space,'cash',300,v_snapshot_benefit,current_date);

  select liquid_balance into v_liquid
  from public.get_folego_snapshot(v_snapshot_space, current_date);

  if v_liquid <> 600 then
    raise exception 'test_snapshot_legacy_cash_defense_failed: %', v_liquid;
  end if;

  -- Previous P0 remains fixed: benefit opening balance still uses benefit.
  v_account := public.onboarding_create_account(
    v_space,
    'Opening Benefit Guard',
    300,
    current_date,
    'Test',
    'benefit',
    false
  );

  if not exists (
    select 1
    from public.financial_events fe
    join public.financial_impacts fi
      on fi.event_id = fe.id
     and fi.space_id = fe.space_id
    where fe.space_id = v_space
      and fe.external_id = 'onboarding:opening_balance:' || v_account::text
      and fi.dimension = 'benefit'
      and fi.amount = 300
  ) then
    raise exception 'test_benefit_opening_regression_failed';
  end if;
end;
$test$;

rollback;

select 'ok' as protect_cash_from_benefit_accounts_tests;
