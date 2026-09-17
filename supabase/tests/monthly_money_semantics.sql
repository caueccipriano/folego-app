-- Regression tests for Monthly Money Semantics + Home Spending Breakdown 1.0.
-- Fixtures are isolated in a transaction and rolled back.

begin;

do $test$
declare
  v_user uuid;
  v_space uuid := gen_random_uuid();
  v_account_a uuid := gen_random_uuid();
  v_account_b uuid := gen_random_uuid();
  v_investment uuid := gen_random_uuid();
  v_benefit_account uuid := gen_random_uuid();
  v_expense_category uuid := gen_random_uuid();
  v_income_category uuid := gen_random_uuid();
  v_card uuid := gen_random_uuid();

  v_transfer uuid := gen_random_uuid();
  v_card_payment uuid := gen_random_uuid();
  v_refund uuid := gen_random_uuid();
  v_reserve uuid := gen_random_uuid();
  v_opening uuid := gen_random_uuid();
  v_adjustment uuid := gen_random_uuid();

  v_purchase uuid;
  v_purchase_event uuid;
  v_benefit_event uuid;

  v_summary record;
  v_october record;
  v_month record;
  v_expected numeric;
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
  values(v_space, v_user, 'Monthly money semantics test', 'personal', 'BRL', 'America/Sao_Paulo');

  insert into public.space_members(space_id, user_id, role)
  values(v_space, v_user, 'owner');

  insert into public.accounts(id, space_id, name, type, available_for_spending, active) values
    (v_account_a, v_space, 'Conta A', 'checking', true, true),
    (v_account_b, v_space, 'Conta B', 'checking', true, true),
    (v_investment, v_space, 'Reserva', 'investment', false, true),
    (v_benefit_account, v_space, 'Benefício', 'benefit', false, true);

  insert into public.categories(id, space_id, name, kind, active) values
    (v_expense_category, v_space, 'Compras teste', 'expense', true),
    (v_income_category, v_space, 'Salário teste', 'income', true);

  insert into public.credit_cards(
    id, space_id, name, closing_day, due_day, payment_account_id, active
  ) values(
    v_card, v_space, 'Cartão teste', 5, 12, v_account_a, true
  );

  -- Real economic income.
  perform public.register_income(
    v_space, v_account_a, 2000, 'Salário',
    v_income_category, '2026-09-02 09:00:00-03'::timestamptz,
    '2026-09-02'::date, 'app', null
  );

  -- Direct account expense.
  perform public.register_expense(
    v_space, v_account_a, 100, 'Despesa direta',
    v_expense_category, '2026-09-03 10:00:00-03'::timestamptz,
    '2026-09-03'::date, 'app', null
  );

  -- 1. Own-account transfer: cash moves, economic income/expense stay zero.
  insert into public.financial_events(
    id, space_id, event_type, description, amount, currency,
    occurred_at, competence_date, status, source, metadata
  ) values(
    v_transfer, v_space, 'transfer', 'Conta A -> Conta B', 50, 'BRL',
    '2026-09-04 10:00:00-03', '2026-09-04', 'confirmed', 'app',
    jsonb_build_object('from_account_id', v_account_a, 'to_account_id', v_account_b)
  );
  insert into public.financial_impacts(
    event_id, space_id, dimension, amount, account_id, effective_date
  ) values
    (v_transfer, v_space, 'cash', -50, v_account_a, '2026-09-04'),
    (v_transfer, v_space, 'cash', 50, v_account_b, '2026-09-04');

  -- 2. Card payment: cash out only; never a new economic expense.
  insert into public.financial_events(
    id, space_id, event_type, description, amount, currency,
    occurred_at, competence_date, status, source
  ) values(
    v_card_payment, v_space, 'card_payment', 'Pagamento de fatura', 200, 'BRL',
    '2026-09-05 10:00:00-03', '2026-09-05', 'confirmed', 'app'
  );
  insert into public.financial_impacts(
    event_id, space_id, dimension, amount, account_id, effective_date
  ) values(
    v_card_payment, v_space, 'cash', -200, v_account_a, '2026-09-05'
  );

  -- 3. Purchase of 897.84 in 6 installments, made in September after closing.
  -- The purchase belongs to "spending made" in September, but competence starts in October.
  v_purchase := public.register_card_purchase(
    v_space, v_card, 897.84, 'Compra 6x', 6, v_expense_category,
    '2026-09-16 12:00:00-03'::timestamptz, 'Loja teste', 'app', null
  );
  select event_id into v_purchase_event
  from public.card_purchases
  where id = v_purchase;

  -- 4. Refund: cash comes back and economic expense is reduced; it is not income.
  insert into public.financial_events(
    id, space_id, event_type, description, amount, currency,
    occurred_at, competence_date, category_id, status, source
  ) values(
    v_refund, v_space, 'refund', 'Reembolso', 32, 'BRL',
    '2026-09-17 10:00:00-03', '2026-09-17',
    v_expense_category, 'confirmed', 'app'
  );
  insert into public.financial_impacts(
    event_id, space_id, dimension, amount, account_id, category_id, effective_date
  ) values
    (v_refund, v_space, 'cash', 32, v_account_a, v_expense_category, '2026-09-17'),
    (v_refund, v_space, 'economic', 32, null, v_expense_category, '2026-09-17'),
    (v_refund, v_space, 'budget', 32, null, v_expense_category, '2026-09-17');

  -- 5. Benefit expense: economic spending without current-account cash.
  v_benefit_event := public.register_benefit_at(
    v_space, v_benefit_account, 40, 'Benefício',
    false, v_expense_category, '2026-09-18 10:00:00-03'::timestamptz
  );

  -- 6. Investment/reserve transfer: movement only.
  insert into public.financial_events(
    id, space_id, event_type, description, amount, currency,
    occurred_at, competence_date, status, source
  ) values(
    v_reserve, v_space, 'reserve_transfer', 'Aporte em reserva', 75, 'BRL',
    '2026-09-19 10:00:00-03', '2026-09-19', 'confirmed', 'app'
  );
  insert into public.financial_impacts(
    event_id, space_id, dimension, amount, account_id, effective_date
  ) values
    (v_reserve, v_space, 'cash', -75, v_account_a, '2026-09-19'),
    (v_reserve, v_space, 'protected', 75, v_investment, '2026-09-19');

  -- 7. Opening balance / reconciliation adjustment: neither income nor expense.
  insert into public.financial_events(
    id, space_id, event_type, description, amount, currency,
    occurred_at, competence_date, status, source
  ) values
    (v_opening, v_space, 'opening_balance', 'Saldo inicial', 500, 'BRL',
     '2026-09-01 08:00:00-03', '2026-09-01', 'confirmed', 'app'),
    (v_adjustment, v_space, 'adjustment', 'Conciliação', 25, 'BRL',
     '2026-09-20 08:00:00-03', '2026-09-20', 'confirmed', 'app');

  insert into public.financial_impacts(
    event_id, space_id, dimension, amount, account_id, effective_date
  ) values
    (v_opening, v_space, 'cash', 500, v_account_a, '2026-09-01'),
    (v_adjustment, v_space, 'cash', -25, v_account_a, '2026-09-20');

  select * into v_summary
  from public.get_monthly_money_summary(v_space, '2026-09-01');

  -- September spending made = direct + full card purchase + benefits - refunds.
  if v_summary.spending_account <> 100 then
    raise exception 'account_spending_wrong: %', v_summary.spending_account;
  end if;
  if v_summary.spending_cards <> 897.84 then
    raise exception 'card_spending_must_use_full_purchase: %', v_summary.spending_cards;
  end if;
  if v_summary.spending_benefits <> 40 then
    raise exception 'benefit_spending_missing: %', v_summary.spending_benefits;
  end if;
  if v_summary.refunds_amount <> 32 then
    raise exception 'refund_not_separated: %', v_summary.refunds_amount;
  end if;
  if v_summary.spending_net <> 1005.84 then
    raise exception 'september_spending_net_wrong: %', v_summary.spending_net;
  end if;

  -- Transfer, card payment, reserve, opening balance and adjustment did not become income/expense.
  if v_summary.income_amount <> 2000 then
    raise exception 'non_income_movement_leaked_into_income: %', v_summary.income_amount;
  end if;
  if v_summary.competence_net <> 108 then
    raise exception 'non_expense_movement_leaked_into_competence: %', v_summary.competence_net;
  end if;

  -- September competence for the card purchase is zero.
  if v_summary.competence_cards_total <> 0 then
    raise exception 'september_card_competence_should_be_zero: %', v_summary.competence_cards_total;
  end if;

  -- Refund adds cash, but does not add monthly income.
  if not exists(
    select 1 from public.financial_impacts
    where event_id = v_refund and dimension = 'cash' and amount = 32
  ) then
    raise exception 'refund_cash_not_positive';
  end if;

  -- Benefit never touches the checking-account cash dimension.
  if exists(
    select 1 from public.financial_impacts
    where event_id = v_benefit_event and dimension = 'cash'
  ) then
    raise exception 'benefit_reduced_current_account';
  end if;

  -- Card payment lowers cash only and is reported as movement, not spending.
  if v_summary.movement_card_payments <> 200 then
    raise exception 'card_payment_movement_wrong: %', v_summary.movement_card_payments;
  end if;
  if exists(
    select 1 from public.financial_impacts
    where event_id = v_card_payment and dimension = 'economic'
  ) then
    raise exception 'card_payment_created_economic_expense';
  end if;

  -- Own-account transfer is shown once as movement, without income/expense.
  if v_summary.movement_transfers <> 50 then
    raise exception 'transfer_movement_wrong: %', v_summary.movement_transfers;
  end if;

  -- Reserve movement is separate from spending/income.
  if v_summary.movement_reserve_investment <> 75 then
    raise exception 'reserve_movement_wrong: %', v_summary.movement_reserve_investment;
  end if;

  -- Opening balance and reconciliation are separate movements only.
  if v_summary.movement_reconciliation <> 525 then
    raise exception 'reconciliation_movement_wrong: %', v_summary.movement_reconciliation;
  end if;

  -- October through March each receives exactly one 149.64 installment.
  for v_month in
    select generate_series('2026-10-01'::date, '2027-03-01'::date, interval '1 month')::date as month_start
  loop
    select * into v_october
    from public.get_monthly_money_summary(v_space, v_month.month_start);

    v_expected := 149.64;
    if v_october.competence_cards_total <> v_expected then
      raise exception 'installment_competence_wrong_for_%: expected %, got %',
        v_month.month_start, v_expected, v_october.competence_cards_total;
    end if;
  end loop;

  if (
    select count(*)
    from public.financial_impacts
    where event_id = v_purchase_event
      and dimension = 'economic'
  ) <> 6 then
    raise exception 'card_purchase_impacts_were_duplicated_or_lost';
  end if;
end;
$test$;

rollback;

select 'ok' as monthly_money_semantics_tests;
