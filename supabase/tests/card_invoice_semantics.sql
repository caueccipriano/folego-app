-- Card invoice semantic regression test.
-- gross purchases - credits - confirmed payments = amount due.
-- Runs in a transaction and rolls back all fixtures.

begin;

do $test$
declare
  v_user uuid;
  v_space uuid := gen_random_uuid();
  v_account uuid := gen_random_uuid();
  v_category uuid := gen_random_uuid();
  v_card uuid := gen_random_uuid();
  v_event uuid := gen_random_uuid();
  v_purchase uuid := gen_random_uuid();
  v_invoice uuid := gen_random_uuid();
  v_result jsonb;
  v_month date := date_trunc('month', current_date)::date;
begin
  select owner_id into v_user
  from public.financial_spaces
  order by created_at
  limit 1;

  if v_user is null then
    raise exception 'card_invoice_test_requires_existing_user';
  end if;

  perform set_config('request.jwt.claim.sub', v_user::text, true);

  insert into public.financial_spaces(id, owner_id, name, type, currency, timezone)
  values(v_space, v_user, 'Card invoice semantics test', 'personal', 'BRL', 'America/Sao_Paulo');

  insert into public.space_members(space_id, user_id, role)
  values(v_space, v_user, 'owner');

  insert into public.accounts(
    id, space_id, name, type, available_for_spending, active
  ) values(
    v_account, v_space, 'Conta', 'checking', true, true
  );

  insert into public.categories(
    id, space_id, name, kind, active, category_role
  ) values(
    v_category, v_space, 'Compras teste', 'expense', true, 'economic'
  );

  insert into public.credit_cards(
    id, space_id, name, closing_day, due_day, payment_account_id, active
  ) values(
    v_card, v_space, 'Cartão teste', 25, 5, v_account, true
  );

  insert into public.financial_events(
    id, space_id, event_type, description, amount, currency,
    occurred_at, competence_date, category_id, status, source
  ) values(
    v_event, v_space, 'card_purchase', 'Compra ciclo', 1843.04, 'BRL',
    now(), current_date, v_category, 'confirmed', 'test'
  );

  insert into public.card_purchases(
    id, space_id, card_id, event_id, description, total_amount,
    installments_count, purchase_at, category_id, status
  ) values(
    v_purchase, v_space, v_card, v_event, 'Compra ciclo', 1843.04,
    2, now(), v_category, 'confirmed'
  );

  insert into public.card_invoices(
    id, space_id, card_id, reference_month, closing_date, due_date,
    opening_balance, status
  ) values(
    v_invoice, v_space, v_card, v_month,
    (v_month + interval '1 month - 1 day')::date,
    (v_month + interval '1 month + 4 days')::date,
    0, 'open'
  );

  insert into public.card_installments(
    id, space_id, purchase_id, invoice_id, installment_number,
    total_installments, amount, competence_date, status
  ) values
    (
      gen_random_uuid(), v_space, v_purchase, v_invoice, 1,
      2, 1702.52, v_month, 'invoiced'
    ),
    (
      gen_random_uuid(), v_space, v_purchase, v_invoice, 2,
      2, 140.52, v_month, 'refunded'
    );

  select public.get_card_invoice_semantics(v_space, v_card)
    into v_result;

  if round((v_result ->> 'gross_purchases')::numeric, 2) <> 1843.04 then
    raise exception 'gross_purchases_wrong: %', v_result ->> 'gross_purchases';
  end if;

  if round((v_result ->> 'credits')::numeric, 2) <> 140.52 then
    raise exception 'credits_wrong: %', v_result ->> 'credits';
  end if;

  if round((v_result ->> 'amount_due')::numeric, 2) <> 1702.52 then
    raise exception 'amount_due_wrong: %', v_result ->> 'amount_due';
  end if;
end;
$test$;

rollback;

select 'ok' as card_invoice_semantics_tests;
