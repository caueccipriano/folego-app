-- Filter/search/keyset regression coverage. Fixtures are isolated and rolled back.
begin;

do $test$
declare
  v_user uuid;
  v_space uuid := gen_random_uuid();
  v_account_a uuid := gen_random_uuid();
  v_account_b uuid := gen_random_uuid();
  v_benefit uuid := gen_random_uuid();
  v_card uuid := gen_random_uuid();
  v_parent_category uuid := gen_random_uuid();
  v_child_category uuid := gen_random_uuid();
  v_purchase uuid;
  v_purchase_event uuid;
  v_invoice uuid;
  v_payment_event uuid;
  v_benefit_event uuid;
  v_transfer_event uuid := gen_random_uuid();
  v_cursor_at timestamptz;
  v_cursor_id uuid;
  v_count integer;
  v_distinct integer;
  i integer;
begin
  select owner_id into v_user from public.financial_spaces order by created_at limit 1;
  if v_user is null then raise exception 'test_setup_no_user'; end if;
  perform set_config('request.jwt.claim.sub', v_user::text, true);

  insert into public.financial_spaces(id, owner_id, name, type, currency, timezone)
  values(v_space, v_user, 'Filtered transaction test', 'personal', 'BRL', 'America/Sao_Paulo');
  insert into public.space_members(space_id, user_id, role) values(v_space, v_user, 'owner');
  insert into public.accounts(id, space_id, name, type, available_for_spending, active) values
    (v_account_a, v_space, 'Conta A', 'checking', true, true),
    (v_account_b, v_space, 'Conta B', 'checking', true, true),
    (v_benefit, v_space, 'Flash', 'benefit', false, true);
  insert into public.categories(id, space_id, name, kind, parent_id, active) values
    (v_parent_category, v_space, 'Filtro pai ' || left(v_space::text, 8), 'expense', null, true),
    (v_child_category, v_space, 'Filtro filho ' || left(v_space::text, 8), 'expense', v_parent_category, true);
  insert into public.credit_cards(id, space_id, name, closing_day, due_day, payment_account_id, active)
  values(v_card, v_space, 'Cartão teste', 20, 27, v_account_a, true);

  perform public.register_expense(v_space, v_account_a, 12, 'Uber [extrato 4]', v_child_category, '2026-09-10 10:00:00-03'::timestamptz, date '2026-09-10', 'test', null);
  perform public.register_income(v_space, v_account_a, 100, 'Receita teste', null, '2026-09-10 11:00:00-03'::timestamptz, date '2026-09-10', 'test', null);
  perform public.register_expense(v_space, v_account_a, 13, 'Último instante do dia', v_child_category, '2026-09-10 23:59:59-03'::timestamptz, date '2026-09-10', 'test', null);
  perform public.register_expense(v_space, v_account_a, 14, 'Primeiro instante do dia seguinte', v_child_category, '2026-09-11 00:00:00-03'::timestamptz, date '2026-09-11', 'test', null);

  v_purchase := public.register_card_purchase(v_space, v_card, 80, 'Compra cartão', 1, v_child_category, '2026-09-10 12:00:00-03'::timestamptz, 'Loja Teste Merchant', 'test', null);
  select event_id into v_purchase_event from public.card_purchases where id = v_purchase;
  select invoice_id into v_invoice from public.card_installments where purchase_id = v_purchase limit 1;
  perform public.pay_card_invoice(v_space, v_invoice, v_account_a, 20, 'payment', '2026-09-15 12:00:00-03'::timestamptz, 'test', null);
  select event_id into v_payment_event from public.card_payments where space_id = v_space and invoice_id = v_invoice order by created_at desc limit 1;

  v_benefit_event := public.register_benefit_at(v_space, v_benefit, 25, 'Almoço benefício', false, v_child_category, '2026-09-10 13:00:00-03'::timestamptz);

  insert into public.financial_events(id, space_id, event_type, description, amount, currency, occurred_at, competence_date, status, source, metadata)
  values(v_transfer_event, v_space, 'transfer', 'Transferência interna', 40, 'BRL', '2026-09-10 14:00:00-03'::timestamptz, date '2026-09-10', 'confirmed', 'test', jsonb_build_object('from_account_id', v_account_a, 'to_account_id', v_account_b));
  insert into public.financial_impacts(space_id, event_id, dimension, amount, account_id, effective_date) values
    (v_space, v_transfer_event, 'cash', -40, v_account_a, date '2026-09-10'),
    (v_space, v_transfer_event, 'cash', 40, v_account_b, date '2026-09-10');

  if not exists (select 1 from public.list_transactions_filtered(p_space_id => v_space, p_date_from => date '2026-09-10', p_date_to => date '2026-09-10', p_limit => 100) where description = 'Último instante do dia') then raise exception 'period_end_day_not_included'; end if;
  if exists (select 1 from public.list_transactions_filtered(p_space_id => v_space, p_date_from => date '2026-09-10', p_date_to => date '2026-09-10', p_limit => 100) where description = 'Primeiro instante do dia seguinte') then raise exception 'period_next_day_included'; end if;
  if exists (select 1 from public.list_transactions_filtered(p_space_id => v_space, p_event_types => array['income']::text[], p_limit => 100) where event_type <> 'income') then raise exception 'single_type_filter_failed'; end if;
  if exists (select 1 from public.list_transactions_filtered(p_space_id => v_space, p_event_types => array['income','card_purchase']::text[], p_limit => 100) where event_type <> all(array['income','card_purchase']::text[])) then raise exception 'multi_type_filter_failed'; end if;
  if not exists (select 1 from public.list_transactions_filtered(p_space_id => v_space, p_category_id => v_parent_category, p_limit => 100) where description = 'Uber [extrato 4]') then raise exception 'parent_category_filter_failed'; end if;

  select count(*) into v_count from public.list_transactions_filtered(p_space_id => v_space, p_account_id => v_account_b, p_limit => 100) where id = v_transfer_event;
  if v_count <> 1 then raise exception 'transfer_account_filter_duplicate_or_missing'; end if;
  if not exists (select 1 from public.list_transactions_filtered(p_space_id => v_space, p_account_id => v_account_a, p_limit => 100) where id = v_payment_event) then raise exception 'card_payment_account_filter_failed'; end if;
  if not exists (select 1 from public.list_transactions_filtered(p_space_id => v_space, p_card_id => v_card, p_limit => 100) where id = v_purchase_event) or not exists (select 1 from public.list_transactions_filtered(p_space_id => v_space, p_card_id => v_card, p_limit => 100) where id = v_payment_event) then raise exception 'card_filter_failed'; end if;
  if not exists (select 1 from public.list_transactions_filtered(p_space_id => v_space, p_benefit_account_id => v_benefit, p_limit => 100) where id = v_benefit_event) then raise exception 'benefit_filter_failed'; end if;
  if exists (select 1 from public.list_transactions_filtered(p_space_id => v_space, p_benefit_account_id => v_benefit, p_limit => 100) where event_type <> 'benefit_expense') then raise exception 'benefit_filter_mixed_cash'; end if;
  if not exists (select 1 from public.list_transactions_filtered(p_space_id => v_space, p_search => 'uBeR', p_limit => 100) where description = 'Uber [extrato 4]') then raise exception 'description_search_case_insensitive_failed'; end if;
  if not exists (select 1 from public.list_transactions_filtered(p_space_id => v_space, p_search => 'loja teste', p_limit => 100) where id = v_purchase_event) then raise exception 'merchant_search_failed'; end if;
  select count(*) into v_count from public.list_transactions_filtered(p_space_id => v_space, p_search => 'resultado inexistente 999', p_limit => 100);
  if v_count <> 0 then raise exception 'empty_search_failed'; end if;

  for i in 1..55 loop
    perform public.register_expense(v_space, v_account_a, 1, 'Page item ' || lpad(i::text, 2, '0'), v_child_category, ('2026-08-31 12:00:00-03'::timestamptz - make_interval(mins => i)), date '2026-08-31', 'test', null);
  end loop;

  select count(*), count(distinct id) into v_count, v_distinct from public.list_transactions_filtered(p_space_id => v_space, p_event_types => array['expense']::text[], p_search => 'Page item', p_limit => 51);
  if v_count <> 51 or v_distinct <> 51 then raise exception 'first_keyset_page_invalid'; end if;

  select occurred_at, id into v_cursor_at, v_cursor_id from public.list_transactions_filtered(p_space_id => v_space, p_event_types => array['expense']::text[], p_search => 'Page item', p_limit => 51) order by occurred_at desc, id desc offset 49 limit 1;

  select count(*), count(distinct id) into v_count, v_distinct from public.list_transactions_filtered(p_space_id => v_space, p_event_types => array['expense']::text[], p_search => 'Page item', p_cursor_occurred_at => v_cursor_at, p_cursor_id => v_cursor_id, p_limit => 51);
  if v_count <> 5 or v_distinct <> 5 then raise exception 'second_keyset_page_invalid'; end if;

  perform set_config('request.jwt.claim.sub', gen_random_uuid()::text, true);
  begin
    perform 1 from public.list_transactions_filtered(p_space_id => v_space, p_limit => 1);
    raise exception 'membership_not_enforced';
  exception when insufficient_privilege then null;
  end;
  perform set_config('request.jwt.claim.sub', v_user::text, true);
end
$test$;

rollback;
