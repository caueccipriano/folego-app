-- Regression test: benefit_expense must not reduce the Folego spendable projection.
-- The entire scenario runs inside a transaction and is rolled back.

begin;

do $test$
declare
  v_user uuid;
  v_space uuid := gen_random_uuid();
  v_parent_category uuid := gen_random_uuid();
  v_expense_category uuid := gen_random_uuid();
  v_cash_account uuid;
  v_benefit_account uuid;
  v_as_of date := current_date;
  v_income_date date := current_date + 10;

  v_benefit_before numeric;
  v_benefit_after numeric;

  v_liquid_before numeric;
  v_cash_headroom_before numeric;
  v_budget_used_before numeric;
  v_economic_before numeric;
  v_spendable_before numeric;
  v_daily_before numeric;

  v_liquid_after_benefit numeric;
  v_cash_headroom_after_benefit numeric;
  v_budget_used_after_benefit numeric;
  v_economic_after_benefit numeric;
  v_spendable_after_benefit numeric;
  v_daily_after_benefit numeric;

  v_liquid_after_cash numeric;
  v_cash_headroom_after_cash numeric;
  v_budget_used_after_cash numeric;
  v_economic_after_cash numeric;
  v_spendable_after_cash numeric;
  v_daily_after_cash numeric;
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
  values(v_space, v_user, 'Benefit spendable projection test', 'personal', 'BRL', 'America/Sao_Paulo');

  insert into public.space_members(space_id, user_id, role)
  values(v_space, v_user, 'owner');

  insert into public.categories(
    id, space_id, name, kind, parent_id, essential, active, category_role, sort_order
  )
  values
    (v_parent_category, v_space, 'Discretionary test', 'expense', null, false, true, 'economic', 10),
    (v_expense_category, v_space, 'Daily spending test', 'expense', v_parent_category, false, true, 'economic', 11);

  v_cash_account := public.onboarding_create_account(
    v_space,
    'Test cash',
    1000,
    v_as_of,
    'Test bank',
    'checking',
    true
  );

  v_benefit_account := public.onboarding_create_account(
    v_space,
    'Test benefit',
    500,
    v_as_of,
    'Test benefit provider',
    'benefit',
    false
  );

  perform public.set_budget_limit(
    v_space,
    date_trunc('month', v_as_of)::date,
    v_expense_category,
    600,
    'month'
  );

  insert into public.recurring_items(
    space_id,
    name,
    item_type,
    amount,
    frequency,
    weekday,
    account_id,
    starts_on,
    ends_on,
    certainty,
    active
  )
  values(
    v_space,
    'Test next income',
    'income',
    2000,
    'weekly',
    extract(dow from v_income_date)::int,
    v_cash_account,
    v_income_date,
    v_income_date,
    'confirmed',
    true
  );

  select coalesce(sum(fi.amount), 0)
    into v_benefit_before
  from public.financial_impacts fi
  where fi.space_id = v_space
    and fi.account_id = v_benefit_account
    and fi.dimension = 'benefit'
    and fi.effective_date <= v_as_of;

  select liquid_balance,
         cash_headroom,
         monthly_budget_used,
         economic_headroom,
         spendable_pool,
         daily_folego
    into v_liquid_before,
         v_cash_headroom_before,
         v_budget_used_before,
         v_economic_before,
         v_spendable_before,
         v_daily_before
  from public.get_folego_snapshot(v_space, v_as_of);

  if v_benefit_before <> 500 then
    raise exception 'test_initial_benefit_balance_failed: %', v_benefit_before;
  end if;

  if v_liquid_before <> 1000
     or v_cash_headroom_before <> 1000
     or v_budget_used_before <> 0
     or v_economic_before <> 600
     or v_spendable_before <> 600
     or v_daily_before <> 60 then
    raise exception 'test_initial_snapshot_failed: liquid %, cash %, budget %, economic %, spendable %, daily %',
      v_liquid_before,
      v_cash_headroom_before,
      v_budget_used_before,
      v_economic_before,
      v_spendable_before,
      v_daily_before;
  end if;

  perform public.register_benefit(
    v_space,
    v_benefit_account,
    80,
    'Benefit lunch test',
    false,
    v_expense_category
  );

  select coalesce(sum(fi.amount), 0)
    into v_benefit_after
  from public.financial_impacts fi
  where fi.space_id = v_space
    and fi.account_id = v_benefit_account
    and fi.dimension = 'benefit'
    and fi.effective_date <= v_as_of;

  select liquid_balance,
         cash_headroom,
         monthly_budget_used,
         economic_headroom,
         spendable_pool,
         daily_folego
    into v_liquid_after_benefit,
         v_cash_headroom_after_benefit,
         v_budget_used_after_benefit,
         v_economic_after_benefit,
         v_spendable_after_benefit,
         v_daily_after_benefit
  from public.get_folego_snapshot(v_space, v_as_of);

  if v_benefit_after <> 420 then
    raise exception 'test_benefit_balance_not_reduced: before %, after %', v_benefit_before, v_benefit_after;
  end if;

  if v_liquid_after_benefit <> v_liquid_before then
    raise exception 'test_benefit_changed_liquid_balance: before %, after %', v_liquid_before, v_liquid_after_benefit;
  end if;

  if v_cash_headroom_after_benefit <> v_cash_headroom_before then
    raise exception 'test_benefit_changed_cash_headroom: before %, after %', v_cash_headroom_before, v_cash_headroom_after_benefit;
  end if;

  if v_budget_used_after_benefit <> v_budget_used_before then
    raise exception 'test_benefit_changed_folego_budget_used: before %, after %', v_budget_used_before, v_budget_used_after_benefit;
  end if;

  if v_economic_after_benefit <> v_economic_before then
    raise exception 'test_benefit_changed_economic_headroom: before %, after %', v_economic_before, v_economic_after_benefit;
  end if;

  if v_spendable_after_benefit <> v_spendable_before then
    raise exception 'test_benefit_changed_spendable_pool: before %, after %', v_spendable_before, v_spendable_after_benefit;
  end if;

  if v_daily_after_benefit <> v_daily_before then
    raise exception 'test_benefit_changed_daily_folego: before %, after %', v_daily_before, v_daily_after_benefit;
  end if;

  if not exists (
    select 1
    from public.financial_impacts fi
    join public.financial_events fe on fe.id = fi.event_id and fe.space_id = fi.space_id
    where fi.space_id = v_space
      and fe.event_type = 'benefit_expense'
      and fi.dimension = 'budget'
      and fi.amount = -80
  ) then
    raise exception 'test_benefit_budget_ledger_dimension_missing';
  end if;

  perform public.register_expense(
    v_space,
    v_cash_account,
    80,
    'Equivalent cash lunch test',
    v_expense_category,
    now(),
    v_as_of,
    'manual',
    null
  );

  select liquid_balance,
         cash_headroom,
         monthly_budget_used,
         economic_headroom,
         spendable_pool,
         daily_folego
    into v_liquid_after_cash,
         v_cash_headroom_after_cash,
         v_budget_used_after_cash,
         v_economic_after_cash,
         v_spendable_after_cash,
         v_daily_after_cash
  from public.get_folego_snapshot(v_space, v_as_of);

  if v_liquid_after_cash <> 920
     or v_cash_headroom_after_cash <> 920
     or v_budget_used_after_cash <> 80
     or v_economic_after_cash <> 520
     or v_spendable_after_cash <> 520
     or v_daily_after_cash <> 52 then
    raise exception 'test_cash_expense_projection_failed: liquid %, cash %, budget %, economic %, spendable %, daily %',
      v_liquid_after_cash,
      v_cash_headroom_after_cash,
      v_budget_used_after_cash,
      v_economic_after_cash,
      v_spendable_after_cash,
      v_daily_after_cash;
  end if;

  raise notice 'benefit projection audit: benefit % -> %, liquid % -> %, cash % -> %, budget_used % -> %, economic % -> %, spendable % -> %, daily % -> %',
    v_benefit_before,
    v_benefit_after,
    v_liquid_before,
    v_liquid_after_benefit,
    v_cash_headroom_before,
    v_cash_headroom_after_benefit,
    v_budget_used_before,
    v_budget_used_after_benefit,
    v_economic_before,
    v_economic_after_benefit,
    v_spendable_before,
    v_spendable_after_benefit,
    v_daily_before,
    v_daily_after_benefit;

  raise notice 'cash control audit: liquid %, cash %, budget_used %, economic %, spendable %, daily %',
    v_liquid_after_cash,
    v_cash_headroom_after_cash,
    v_budget_used_after_cash,
    v_economic_after_cash,
    v_spendable_after_cash,
    v_daily_after_cash;
end;
$test$;

rollback;

select 'ok' as benefit_spendable_pool_projection_tests;
