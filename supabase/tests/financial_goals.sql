begin;

select set_config(
  'request.jwt.claim.sub',
  (select owner_id::text from public.financial_spaces order by created_at limit 1),
  true
);
select set_config('request.jwt.claim.role', 'authenticated', true);

insert into public.financial_spaces(id, owner_id, name, type, currency, timezone)
values
  ('11111111-1111-4111-8111-111111111111', current_setting('request.jwt.claim.sub')::uuid, 'Goals test A', 'personal', 'BRL', 'America/Sao_Paulo'),
  ('22222222-2222-4222-8222-222222222222', current_setting('request.jwt.claim.sub')::uuid, 'Goals test B', 'personal', 'BRL', 'America/Sao_Paulo'),
  ('99999999-9999-4999-8999-999999999999', current_setting('request.jwt.claim.sub')::uuid, 'Goals hidden', 'personal', 'BRL', 'America/Sao_Paulo');

insert into public.space_members(space_id, user_id, role)
values
  ('11111111-1111-4111-8111-111111111111', current_setting('request.jwt.claim.sub')::uuid, 'owner'),
  ('22222222-2222-4222-8222-222222222222', current_setting('request.jwt.claim.sub')::uuid, 'owner');

insert into public.savings_goals(id, space_id, name, target, icon_key, status)
values ('99990000-0000-4000-8000-000000000001', '99999999-9999-4999-8999-999999999999', 'Meta invisível', 500, 'gift', 'active');

set local role authenticated;

do $test$
declare
  v_events_before bigint;
  v_impacts_before bigint;
  v_total numeric;
  v_status text;
  v_completed_at timestamptz;
  v_failed boolean;
begin
  if exists (
    select 1 from public.savings_goals
    where id = '99990000-0000-4000-8000-000000000001'
  ) then
    raise exception 'rls_select_space_isolation_failed';
  end if;

  v_failed := false;
  begin
    insert into public.savings_goals(space_id, name, target)
    values ('99999999-9999-4999-8999-999999999999', 'Não deveria gravar', 100);
  exception when insufficient_privilege then
    v_failed := true;
  end;
  if not v_failed then raise exception 'rls_write_space_isolation_failed'; end if;

  v_failed := false;
  begin
    insert into public.savings_goals(space_id, name, target)
    values ('11111111-1111-4111-8111-111111111111', 'Target inválido', 0);
  exception when check_violation then
    v_failed := true;
  end;
  if not v_failed then raise exception 'goal_target_positive_constraint_failed'; end if;

  insert into public.savings_goals(id, space_id, name, target, target_date, icon_key)
  values (
    '33333333-3333-4333-8333-333333333333',
    '11111111-1111-4111-8111-111111111111',
    'Entrada do carro', 1000, current_date + 90, 'car'
  );

  v_failed := false;
  begin
    insert into public.goal_contributions(goal_id, space_id, amount)
    values (
      '33333333-3333-4333-8333-333333333333',
      '11111111-1111-4111-8111-111111111111', 0
    );
  exception when check_violation then
    v_failed := true;
  end;
  if not v_failed then raise exception 'goal_contribution_positive_constraint_failed'; end if;

  v_failed := false;
  begin
    insert into public.goal_contributions(goal_id, space_id, amount)
    values (
      '33333333-3333-4333-8333-333333333333',
      '22222222-2222-4222-8222-222222222222', 10
    );
  exception
    when foreign_key_violation or insufficient_privilege then
      v_failed := true;
  end;
  if not v_failed then raise exception 'goal_contribution_cross_space_link_failed'; end if;

  select count(*) into v_events_before from public.financial_events;
  select count(*) into v_impacts_before from public.financial_impacts;

  insert into public.goal_contributions(id, goal_id, space_id, amount, contributed_at, note)
  values
    ('55555555-5555-4555-8555-555555555551', '33333333-3333-4333-8333-333333333333', '11111111-1111-4111-8111-111111111111', 300, now() - interval '1 day', 'primeiro aporte'),
    ('55555555-5555-4555-8555-555555555552', '33333333-3333-4333-8333-333333333333', '11111111-1111-4111-8111-111111111111', 700, now(), 'segundo aporte');

  select coalesce(sum(amount), 0) into v_total
  from public.goal_contributions
  where goal_id = '33333333-3333-4333-8333-333333333333';
  if v_total <> 1000 then raise exception 'goal_contribution_sum_failed:%', v_total; end if;

  select status, completed_at into v_status, v_completed_at
  from public.savings_goals
  where id = '33333333-3333-4333-8333-333333333333';
  if v_status <> 'completed' or v_completed_at is null then
    raise exception 'goal_auto_completion_failed:%:%', v_status, v_completed_at;
  end if;

  if (select count(*) from public.financial_events) <> v_events_before then
    raise exception 'goal_contribution_created_financial_event';
  end if;
  if (select count(*) from public.financial_impacts) <> v_impacts_before then
    raise exception 'goal_contribution_created_financial_impact';
  end if;

  update public.savings_goals set target = 1500
  where id = '33333333-3333-4333-8333-333333333333';
  select status into v_status from public.savings_goals
  where id = '33333333-3333-4333-8333-333333333333';
  if v_status <> 'active' then raise exception 'goal_target_increase_reopen_failed:%', v_status; end if;

  insert into public.goal_contributions(goal_id, space_id, amount, note)
  values ('33333333-3333-4333-8333-333333333333', '11111111-1111-4111-8111-111111111111', 600, 'aporte final');

  select status into v_status from public.savings_goals
  where id = '33333333-3333-4333-8333-333333333333';
  if v_status <> 'completed' then raise exception 'goal_recompletion_failed:%', v_status; end if;

  if not exists (
    select 1 from public.savings_goals
    where id = '33333333-3333-4333-8333-333333333333'
      and status = 'completed'
  ) then
    raise exception 'completed_goal_not_preserved';
  end if;
end;
$test$;

reset role;
rollback;
select 'financial_goals_tests = ok' as result;
