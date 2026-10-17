-- Flexible Budget 1.0 regression smoke test.
-- Runs only against disposable state inside a transaction and rolls back.

begin;

do $test$
declare
  v_user uuid;
  v_space uuid;
  v_before_categories numeric;
  v_after_categories numeric;
  v_limit numeric;
  v_planned numeric;
  v_used numeric;
  v_cash numeric;
  v_spendable numeric;
  blocked boolean := false;
begin
  select owner_id, id into v_user, v_space
  from public.financial_spaces
  order by created_at
  limit 1;

  if v_user is null or v_space is null then
    raise exception 'test_setup_no_space';
  end if;

  perform set_config('request.jwt.claim.sub', v_user::text, true);

  select category_limits_total into v_before_categories
  from public.get_flexible_budget_overview(v_space, date_trunc('month', current_date)::date);

  select liquid_balance into v_cash
  from public.get_folego_snapshot(v_space, current_date);

  perform public.set_flexible_budget_limit(
    v_space,
    date_trunc('month', current_date)::date,
    999999
  );

  select limit_amount, category_limits_total
    into v_limit, v_after_categories
  from public.get_flexible_budget_overview(
    v_space,
    date_trunc('month', current_date)::date
  );

  select monthly_budget_planned, monthly_budget_used, spendable_pool
    into v_planned, v_used, v_spendable
  from public.get_folego_snapshot(v_space, current_date);

  if v_limit <> 999999 or v_planned <> 999999 then
    raise exception 'global_limit_not_applied: overview %, snapshot %', v_limit, v_planned;
  end if;

  if v_before_categories <> v_after_categories then
    raise exception 'category_limits_changed_with_global_limit: % -> %',
      v_before_categories, v_after_categories;
  end if;

  if v_spendable > greatest(v_cash, 0) then
    raise exception 'spendable_exceeded_cash: spendable %, cash %', v_spendable, v_cash;
  end if;

  perform set_config('request.jwt.claim.sub', gen_random_uuid()::text, true);
  begin
    perform public.set_flexible_budget_limit(
      v_space,
      date_trunc('month', current_date)::date,
      123
    );
  exception when insufficient_privilege then
    blocked := true;
  end;

  if not blocked then
    raise exception 'unauthorized_flexible_budget_write_was_not_blocked';
  end if;
end;
$test$;

rollback;

select 'ok' as flexible_budget_1_tests;
