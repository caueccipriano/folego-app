-- Integration regression tests for update_simple_transaction vs benefit accounts.
-- The entire test runs inside a transaction and rolls back all created data.

begin;

do $test$
declare
  v_user uuid;
  v_space uuid := gen_random_uuid();
  v_checking_a uuid := gen_random_uuid();
  v_checking_b uuid := gen_random_uuid();
  v_benefit uuid := gen_random_uuid();
  v_income_category_a uuid := gen_random_uuid();
  v_income_category_b uuid := gen_random_uuid();
  v_expense_category uuid := gen_random_uuid();
  v_income_move uuid;
  v_income_guard uuid;
  v_income_edit uuid;
  v_expense_guard uuid;
  v_original_description text;
  v_original_amount numeric;
  v_original_occurred_at timestamptz;
  v_original_competence date;
  v_original_category uuid;
  v_original_source text;
  v_original_status text;
  v_count integer;
  v_edit_date date := current_date - 3;
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
  values(v_space, v_user, 'Simple transaction benefit guard test', 'personal', 'BRL', 'America/Sao_Paulo');

  insert into public.space_members(space_id, user_id, role)
  values(v_space, v_user, 'owner');

  insert into public.categories(id, space_id, name, kind, essential, active)
  values
    (v_income_category_a, v_space, 'Income A', 'income', false, true),
    (v_income_category_b, v_space, 'Income B', 'income', false, true),
    (v_expense_category, v_space, 'Expense A', 'expense', false, true);

  insert into public.accounts(id, space_id, name, type, available_for_spending, active)
  values
    (v_checking_a, v_space, 'Checking A', 'checking', true, true),
    (v_checking_b, v_space, 'Checking B', 'checking', true, true),
    (v_benefit, v_space, 'Benefit', 'benefit', false, true);

  -- A. Income can move between normal checking accounts.
  v_income_move := public.register_income(
    v_space, v_checking_a, 100, 'Move income', v_income_category_a,
    now(), current_date, 'test', 'test:update-simple:move-income'
  );

  perform public.update_simple_transaction(
    v_space, v_income_move, v_checking_b, 100, 'Move income',
    v_income_category_a, now(), current_date
  );

  if not exists (
    select 1 from public.financial_impacts
    where event_id = v_income_move
      and space_id = v_space
      and dimension = 'cash'
      and account_id = v_checking_b
      and amount = 100
  ) then
    raise exception 'test_income_move_cash_failed';
  end if;

  if exists (
    select 1 from public.financial_impacts
    where event_id = v_income_move
      and space_id = v_space
      and dimension = 'cash'
      and account_id = v_checking_a
  ) then
    raise exception 'test_income_move_old_cash_remained';
  end if;

  if not exists (
    select 1 from public.financial_impacts
    where event_id = v_income_move
      and space_id = v_space
      and dimension = 'economic'
      and category_id = v_income_category_a
      and amount = 100
  ) then
    raise exception 'test_income_move_economic_failed';
  end if;

  -- B/C/D. Income -> benefit must fail before mutating event or impacts.
  v_income_guard := public.register_income(
    v_space, v_checking_a, 90, 'Original guarded income', v_income_category_a,
    now() - interval '2 days', current_date - 2, 'test-guard', 'test:update-simple:guard-income'
  );

  select description, amount, occurred_at, competence_date, category_id, source, status
    into v_original_description, v_original_amount, v_original_occurred_at,
         v_original_competence, v_original_category, v_original_source, v_original_status
  from public.financial_events
  where id = v_income_guard and space_id = v_space;

  begin
    perform public.update_simple_transaction(
      v_space, v_income_guard, v_benefit, 999, 'Should not persist',
      v_income_category_b, now(), current_date
    );
    raise exception 'test_income_to_benefit_was_accepted';
  exception
    when others then
      if sqlerrm = 'test_income_to_benefit_was_accepted' then
        raise;
      end if;
      if position('benefit_account_requires_benefit_operation' in sqlerrm) = 0 then
        raise exception 'test_income_to_benefit_wrong_error: %', sqlerrm;
      end if;
  end;

  if not exists (
    select 1 from public.financial_events
    where id = v_income_guard
      and space_id = v_space
      and description = v_original_description
      and amount = v_original_amount
      and occurred_at = v_original_occurred_at
      and competence_date = v_original_competence
      and category_id = v_original_category
      and source = v_original_source
      and status = v_original_status
  ) then
    raise exception 'test_failed_edit_mutated_original_event';
  end if;

  select count(*) into v_count
  from public.financial_impacts
  where event_id = v_income_guard and space_id = v_space;

  if v_count <> 2 then
    raise exception 'test_failed_edit_changed_impact_count: %', v_count;
  end if;

  if not exists (
    select 1 from public.financial_impacts
    where event_id = v_income_guard
      and space_id = v_space
      and dimension = 'cash'
      and account_id = v_checking_a
      and amount = 90
  ) then
    raise exception 'test_failed_edit_changed_cash_impact';
  end if;

  if not exists (
    select 1 from public.financial_impacts
    where event_id = v_income_guard
      and space_id = v_space
      and dimension = 'economic'
      and category_id = v_income_category_a
      and amount = 90
  ) then
    raise exception 'test_failed_edit_changed_economic_impact';
  end if;

  -- E. Expense -> benefit remains rejected.
  v_expense_guard := public.register_expense(
    v_space, v_checking_a, 80, 'Guarded expense', v_expense_category,
    now(), current_date, 'test', 'test:update-simple:guard-expense'
  );

  begin
    perform public.update_simple_transaction(
      v_space, v_expense_guard, v_benefit, 80, 'Guarded expense',
      v_expense_category, now(), current_date
    );
    raise exception 'test_expense_to_benefit_was_accepted';
  exception
    when others then
      if sqlerrm = 'test_expense_to_benefit_was_accepted' then
        raise;
      end if;
      if position('benefit_account_requires_benefit_operation' in sqlerrm) = 0 then
        raise exception 'test_expense_to_benefit_wrong_error: %', sqlerrm;
      end if;
  end;

  if not exists (
    select 1 from public.financial_impacts
    where event_id = v_expense_guard
      and space_id = v_space
      and dimension = 'cash'
      and account_id = v_checking_a
      and amount = -80
  ) then
    raise exception 'test_expense_guard_regression_failed';
  end if;

  -- F. Valid income edits of description/value/category/date continue to work.
  v_income_edit := public.register_income(
    v_space, v_checking_a, 50, 'Before edit', v_income_category_a,
    now(), current_date, 'preserve-source', 'test:update-simple:valid-edit'
  );

  perform public.update_simple_transaction(
    v_space, v_income_edit, v_checking_a, 125.55, 'After edit',
    v_income_category_b, v_edit_date::timestamp, v_edit_date
  );

  if not exists (
    select 1 from public.financial_events
    where id = v_income_edit
      and space_id = v_space
      and description = 'After edit'
      and amount = 125.55
      and competence_date = v_edit_date
      and category_id = v_income_category_b
      and source = 'preserve-source'
      and status = 'confirmed'
  ) then
    raise exception 'test_valid_income_event_edit_failed';
  end if;

  if not exists (
    select 1 from public.financial_impacts
    where event_id = v_income_edit
      and space_id = v_space
      and dimension = 'cash'
      and account_id = v_checking_a
      and amount = 125.55
      and effective_date = v_edit_date
  ) then
    raise exception 'test_valid_income_cash_edit_failed';
  end if;

  if not exists (
    select 1 from public.financial_impacts
    where event_id = v_income_edit
      and space_id = v_space
      and dimension = 'economic'
      and category_id = v_income_category_b
      and amount = 125.55
      and effective_date = v_edit_date
  ) then
    raise exception 'test_valid_income_economic_edit_failed';
  end if;

  -- G. update_simple_transaction never creates benefit impacts for these simple events.
  if exists (
    select 1
    from public.financial_impacts fi
    where fi.space_id = v_space
      and fi.event_id in (v_income_move, v_income_guard, v_income_edit, v_expense_guard)
      and fi.dimension = 'benefit'
  ) then
    raise exception 'test_simple_update_created_benefit_impact';
  end if;
end;
$test$;

rollback;

select 'ok' as protect_simple_transaction_updates_from_benefit_accounts_tests;
