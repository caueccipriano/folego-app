-- Integration regression tests for monthly recurring schedules in Fôlego.
-- The entire test runs inside a transaction and rolls back all created data.

begin;

do $test$
declare
  v_user uuid;
  v_space uuid := gen_random_uuid();
  v_checking_a uuid := gen_random_uuid();
  v_checking_b uuid := gen_random_uuid();
  v_benefit uuid := gen_random_uuid();
  v_item uuid;
  v_income uuid;
  v_expense uuid;
  v_event uuid;
  v_next date;
  v_mandatory numeric;
  v_liquid numeric;
  v_dates date[];
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
  values(v_space, v_user, 'Recurring schedule snapshot test', 'personal', 'BRL', 'America/Sao_Paulo');

  insert into public.space_members(space_id,user_id,role)
  values(v_space,v_user,'owner');

  insert into public.accounts(id,space_id,name,type,available_for_spending,active)
  values
    (v_checking_a,v_space,'Checking A','checking',true,true),
    (v_checking_b,v_space,'Checking B','checking',true,true),
    (v_benefit,v_space,'Benefit','benefit',true,true);

  -- Base cash 500 + 100, plus canonical benefit 300 and legacy wrong benefit cash 300.
  insert into public.financial_events(space_id,event_type,description,amount,currency,occurred_at,competence_date,status,source)
  values(v_space,'opening_balance','Checking A',500,'BRL','2026-01-01 12:00:00+00','2026-01-01','confirmed','test')
  returning id into v_event;

  insert into public.financial_impacts(event_id,space_id,dimension,amount,account_id,effective_date)
  values(v_event,v_space,'cash',500,v_checking_a,'2026-01-01');

  insert into public.financial_events(space_id,event_type,description,amount,currency,occurred_at,competence_date,status,source)
  values(v_space,'opening_balance','Checking B',100,'BRL','2026-01-01 12:00:00+00','2026-01-01','confirmed','test')
  returning id into v_event;

  insert into public.financial_impacts(event_id,space_id,dimension,amount,account_id,effective_date)
  values(v_event,v_space,'cash',100,v_checking_b,'2026-01-01');

  insert into public.financial_events(space_id,event_type,description,amount,currency,occurred_at,competence_date,status,source)
  values(v_space,'opening_balance','Benefit',300,'BRL','2026-01-01 12:00:00+00','2026-01-01','confirmed','test')
  returning id into v_event;

  insert into public.financial_impacts(event_id,space_id,dimension,amount,account_id,effective_date)
  values
    (v_event,v_space,'benefit',300,v_benefit,'2026-01-01'),
    (v_event,v_space,'cash',300,v_benefit,'2026-01-01');

  -- A. monthly_days with one day. Modern schedule wins even with legacy day populated.
  v_item := gen_random_uuid();
  insert into public.recurring_items(
    id,space_id,name,item_type,amount,frequency,day_of_month,monthly_days,monthly_last_day,starts_on,certainty,active
  )
  values(v_item,v_space,'A income','income',100,'monthly',10,array[10],false,'2026-01-01','confirmed',true);

  select next_income_date into v_next
  from public.get_folego_snapshot(v_space,'2026-01-01');

  if v_next <> date '2026-01-10' then
    raise exception 'test_a_snapshot_failed: %',v_next;
  end if;

  select array_agg(due_date order by due_date) into v_dates
  from public.get_upcoming_events(v_space,'2026-01-01','2026-01-31')
  where id=v_item;

  if v_dates <> array[date '2026-01-10'] then
    raise exception 'test_a_upcoming_failed: %',v_dates;
  end if;

  delete from public.recurring_items where space_id=v_space;

  -- B. monthly_days with multiple days: both expenses count before next confirmed income.
  v_income := gen_random_uuid();
  v_expense := gen_random_uuid();

  insert into public.recurring_items(
    id,space_id,name,item_type,amount,frequency,day_of_month,monthly_days,monthly_last_day,account_id,starts_on,certainty,active
  )
  values
    (v_income,v_space,'B next income','income',100,'monthly',25,array[25],false,null,'2026-01-01','confirmed',true),
    (v_expense,v_space,'B expense','expense',10,'monthly',5,array[5,20],false,v_checking_a,'2026-01-01','confirmed',true);

  select mandatory_outflows_until_income into v_mandatory
  from public.get_folego_snapshot(v_space,'2026-01-01');

  if v_mandatory <> 20 then
    raise exception 'test_b_snapshot_failed: %',v_mandatory;
  end if;

  select array_agg(due_date order by due_date) into v_dates
  from public.get_upcoming_events(v_space,'2026-01-01','2026-01-24')
  where id=v_expense;

  if v_dates <> array[date '2026-01-05',date '2026-01-20'] then
    raise exception 'test_b_upcoming_failed: %',v_dates;
  end if;

  delete from public.recurring_items where space_id=v_space;

  -- C. monthly_last_day in a normal February = 28.
  v_item := gen_random_uuid();
  insert into public.recurring_items(
    id,space_id,name,item_type,amount,frequency,day_of_month,monthly_days,monthly_last_day,starts_on,certainty,active
  )
  values(v_item,v_space,'C last day','income',100,'monthly',15,'{}'::integer[],true,'2027-02-01','confirmed',true);

  select next_income_date into v_next
  from public.get_folego_snapshot(v_space,'2027-02-01');

  if v_next <> date '2027-02-28' then
    raise exception 'test_c_snapshot_failed: %',v_next;
  end if;

  select array_agg(due_date order by due_date) into v_dates
  from public.get_upcoming_events(v_space,'2027-02-01','2027-02-28')
  where id=v_item;

  if v_dates <> array[date '2027-02-28'] then
    raise exception 'test_c_upcoming_failed: %',v_dates;
  end if;

  delete from public.recurring_items where space_id=v_space;

  -- D. monthly_last_day in a leap-year February = 29.
  v_item := gen_random_uuid();
  insert into public.recurring_items(
    id,space_id,name,item_type,amount,frequency,day_of_month,monthly_days,monthly_last_day,starts_on,certainty,active
  )
  values(v_item,v_space,'D leap last day','income',100,'monthly',15,'{}'::integer[],true,'2028-02-01','confirmed',true);

  select next_income_date into v_next
  from public.get_folego_snapshot(v_space,'2028-02-01');

  if v_next <> date '2028-02-29' then
    raise exception 'test_d_snapshot_failed: %',v_next;
  end if;

  select array_agg(due_date order by due_date) into v_dates
  from public.get_upcoming_events(v_space,'2028-02-01','2028-02-29')
  where id=v_item;

  if v_dates <> array[date '2028-02-29'] then
    raise exception 'test_d_upcoming_failed: %',v_dates;
  end if;

  delete from public.recurring_items where space_id=v_space;

  -- E. Multiple days + last day in April: 5, 20 and 30.
  v_income := gen_random_uuid();
  v_expense := gen_random_uuid();

  insert into public.recurring_items(
    id,space_id,name,item_type,amount,frequency,day_of_month,monthly_days,monthly_last_day,account_id,starts_on,certainty,active
  )
  values
    (v_income,v_space,'E May income','income',100,'monthly',1,array[1],false,null,'2026-05-01','confirmed',true),
    (v_expense,v_space,'E expense','expense',10,'monthly',5,array[5,20],true,v_checking_a,'2026-04-01','confirmed',true);

  select mandatory_outflows_until_income into v_mandatory
  from public.get_folego_snapshot(v_space,'2026-04-01');

  if v_mandatory <> 30 then
    raise exception 'test_e_snapshot_failed: %',v_mandatory;
  end if;

  select array_agg(due_date order by due_date) into v_dates
  from public.get_upcoming_events(v_space,'2026-04-01','2026-04-30')
  where id=v_expense;

  if v_dates <> array[date '2026-04-05',date '2026-04-20',date '2026-04-30'] then
    raise exception 'test_e_upcoming_failed: %',v_dates;
  end if;

  delete from public.recurring_items where space_id=v_space;

  -- F. monthly_days=[31] does not fabricate April 30.
  v_income := gen_random_uuid();
  v_expense := gen_random_uuid();

  insert into public.recurring_items(
    id,space_id,name,item_type,amount,frequency,day_of_month,monthly_days,monthly_last_day,account_id,starts_on,certainty,active
  )
  values
    (v_income,v_space,'F May income','income',100,'monthly',1,array[1],false,null,'2026-05-01','confirmed',true),
    (v_expense,v_space,'F day 31','expense',10,'monthly',31,array[31],false,v_checking_a,'2026-04-01','confirmed',true);

  select mandatory_outflows_until_income into v_mandatory
  from public.get_folego_snapshot(v_space,'2026-04-01');

  if v_mandatory <> 0 then
    raise exception 'test_f_snapshot_failed: %',v_mandatory;
  end if;

  if exists(
    select 1 from public.get_upcoming_events(v_space,'2026-04-01','2026-04-30') where id=v_expense
  ) then
    raise exception 'test_f_upcoming_fabricated_day';
  end if;

  delete from public.recurring_items where space_id=v_space;

  -- G. Legacy fallback via day_of_month remains supported.
  v_item := gen_random_uuid();
  insert into public.recurring_items(
    id,space_id,name,item_type,amount,frequency,day_of_month,monthly_days,monthly_last_day,starts_on,certainty,active
  )
  values(v_item,v_space,'G legacy','income',100,'monthly',15,'{}'::integer[],false,'2026-05-01','confirmed',true);

  select next_income_date into v_next
  from public.get_folego_snapshot(v_space,'2026-05-01');

  if v_next <> date '2026-05-15' then
    raise exception 'test_g_snapshot_failed: %',v_next;
  end if;

  select array_agg(due_date order by due_date) into v_dates
  from public.get_upcoming_events(v_space,'2026-05-01','2026-05-31')
  where id=v_item;

  if v_dates <> array[date '2026-05-15'] then
    raise exception 'test_g_upcoming_failed: %',v_dates;
  end if;

  delete from public.recurring_items where space_id=v_space;

  -- H. starts_on after first configured day excludes that earlier occurrence.
  v_item := gen_random_uuid();
  insert into public.recurring_items(
    id,space_id,name,item_type,amount,frequency,day_of_month,monthly_days,monthly_last_day,starts_on,certainty,active
  )
  values(v_item,v_space,'H starts on','income',100,'monthly',5,array[5,20],false,'2026-06-10','confirmed',true);

  select next_income_date into v_next
  from public.get_folego_snapshot(v_space,'2026-06-01');

  if v_next <> date '2026-06-20' then
    raise exception 'test_h_snapshot_failed: %',v_next;
  end if;

  select array_agg(due_date order by due_date) into v_dates
  from public.get_upcoming_events(v_space,'2026-06-01','2026-06-30')
  where id=v_item;

  if v_dates <> array[date '2026-06-20'] then
    raise exception 'test_h_upcoming_failed: %',v_dates;
  end if;

  delete from public.recurring_items where space_id=v_space;

  -- I. ends_on before next configured day excludes that later occurrence.
  v_item := gen_random_uuid();
  insert into public.recurring_items(
    id,space_id,name,item_type,amount,frequency,day_of_month,monthly_days,monthly_last_day,starts_on,ends_on,certainty,active
  )
  values(v_item,v_space,'I ends on','income',100,'monthly',20,array[20],false,'2026-07-01','2026-07-10','confirmed',true);

  select next_income_date into v_next
  from public.get_folego_snapshot(v_space,'2026-07-06');

  if v_next is not null then
    raise exception 'test_i_snapshot_failed: %',v_next;
  end if;

  if exists(
    select 1 from public.get_upcoming_events(v_space,'2026-07-06','2026-07-31') where id=v_item
  ) then
    raise exception 'test_i_upcoming_failed';
  end if;

  delete from public.recurring_items where space_id=v_space;

  -- Regression: benefit accounts remain excluded from liquid cash even with legacy cash impacts.
  select liquid_balance into v_liquid
  from public.get_folego_snapshot(v_space,'2026-01-01');

  if v_liquid <> 600 then
    raise exception 'test_benefit_cash_regression_failed: %',v_liquid;
  end if;
end;
$test$;

rollback;

select 'ok' as align_monthly_recurring_schedule_in_folego_snapshot_tests;
