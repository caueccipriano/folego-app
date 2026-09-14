-- Integration regression tests for benefit ledger semantics.
-- The entire test runs inside a transaction and rolls back all created data.

begin;

do $test$
declare
  v_user uuid;
  v_space uuid := gen_random_uuid();
  v_benefit_account uuid := gen_random_uuid();
  v_checking_account uuid := gen_random_uuid();
  v_expense_category uuid := gen_random_uuid();
  v_income_category uuid := gen_random_uuid();
  v_event uuid;
  v_account uuid;
  v_value numeric;
  v_count integer;
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
  values(v_space, v_user, 'Benefit ledger semantics test', 'personal', 'BRL', 'America/Sao_Paulo');

  insert into public.space_members(space_id, user_id, role)
  values(v_space, v_user, 'owner');

  insert into public.categories(id, space_id, name, kind, essential, active)
  values
    (v_expense_category, v_space, 'Test expense', 'expense', false, true),
    (v_income_category, v_space, 'Test income', 'income', false, true);

  insert into public.accounts(id, space_id, name, type, available_for_spending, active)
  values
    (v_benefit_account, v_space, 'Test Benefit', 'benefit', false, true),
    (v_checking_account, v_space, 'Test Checking', 'checking', true, true);

  -- A. Benefit credit: benefit +300 only.
  v_event := public.register_benefit(
    v_space,
    v_benefit_account,
    300,
    'Benefit credit test',
    true,
    v_income_category
  );

  if not exists (
    select 1 from public.financial_events
    where id = v_event
      and space_id = v_space
      and event_type = 'benefit_credit'
      and category_id = v_income_category
      and status = 'confirmed'
  ) then
    raise exception 'test_credit_event_failed';
  end if;

  select coalesce(sum(amount), 0), count(*)
  into v_value, v_count
  from public.financial_impacts
  where event_id = v_event
    and space_id = v_space
    and dimension = 'benefit';

  if v_value <> 300 or v_count <> 1 then
    raise exception 'test_credit_benefit_impact_failed';
  end if;

  if exists (
    select 1 from public.financial_impacts
    where event_id = v_event
      and space_id = v_space
      and dimension in ('cash', 'economic', 'budget', 'commitment')
  ) then
    raise exception 'test_credit_unexpected_impact_failed';
  end if;

  -- B. Benefit expense: benefit/economic/budget -80, no cash.
  v_event := public.register_benefit(
    v_space,
    v_benefit_account,
    80,
    'Benefit expense test',
    false,
    v_expense_category
  );

  if not exists (
    select 1 from public.financial_events
    where id = v_event
      and space_id = v_space
      and event_type = 'benefit_expense'
      and category_id = v_expense_category
      and status = 'confirmed'
  ) then
    raise exception 'test_expense_event_failed';
  end if;

  if not exists (
    select 1 from public.financial_impacts
    where event_id = v_event
      and space_id = v_space
      and dimension = 'benefit'
      and account_id = v_benefit_account
      and amount = -80
  ) then
    raise exception 'test_expense_benefit_impact_failed';
  end if;

  if not exists (
    select 1 from public.financial_impacts
    where event_id = v_event
      and space_id = v_space
      and dimension = 'economic'
      and category_id = v_expense_category
      and amount = -80
  ) then
    raise exception 'test_expense_economic_impact_failed';
  end if;

  if not exists (
    select 1 from public.financial_impacts
    where event_id = v_event
      and space_id = v_space
      and dimension = 'budget'
      and category_id = v_expense_category
      and amount = -80
  ) then
    raise exception 'test_expense_budget_impact_failed';
  end if;

  select count(*) into v_count
  from public.financial_impacts
  where event_id = v_event
    and space_id = v_space;

  if v_count <> 3 then
    raise exception 'test_expense_impact_count_failed';
  end if;

  if exists (
    select 1 from public.financial_impacts
    where event_id = v_event
      and space_id = v_space
      and dimension = 'cash'
  ) then
    raise exception 'test_expense_cash_impact_failed';
  end if;

  -- C. register_benefit must reject a non-benefit account.
  begin
    perform public.register_benefit(
      v_space,
      v_checking_account,
      10,
      'Invalid benefit account test',
      true,
      v_income_category
    );
    raise exception 'test_non_benefit_account_was_accepted';
  exception
    when others then
      if sqlerrm = 'test_non_benefit_account_was_accepted' then
        raise;
      end if;

      if position('invalid_benefit_account' in sqlerrm) = 0 then
        raise exception 'test_non_benefit_wrong_error: %', sqlerrm;
      end if;
  end;

  -- D. Benefit opening balance: benefit +300, no cash.
  v_account := public.onboarding_create_account(
    v_space,
    'Opening Benefit',
    300,
    current_date,
    'Test',
    'benefit',
    false
  );

  select fe.id into v_event
  from public.financial_events fe
  where fe.space_id = v_space
    and fe.external_id = 'onboarding:opening_balance:' || v_account::text
    and fe.event_type = 'opening_balance';

  if v_event is null then
    raise exception 'test_benefit_opening_event_missing';
  end if;

  if not exists (
    select 1 from public.financial_impacts
    where event_id = v_event
      and space_id = v_space
      and dimension = 'benefit'
      and account_id = v_account
      and amount = 300
  ) then
    raise exception 'test_benefit_opening_impact_failed';
  end if;

  if exists (
    select 1 from public.financial_impacts
    where event_id = v_event
      and space_id = v_space
      and dimension = 'cash'
  ) then
    raise exception 'test_benefit_opening_cash_failed';
  end if;

  -- E. Banking opening balance keeps the existing cash semantics.
  v_account := public.onboarding_create_account(
    v_space,
    'Opening Checking',
    300,
    current_date,
    'Test Bank',
    'checking',
    true
  );

  select fe.id into v_event
  from public.financial_events fe
  where fe.space_id = v_space
    and fe.external_id = 'onboarding:opening_balance:' || v_account::text
    and fe.event_type = 'opening_balance';

  if v_event is null then
    raise exception 'test_checking_opening_event_missing';
  end if;

  if not exists (
    select 1 from public.financial_impacts
    where event_id = v_event
      and space_id = v_space
      and dimension = 'cash'
      and account_id = v_account
      and amount = 300
  ) then
    raise exception 'test_checking_opening_cash_failed';
  end if;

  if exists (
    select 1 from public.financial_impacts
    where event_id = v_event
      and space_id = v_space
      and dimension = 'benefit'
  ) then
    raise exception 'test_checking_opening_benefit_failed';
  end if;
end;
$test$;

rollback;

select 'ok' as benefit_ledger_semantics_tests;
