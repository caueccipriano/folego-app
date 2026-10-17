-- ProjectionEngine regression tests.
-- Includes fixtures mirrored from "Controle Financeiro 2026" > Projeção.
-- Everything runs inside a transaction and is rolled back.

begin;

do $test$
declare
  v_user uuid;
  v_space uuid := gen_random_uuid();
  v_account uuid := gen_random_uuid();
  v_space_sheet uuid := gen_random_uuid();
  v_account_sheet uuid := gen_random_uuid();
  v_space_budget uuid := gen_random_uuid();
  v_budget_parent uuid := gen_random_uuid();
  v_budget_child uuid := gen_random_uuid();
  v_space_future uuid := gen_random_uuid();
  v_account_future uuid := gen_random_uuid();
  v_protected_future uuid := gen_random_uuid();
  v_future_parent uuid := gen_random_uuid();
  v_future_child uuid := gen_random_uuid();
  v_card uuid := gen_random_uuid();
  v_invoice uuid := gen_random_uuid();
  v_parent_category uuid := gen_random_uuid();
  v_child_category uuid := gen_random_uuid();
  v_recurring_date date;
  v_recurring_cash_month date;
  v_third jsonb;
  v_event uuid := gen_random_uuid();
  v_purchase uuid := gen_random_uuid();
  v_today date := (now() at time zone 'America/Sao_Paulo')::date;
  v_next_month date := (date_trunc('month', v_today) + interval '1 month')::date;
  v_next_due date;
  v_future_date date;
  v_before_events bigint;
  v_after_events bigint;
  v_before_impacts bigint;
  v_after_impacts bigint;
  v_projection jsonb;
  v_months jsonb;
  v_first jsonb;
  v_second jsonb;
  v_next jsonb;
