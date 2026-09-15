-- Plano 2.0 integration/regression tests.
-- Everything runs in one transaction and rolls back.

begin;

do $test$
declare
  v_user uuid;
  v_space uuid := gen_random_uuid();
  v_parent uuid := gen_random_uuid();
  v_child_once uuid := gen_random_uuid();
  v_child_recurring uuid := gen_random_uuid();
  v_child_activity uuid := gen_random_uuid();
  v_checking uuid := gen_random_uuid();
  v_benefit uuid := gen_random_uuid();
  v_card uuid := gen_random_uuid();
  v_invoice uuid := gen_random_uuid();
  v_purchase_event uuid := gen_random_uuid();
  v_payment_id uuid;
  v_payment_event uuid;
  v_current date := date_trunc('month', current_date)::date;
  v_prev date := (date_trunc('month', current_date) - interval '1 month')::date;
  v_next date := (date_trunc('month', current_date) + interval '1 month')::date;
  v_next2 date := (date_trunc('month', current_date) + interval '2 months')::date;
  v_value numeric;
  v_before numeric;
  v_after numeric;
  v_source text;
  v_recurring boolean;
  v_count integer;
  v_intruder uuid := gen_random_uuid();
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
  values(v_space, v_user, 'Plan 2.0 integration test', 'personal', 'BRL', 'America/Sao_Paulo');

  insert into public.space_members(space_id, user_id, role)
  values(v_space, v_user, 'owner');

  insert into public.categories(
    id, space_id, name, kind, parent_id, essential, active, category_role, sort_order
  )
  values
    (v_parent, v_space, 'Teste plano', 'expense', null, false, true, 'economic', 10),
    (v_child_once, v_space, 'Pontual', 'expense', v_parent, false, true, 'economic', 11),
    (v_child_recurring, v_space, 'Recorrente', 'expense', v_parent, false, true, 'economic', 12),
    (v_child_activity, v_space, 'Atividade', 'expense', v_parent, false, true, 'economic', 13);

  -- A. Só este mês não herda no próximo.
  perform public.set_budget_limit(v_space, v_current, v_child_once, 500, 'month');

  select planned_amount, budget_source, is_recurring
    into v_value, v_source, v_recurring
  from public.get_budget_overview(v_space, v_current)
  where category_id = v_child_once;

  if v_value <> 500 or v_source <> 'month' or v_recurring then
    raise exception 'test_month_only_current_failed';
  end if;

  select planned_amount into v_value
  from public.get_budget_overview(v_space, v_next)
  where category_id = v_child_once;

  if v_value <> 0 then
    raise exception 'test_month_only_future_failed';
  end if;

  -- B/C. Todo mês aparece no futuro sem materializar meses futuros.
  perform public.set_budget_limit(
    v_space, v_current, v_child_recurring, 700, 'from_month'
  );

  select planned_amount, is_recurring into v_value, v_recurring
  from public.get_budget_overview(v_space, v_next)
  where category_id = v_child_recurring;

  if v_value <> 700 or not v_recurring then
    raise exception 'test_recurring_future_failed';
  end if;

  select count(*) into v_count
  from public.budgets
  where space_id = v_space
    and period_month in (v_next, v_next2);

  if v_count <> 0 then
    raise exception 'test_recurring_materialized_future_rows';
  end if;

  -- D/F. Deste mês em diante versiona a regra e mantém o passado.
  perform public.set_budget_limit(
    v_space, v_next, v_child_recurring, 850, 'from_month'
  );

  select planned_amount into v_value
  from public.get_budget_overview(v_space, v_current)
  where category_id = v_child_recurring;

  if v_value <> 700 then
    raise exception 'test_recurring_history_changed';
  end if;

  select planned_amount into v_value
  from public.get_budget_overview(v_space, v_next2)
  where category_id = v_child_recurring;

  if v_value <> 850 then
    raise exception 'test_recurring_from_month_failed';
  end if;

  -- E. Override só muda o mês escolhido.
  perform public.set_budget_limit(
    v_space, v_current, v_child_recurring, 900, 'month'
  );

  select planned_amount, budget_source into v_value, v_source
  from public.get_budget_overview(v_space, v_current)
  where category_id = v_child_recurring;

  if v_value <> 900 or v_source <> 'override' then
    raise exception 'test_month_override_failed';
  end if;

  select planned_amount into v_value
  from public.get_budget_overview(v_space, v_next)
  where category_id = v_child_recurring;

  if v_value <> 850 then
    raise exception 'test_month_override_leaked_future';
  end if;

  -- G. Cancelar recorrência no futuro não apaga histórico.
  perform public.set_budget_limit(
    v_space, v_next2, v_child_recurring, 0, 'cancel_from_month'
  );

  select planned_amount into v_value
  from public.get_budget_overview(v_space, v_next)
  where category_id = v_child_recurring;

  if v_value <> 850 then
    raise exception 'test_cancel_changed_previous_month';
  end if;

  select planned_amount into v_value
  from public.get_budget_overview(v_space, v_next2)
  where category_id = v_child_recurring;

  if v_value <> 0 then
    raise exception 'test_cancel_future_failed';
  end if;

  begin
    perform public.set_budget_limit(
      v_space, v_prev, v_child_recurring, 999, 'from_month'
    );
    raise exception 'test_historical_recurring_was_accepted';
  exception
    when others then
      if sqlerrm = 'test_historical_recurring_was_accepted' then raise; end if;
      if position('historical_recurring_budget_is_immutable' in sqlerrm) = 0 then
        raise exception 'test_historical_recurring_wrong_error: %', sqlerrm;
      end if;
  end;

  -- H. Parent não aceita budget direto.
  begin
    perform public.set_budget_limit(v_space, v_current, v_parent, 1000, 'month');
    raise exception 'test_parent_budget_was_accepted';
  exception
    when others then
      if sqlerrm = 'test_parent_budget_was_accepted' then raise; end if;
      if position('budget_requires_subcategory' in sqlerrm) = 0 then
        raise exception 'test_parent_budget_wrong_error: %', sqlerrm;
      end if;
  end;

  begin
    perform public.onboarding_set_budget_item(
      v_space, v_current, v_parent, 1000
    );
    raise exception 'test_onboarding_parent_budget_was_accepted';
  exception
    when others then
      if sqlerrm = 'test_onboarding_parent_budget_was_accepted' then raise; end if;
      if position('Budget requires an expense subcategory' in sqlerrm) = 0 then
        raise exception 'test_onboarding_parent_wrong_error: %', sqlerrm;
      end if;
  end;

  select planned_amount into v_value
  from public.get_budget_overview(v_space, v_current)
  where category_id = v_parent;

  if v_value <> 1400 then
    raise exception 'test_parent_aggregation_failed: %', v_value;
  end if;

  -- I. Outro usuário não lê nem grava o espaço.
  perform set_config('request.jwt.claim.sub', v_intruder::text, true);

  select count(*) into v_count
  from public.get_budget_overview(v_space, v_current);

  if v_count <> 0 then
    raise exception 'test_other_space_read_leaked';
  end if;

  begin
    perform public.set_budget_limit(v_space, v_current, v_child_once, 1, 'month');
    raise exception 'test_other_space_write_was_accepted';
  exception
    when others then
      if sqlerrm = 'test_other_space_write_was_accepted' then raise; end if;
      if position('write_access_denied' in sqlerrm) = 0 then
        raise exception 'test_other_space_write_wrong_error: %', sqlerrm;
      end if;
  end;

  perform set_config('request.jwt.claim.sub', v_user::text, true);

  -- J. Pagamento da fatura não duplica realizado.
  insert into public.accounts(
    id, space_id, name, type, available_for_spending, active
  )
  values(v_checking, v_space, 'Conta teste', 'checking', true, true);

  insert into public.credit_cards(
    id, space_id, name, closing_day, due_day, payment_account_id, active
  )
  values(v_card, v_space, 'Cartão teste', 20, 5, v_checking, true);

  insert into public.card_invoices(
    id, space_id, card_id, reference_month, closing_date, due_date,
    opening_balance, status
  )
  values(
    v_invoice,
    v_space,
    v_card,
    v_current,
    v_current + 19,
    v_current + 35,
    100,
    'open'
  );

  insert into public.financial_events(
    id, space_id, event_type, description, amount, competence_date,
    category_id, status, source
  )
  values(
    v_purchase_event,
    v_space,
    'card_purchase',
    'Compra teste',
    100,
    v_current,
    v_child_activity,
    'confirmed',
    'app'
  );

  insert into public.financial_impacts(
    event_id, space_id, dimension, amount, category_id, effective_date
  )
  values(
    v_purchase_event,
    v_space,
    'budget',
    -100,
    v_child_activity,
    v_current
  );

  select actual_amount into v_before
  from public.get_budget_overview(v_space, v_current)
  where category_id = v_child_activity;

  v_payment_id := public.pay_card_invoice(
    v_space,
    v_invoice,
    v_checking,
    100,
    'payment',
    now(),
    'app',
    null
  );

  select event_id into v_payment_event
  from public.card_payments
  where id = v_payment_id;

  if exists(
    select 1
    from public.financial_impacts
    where event_id = v_payment_event
      and dimension = 'budget'
  ) then
    raise exception 'test_card_payment_budget_impact_failed';
  end if;

  select actual_amount into v_after
  from public.get_budget_overview(v_space, v_current)
  where category_id = v_child_activity;

  if v_before <> 100 or v_after <> v_before then
    raise exception 'test_card_payment_duplicated_budget: before %, after %',
      v_before,
      v_after;
  end if;

  -- K. Benefício continua consumindo budget pela dimensão canônica.
  insert into public.accounts(
    id, space_id, name, type, available_for_spending, active
  )
  values(v_benefit, v_space, 'Benefício teste', 'benefit', false, true);

  perform public.register_benefit(
    v_space,
    v_benefit,
    80,
    'Benefício gasto teste',
    false,
    v_child_activity
  );

  select actual_amount into v_after
  from public.get_budget_overview(v_space, v_current)
  where category_id = v_child_activity;

  if v_after <> 180 then
    raise exception 'test_benefit_budget_failed: %', v_after;
  end if;
end;
$test$;

rollback;
