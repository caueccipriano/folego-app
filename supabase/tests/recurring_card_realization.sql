-- Regression tests for recurring card realization.
-- All fixtures are rolled back at the end.

begin;

do $test$
declare
  v_user uuid;
  v_space uuid := gen_random_uuid();
  v_account uuid := gen_random_uuid();
  v_card uuid := gen_random_uuid();
  v_bad_card uuid := gen_random_uuid();
  v_expense_category uuid := gen_random_uuid();
  v_income_category uuid := gen_random_uuid();
  v_rec_account uuid := gen_random_uuid();
  v_rec_income uuid := gen_random_uuid();
  v_rec_card uuid := gen_random_uuid();
  v_rec_bad uuid := gen_random_uuid();
  v_event uuid;
  v_event_again uuid;
  v_purchase uuid;
  v_manual_purchase uuid;
  v_manual_event uuid;
  v_invoice uuid;
  v_count integer;
  v_value numeric;
  v_manual_value numeric;
begin
  select owner_id into v_user
  from public.financial_spaces
  order by created_at
  limit 1;

  if v_user is null then
    raise exception 'test_setup_no_user';
  end if;

  perform set_config('request.jwt.claim.sub', v_user::text, true);

  insert into public.financial_spaces(
    id, owner_id, name, type, currency, timezone
  ) values (
    v_space, v_user, 'Recurring card test', 'personal', 'BRL',
    'America/Sao_Paulo'
  );

  insert into public.space_members(space_id, user_id, role)
  values(v_space, v_user, 'owner');

  insert into public.accounts(
    id, space_id, name, type, available_for_spending, active
  ) values (
    v_account, v_space, 'Checking', 'checking', true, true
  );

  insert into public.categories(
    id, space_id, name, kind, essential, active
  ) values
    (v_expense_category, v_space, 'Expense test', 'expense', false, true),
    (v_income_category, v_space, 'Income test', 'income', false, true);

  insert into public.credit_cards(
    id, space_id, name, closing_day, due_day, active
  ) values
    (v_card, v_space, 'Card', 20, 27, true),
    (v_bad_card, v_space, 'Bad Card', 20, 27, true);

  insert into public.recurring_items(
    id, space_id, name, item_type, amount, frequency, day_of_month,
    monthly_days, category_id, account_id, card_id, starts_on,
    certainty, active
  ) values
    (
      v_rec_account, v_space, 'Account recurring', 'expense', 30,
      'monthly', 15, array[15], v_expense_category, v_account, null,
      '2026-10-01', 'confirmed', true
    ),
    (
      v_rec_income, v_space, 'Income recurring', 'income', 100,
      'monthly', 15, array[15], v_income_category, v_account, null,
      '2026-10-01', 'confirmed', true
    ),
    (
      v_rec_card, v_space, 'Spotify', 'expense', 21.90,
      'monthly', 15, array[15], v_expense_category, null, v_card,
      '2026-10-01', 'confirmed', true
    ),
    (
      v_rec_bad, v_space, 'Failing card', 'expense', 10,
      'monthly', 15, array[15], v_expense_category, null, v_bad_card,
      '2026-10-01', 'confirmed', true
    );

  -- A. Account recurrence stays a normal expense.
  v_event := public.realize_recurring(
    v_space, v_rec_account, '2026-10-15', null
  );
  if not exists (
    select 1 from public.financial_events
    where id = v_event and event_type = 'expense'
  ) then
    raise exception 'account_recurring_changed';
  end if;

  -- B. Income recurrence stays an income.
  v_event := public.realize_recurring(
    v_space, v_rec_income, '2026-10-15', null
  );
  if not exists (
    select 1 from public.financial_events
    where id = v_event and event_type = 'income'
  ) then
    raise exception 'income_recurring_changed';
  end if;

  -- C. Card recurrence creates the canonical card purchase on due date.
  v_event := public.realize_recurring(
    v_space, v_rec_card, '2026-10-15', null
  );

  select id into v_purchase
  from public.card_purchases
  where space_id = v_space and event_id = v_event;

  if v_purchase is null then
    raise exception 'card_purchase_missing';
  end if;

  if not exists (
    select 1 from public.financial_events
    where id = v_event
      and event_type = 'card_purchase'
      and occurred_at::date = '2026-10-15'
      and amount = 21.90
  ) then
    raise exception 'card_event_invalid';
  end if;

  if not exists (
    select 1 from public.card_purchases
    where id = v_purchase
      and card_id = v_card
      and total_amount = 21.90
      and installments_count = 1
      and purchase_at::date = '2026-10-15'
      and category_id = v_expense_category
  ) then
    raise exception 'card_purchase_backing_invalid';
  end if;

  -- D/E. Card recurrence is 1x and uses the canonical invoice rules.
  select invoice_id into v_invoice
  from public.card_installments
  where purchase_id = v_purchase
    and installment_number = 1
    and total_installments = 1
    and amount = 21.90;

  if v_invoice is null then
    raise exception 'card_installment_missing';
  end if;

  if not exists (
    select 1 from public.card_invoices
    where id = v_invoice
      and card_id = v_card
      and closing_date = '2026-10-20'
      and due_date = '2026-10-27'
      and reference_month = '2026-10-01'
  ) then
    raise exception 'invoice_assignment_invalid';
  end if;

  -- F. Card purchase never reduces cash at purchase time.
  if exists (
    select 1 from public.financial_impacts
    where event_id = v_event and dimension = 'cash'
  ) then
    raise exception 'card_purchase_has_cash_impact';
  end if;

  -- G. Impacts equal a manual canonical 1x purchase.
  v_manual_purchase := public.register_card_purchase(
    v_space,
    v_card,
    21.90,
    'Manual comparison',
    1,
    v_expense_category,
    '2026-10-15 12:00:00-03'::timestamptz,
    null,
    'app',
    null
  );

  select event_id into v_manual_event
  from public.card_purchases
  where id = v_manual_purchase;

  select coalesce(sum(amount), 0) into v_value
  from public.financial_impacts
  where event_id = v_event and dimension = 'economic';
  select coalesce(sum(amount), 0) into v_manual_value
  from public.financial_impacts
  where event_id = v_manual_event and dimension = 'economic';
  if v_value <> -21.90 or v_value <> v_manual_value then
    raise exception 'economic_impact_invalid';
  end if;

  select coalesce(sum(amount), 0) into v_value
  from public.financial_impacts
  where event_id = v_event and dimension = 'budget';
  select coalesce(sum(amount), 0) into v_manual_value
  from public.financial_impacts
  where event_id = v_manual_event and dimension = 'budget';
  if v_value <> -21.90 or v_value <> v_manual_value then
    raise exception 'budget_impact_invalid';
  end if;

  -- H. Repeating the same occurrence is idempotent.
  v_event_again := public.realize_recurring(
    v_space, v_rec_card, '2026-10-15', null
  );
  if v_event_again <> v_event then
    raise exception 'idempotency_event_mismatch';
  end if;

  select count(*) into v_count
  from public.financial_events
  where space_id = v_space
    and event_type = 'card_purchase'
    and description = 'Spotify';
  if v_count <> 1 then
    raise exception 'duplicate_card_event';
  end if;

  select count(*) into v_count
  from public.card_purchases
  where space_id = v_space and event_id = v_event;
  if v_count <> 1 then
    raise exception 'duplicate_card_purchase';
  end if;

  select count(*) into v_count
  from public.card_installments
  where space_id = v_space and purchase_id = v_purchase;
  if v_count <> 1 then
    raise exception 'duplicate_card_installment';
  end if;

  if not exists (
    select 1 from public.recurring_occurrences
    where recurring_item_id = v_rec_card
      and due_date = '2026-10-15'
      and event_id = v_event
      and status = 'realized'
      and actual_amount = 21.90
  ) then
    raise exception 'occurrence_event_link_missing';
  end if;

  -- I. Failed canonical purchase cannot leave a realized occurrence.
  update public.credit_cards set active = false where id = v_bad_card;
  begin
    perform public.realize_recurring(
      v_space, v_rec_bad, '2026-10-15', null
    );
    raise exception 'expected_card_failure';
  exception
    when others then
      if sqlerrm = 'expected_card_failure' then
        raise;
      end if;
      if position('invalid_card' in sqlerrm) = 0 then
        raise exception 'unexpected_card_failure: %', sqlerrm;
      end if;
  end;

  if exists (
    select 1 from public.recurring_occurrences
    where recurring_item_id = v_rec_bad
      and due_date = '2026-10-15'
      and status = 'realized'
  ) then
    raise exception 'failed_purchase_marked_realized';
  end if;

  -- J. Exactly one destination is mandatory; income remains account-only.
  begin
    insert into public.recurring_items(
      space_id, name, item_type, amount, frequency, day_of_month,
      monthly_days, category_id, account_id, card_id, starts_on,
      certainty, active
    ) values (
      v_space, 'Invalid both', 'expense', 10, 'monthly', 15,
      array[15], v_expense_category, v_account, v_card,
      '2026-10-01', 'confirmed', true
    );
    raise exception 'expected_destination_constraint';
  exception
    when check_violation then null;
  end;

  begin
    insert into public.recurring_items(
      space_id, name, item_type, amount, frequency, day_of_month,
      monthly_days, category_id, account_id, card_id, starts_on,
      certainty, active
    ) values (
      v_space, 'Invalid income card', 'income', 10, 'monthly', 15,
      array[15], v_income_category, null, v_card,
      '2026-10-01', 'confirmed', true
    );
    raise exception 'expected_income_destination_constraint';
  exception
    when check_violation then null;
  end;
end;
$test$;

rollback;