begin
  select owner_id into v_user
  from public.financial_spaces
  order by created_at
  limit 1;

  if v_user is null then
    raise exception 'projection_test_requires_existing_user';
  end if;

  perform set_config('request.jwt.claim.sub', v_user::text, true);

  -- Fixture A: generic arithmetic + scenario immutability.
  insert into public.financial_spaces(id, owner_id, name, type, currency, timezone)
  values(v_space, v_user, 'Projection test', 'personal', 'BRL', 'America/Sao_Paulo');

  insert into public.space_members(space_id, user_id, role)
  values(v_space, v_user, 'owner');

  insert into public.accounts(
    id, space_id, name, type, available_for_spending, active
  ) values(
    v_account, v_space, 'Conta teste', 'checking', true, true
  );

  insert into public.financial_events(
    id, space_id, event_type, description, amount, currency,
    occurred_at, competence_date, status, source
  ) values(
    gen_random_uuid(), v_space, 'opening_balance', 'Saldo inicial', 1000, 'BRL',
    v_today::timestamptz, v_today, 'confirmed', 'test'
  ) returning id into v_event;

  insert into public.financial_impacts(
    event_id, space_id, dimension, amount, account_id, effective_date
  ) values(v_event, v_space, 'cash', 1000, v_account, v_today);

  select count(*) into v_before_events
  from public.financial_events where space_id = v_space;
  select count(*) into v_before_impacts
  from public.financial_impacts where space_id = v_space;

  select public.get_projection(
    v_space,
    3,
    jsonb_build_array(
      jsonb_build_object(
        'id','income-fixture',
        'name','Receita fixture',
        'component','income',
        'amount_delta',5000,
        'frequency','once',
        'starts_on',v_today
      ),
      jsonb_build_object(
        'id','expense-fixture',
        'name','Despesa fixture',
        'component','direct_expense',
        'amount_delta',4000,
        'frequency','once',
        'starts_on',v_today
      )
    ),
    '{}'::text[]
  ) into v_projection;

  v_first := (v_projection -> 'months') -> 0;

  if round((v_first ->> 'opening_balance')::numeric, 2) <> 1000 then
    raise exception 'projection_opening_balance_wrong: %', v_first ->> 'opening_balance';
  end if;

  if round((v_first ->> 'closing_balance')::numeric, 2) <> 2000 then
    raise exception 'projection_1000_plus_5000_minus_4000_wrong: %',
      v_first ->> 'closing_balance';
  end if;

  select count(*) into v_after_events
  from public.financial_events where space_id = v_space;
  select count(*) into v_after_impacts
  from public.financial_impacts where space_id = v_space;

  if v_after_events <> v_before_events or v_after_impacts <> v_before_impacts then
    raise exception 'simulation_created_financial_ledger_rows';
  end if;

  if (
    select coalesce(sum(fi.amount),0)
    from public.financial_impacts fi
    where fi.space_id = v_space
      and fi.dimension = 'cash'
      and fi.account_id = v_account
  ) <> 1000 then
    raise exception 'simulation_changed_real_account_balance';
  end if;

  -- Fixture B: spreadsheet "Projeção" chaining.
  -- Planilha fixture: 4,900 income - 4,096.76 expenses - 735 reserve
  -- = 68.24 in month 1; the next month opens at 68.24 and closes at 136.48.
  insert into public.financial_spaces(id, owner_id, name, type, currency, timezone)
  values(v_space_sheet, v_user, 'Projection spreadsheet fixture', 'personal', 'BRL', 'America/Sao_Paulo');

  insert into public.space_members(space_id, user_id, role)
  values(v_space_sheet, v_user, 'owner');

  insert into public.accounts(
    id, space_id, name, type, available_for_spending, active
  ) values(
    v_account_sheet, v_space_sheet, 'Conta planilha', 'checking', true, true
  );

  select public.get_projection(
    v_space_sheet,
    3,
    jsonb_build_array(
      jsonb_build_object(
        'id','sheet-income',
        'name','Renda base',
        'component','income',
        'amount_delta',4900,
        'frequency','monthly',
        'starts_on',v_today,
        'ends_on',(v_today + interval '2 months')::date
      ),
      jsonb_build_object(
        'id','sheet-budget',
        'name','Orçamento categorias',
        'component','direct_expense',
        'amount_delta',4096.76,
        'frequency','monthly',
        'starts_on',v_today,
        'ends_on',(v_today + interval '2 months')::date
      ),
      jsonb_build_object(
        'id','sheet-reserve',
        'name','Aporte reserva',
        'component','reserve',
        'amount_delta',735,
        'frequency','monthly',
        'starts_on',v_today,
        'ends_on',(v_today + interval '2 months')::date
      )
    ),
    '{}'::text[]
  ) into v_projection;

  v_months := v_projection -> 'months';
  v_first := v_months -> 0;
  v_second := v_months -> 1;

  if round((v_first ->> 'closing_balance')::numeric, 2) <> 68.24 then
    raise exception 'spreadsheet_fixture_month1_wrong: %', v_first ->> 'closing_balance';
  end if;

  if round((v_second ->> 'opening_balance')::numeric, 2) <> 68.24 then
    raise exception 'spreadsheet_fixture_chaining_wrong: %', v_second ->> 'opening_balance';
  end if;

  if round((v_second ->> 'closing_balance')::numeric, 2) <> 136.48 then
    raise exception 'spreadsheet_fixture_month2_wrong: %', v_second ->> 'closing_balance';
  end if;

  -- Fixture C: existing future card installment enters only its due month,
  -- is not double-counted with its budget, and card-backed recurrences use
  -- the same closing/due cycle as a real card purchase.
  insert into public.categories(
    id, space_id, name, kind, parent_id, active, category_role, is_selectable
  ) values
    (
      v_parent_category, v_space, 'Compras projeção', 'expense',
      null, true, 'group', false
    ),
    (
      v_child_category, v_space, 'Categoria projeção', 'expense',
      v_parent_category, true, 'economic', true
    );

  insert into public.credit_cards(
    id, space_id, name, closing_day, due_day, payment_account_id, active
  ) values(
    v_card, v_space, 'Cartão projeção', 10, 20, v_account, true
  );

  insert into public.financial_events(
    id, space_id, event_type, description, amount, currency,
    occurred_at, competence_date, category_id, status, source
  ) values(
    gen_random_uuid(), v_space, 'card_purchase', 'Compra 6x', 897.84, 'BRL',
    v_today::timestamptz, v_today, v_child_category, 'confirmed', 'test'
  ) returning id into v_event;

  insert into public.card_purchases(
    id, space_id, card_id, event_id, description, total_amount,
    installments_count, purchase_at, category_id, status
  ) values(
    v_purchase, v_space, v_card, v_event, 'Compra 6x', 897.84,
    6, v_today::timestamptz, v_child_category, 'confirmed'
  );

  v_next_due := make_date(
    extract(year from v_next_month)::int,
    extract(month from v_next_month)::int,
    20
  );

  insert into public.card_invoices(
    id, space_id, card_id, reference_month, closing_date, due_date,
    opening_balance, status
  ) values(
    v_invoice, v_space, v_card, v_next_month,
    (v_next_month + interval '1 month - 1 day')::date,
    v_next_due, 0, 'open'
  );

  insert into public.card_installments(
    id, space_id, purchase_id, invoice_id, installment_number,
    total_installments, amount, competence_date, status
  ) values(
    gen_random_uuid(), v_space, v_purchase, v_invoice, 1,
    6, 149.64, v_next_month, 'invoiced'
  );

  insert into public.financial_impacts(
    event_id, space_id, dimension, amount, category_id, effective_date
  ) values(
    v_event, v_space, 'budget', -149.64, v_child_category, v_next_month
  );

  insert into public.budget_recurring_rules(
    space_id, category_id, planned_amount, effective_from
  ) values(
    v_space, v_child_category, 500, v_next_month
  );

  -- Occurs on day 16 after a day-10 close, therefore it belongs to the
  -- following cycle and is paid on day 20 of the month after v_next_month.
  v_recurring_date := (v_next_month + interval '15 days')::date;
  v_recurring_cash_month :=
    (date_trunc('month', v_recurring_date) + interval '1 month')::date;

  insert into public.recurring_items(
    space_id, name, item_type, amount, frequency, monthly_days,
    category_id, card_id, starts_on, ends_on, certainty, active,
    recurrence_kind
  ) values(
    v_space, 'Assinatura no cartão', 'expense', 99, 'monthly',
    array[16]::integer[], v_child_category, v_card,
    v_recurring_date, v_recurring_date, 'confirmed', true, 'subscription'
  );

  select public.get_projection(v_space, 3, '[]'::jsonb, '{}'::text[])
    into v_projection;

  v_first := (v_projection -> 'months') -> 0;
  v_next := (v_projection -> 'months') -> 1;
  v_third := (v_projection -> 'months') -> 2;

  if round((v_first ->> 'card_installments')::numeric, 2) <> 0 then
    raise exception 'future_installment_leaked_into_current_month: %',
      v_first ->> 'card_installments';
  end if;

  if round((v_next ->> 'card_installments')::numeric, 2) <> 149.64 then
    raise exception 'future_installment_missing_in_correct_month: %',
      v_next ->> 'card_installments';
  end if;

  if round((v_next ->> 'direct_expenses')::numeric, 2) <> 350.36 then
    raise exception 'known_installment_double_counted_with_budget: %',
      v_next ->> 'direct_expenses';
  end if;

  if round(
    (v_next ->> 'direct_expenses')::numeric
    + (v_next ->> 'card_installments')::numeric,
    2
  ) <> 500 then
    raise exception 'budget_plus_known_card_should_equal_budget: direct %, card %',
      v_next ->> 'direct_expenses',
      v_next ->> 'card_installments';
  end if;

  if date_trunc('month', (v_third ->> 'month')::date)::date
      <> v_recurring_cash_month then
    raise exception 'recurring_card_fixture_month_mismatch';
  end if;

  if round((v_third ->> 'card_installments')::numeric, 2) <> 99 then
    raise exception 'card_recurring_not_routed_to_invoice_month: %',
      v_third ->> 'card_installments';
  end if;

  if round((v_third ->> 'direct_expenses')::numeric, 2) <> 401 then
    raise exception 'card_recurring_not_offset_from_budget: %',
      v_third ->> 'direct_expenses';
  end if;

  if round(
    (v_third ->> 'direct_expenses')::numeric
    + (v_third ->> 'card_installments')::numeric,
    2
  ) <> 500 then
    raise exception 'budget_plus_card_recurring_should_equal_budget';
  end if;

  -- Fixture D: budget-only planning must produce a real projection even when
  -- there are no recurring items, cards, debts or persisted planning items.
  insert into public.financial_spaces(id, owner_id, name, type, currency, timezone)
  values(v_space_budget, v_user, 'Projection budget-only fixture', 'personal', 'BRL', 'America/Sao_Paulo');

  insert into public.space_members(space_id, user_id, role)
  values(v_space_budget, v_user, 'owner');

  insert into public.categories(
    id, space_id, name, kind, parent_id, active, category_role, is_selectable
  ) values
    (
      v_budget_parent, v_space_budget, 'Budget-only parent', 'expense',
      null, true, 'group', false
    ),
    (
      v_budget_child, v_space_budget, 'Budget-only child', 'expense',
      v_budget_parent, true, 'economic', true
    );

  insert into public.budget_recurring_rules(
    space_id, category_id, planned_amount, effective_from
  ) values(
    v_space_budget,
    v_budget_child,
    300,
    date_trunc('month', v_today)::date
  );

  select public.get_projection(v_space_budget, 3, '[]'::jsonb, '{}'::text[])
    into v_projection;

  v_first := (v_projection -> 'months') -> 0;
  v_second := (v_projection -> 'months') -> 1;

  if coalesce((v_projection ->> 'has_projection_inputs')::boolean, false) is not true then
    raise exception 'budget_only_projection_not_recognized_as_input';
  end if;

  if round((v_first ->> 'direct_expenses')::numeric, 2) <> 300 then
    raise exception 'budget_only_current_month_wrong: %', v_first ->> 'direct_expenses';
  end if;

  if round((v_second ->> 'opening_balance')::numeric, 2)
      <> round((v_first ->> 'closing_balance')::numeric, 2) then
    raise exception 'budget_only_month_chaining_wrong';
  end if;

  -- Fixture E: future confirmed cash movements must be projected from the
  -- canonical ledger. Transfers from a spendable account into a protected
  -- account count as reserve transfers, while account-to-account movement
  -- inside the spendable pool would net to zero.
  insert into public.financial_spaces(id, owner_id, name, type, currency, timezone)
  values(v_space_future, v_user, 'Projection future movement fixture', 'personal', 'BRL', 'America/Sao_Paulo');

  insert into public.space_members(space_id, user_id, role)
  values(v_space_future, v_user, 'owner');

  insert into public.accounts(
    id, space_id, name, type, available_for_spending, active
  ) values
    (v_account_future, v_space_future, 'Conta futura', 'checking', true, true),
    (v_protected_future, v_space_future, 'Reserva futura', 'savings', false, true);

  insert into public.categories(
    id, space_id, name, kind, parent_id, active, category_role, is_selectable
  ) values
    (
      v_future_parent, v_space_future, 'Future parent', 'expense',
      null, true, 'group', false
    ),
    (
      v_future_child, v_space_future, 'Future expense', 'expense',
      v_future_parent, true, 'economic', true
    );

  insert into public.financial_events(
    id, space_id, event_type, description, amount, currency,
    occurred_at, competence_date, status, source
  ) values(
    gen_random_uuid(), v_space_future, 'opening_balance', 'Future opening', 1000, 'BRL',
    v_today::timestamptz, v_today, 'confirmed', 'test'
  ) returning id into v_event;

  insert into public.financial_impacts(
    event_id, space_id, dimension, amount, account_id, effective_date
  ) values(v_event, v_space_future, 'cash', 1000, v_account_future, v_today);

  v_future_date := (date_trunc('month', v_today) + interval '1 month + 5 days')::date;

  insert into public.financial_events(
    id, space_id, event_type, description, amount, currency,
    occurred_at, competence_date, status, source
  ) values(
    gen_random_uuid(), v_space_future, 'income', 'Future income', 500, 'BRL',
    v_future_date::timestamptz, v_future_date, 'confirmed', 'test'
  ) returning id into v_event;

  insert into public.financial_impacts(
    event_id, space_id, dimension, amount, account_id, effective_date
  ) values(v_event, v_space_future, 'cash', 500, v_account_future, v_future_date);

  insert into public.financial_events(
    id, space_id, event_type, description, amount, currency,
    occurred_at, competence_date, category_id, status, source
  ) values(
    gen_random_uuid(), v_space_future, 'expense', 'Future expense', 120, 'BRL',
    v_future_date::timestamptz, v_future_date, v_future_child, 'confirmed', 'test'
  ) returning id into v_event;

  insert into public.financial_impacts(
    event_id, space_id, dimension, amount, account_id, category_id, effective_date
  ) values
    (v_event, v_space_future, 'cash', -120, v_account_future, null, v_future_date),
    (v_event, v_space_future, 'economic', -120, null, v_future_child, v_future_date),
    (v_event, v_space_future, 'budget', -120, null, v_future_child, v_future_date);

  insert into public.financial_events(
    id, space_id, event_type, description, amount, currency,
    occurred_at, competence_date, status, source, metadata
  ) values(
    gen_random_uuid(), v_space_future, 'transfer', 'Future reserve transfer', 200, 'BRL',
    v_future_date::timestamptz, v_future_date, 'confirmed', 'test',
    jsonb_build_object('from_account_id', v_account_future, 'to_account_id', v_protected_future)
  ) returning id into v_event;

  insert into public.financial_impacts(
    event_id, space_id, dimension, amount, account_id, effective_date
  ) values
    (v_event, v_space_future, 'cash', -200, v_account_future, v_future_date),
    (v_event, v_space_future, 'cash', 200, v_protected_future, v_future_date);

  select public.get_projection(v_space_future, 3, '[]'::jsonb, '{}'::text[])
    into v_projection;

  v_first := (v_projection -> 'months') -> 0;
  v_next := (v_projection -> 'months') -> 1;

  if round((v_first ->> 'closing_balance')::numeric, 2) <> 1000 then
    raise exception 'future_movements_leaked_into_current_balance: %',
      v_first ->> 'closing_balance';
  end if;

  if round((v_next ->> 'opening_balance')::numeric, 2) <> 1000 then
    raise exception 'future_movements_next_month_opening_wrong: %',
      v_next ->> 'opening_balance';
  end if;

  if round((v_next ->> 'guaranteed_income')::numeric, 2) <> 500 then
    raise exception 'future_income_missing: %', v_next ->> 'guaranteed_income';
  end if;

  if round((v_next ->> 'direct_expenses')::numeric, 2) <> 120 then
    raise exception 'future_expense_missing: %', v_next ->> 'direct_expenses';
  end if;

  if round((v_next ->> 'reserve_transfers')::numeric, 2) <> 200 then
    raise exception 'future_reserve_transfer_missing: %', v_next ->> 'reserve_transfers';
  end if;

  if round((v_next ->> 'closing_balance')::numeric, 2) <> 1180 then
    raise exception 'future_movements_closing_wrong: %', v_next ->> 'closing_balance';
  end if;

end;
$test$;

rollback;

select 'ok' as projection_engine_tests;
