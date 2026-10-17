begin;

do $test$
declare
  v_user uuid;
  v_space uuid := gen_random_uuid();
  v_event uuid := gen_random_uuid();
  v_tag uuid;
  v_custom uuid;
  v_count int;
  v_parent uuid;
  v_account uuid := gen_random_uuid();
  v_card uuid := gen_random_uuid();
  v_invoice uuid := gen_random_uuid();
  v_payment uuid;
begin
  select owner_id into v_user
  from public.financial_spaces
  order by created_at
  limit 1;

  if v_user is null then raise exception 'test_setup_no_user'; end if;

  perform set_config('request.jwt.claim.sub', v_user::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);

  insert into public.financial_spaces(id,owner_id,name,type,currency,timezone)
  values(v_space,v_user,'Universal category taxonomy test','personal','BRL','America/Sao_Paulo');
  insert into public.space_members(space_id,user_id,role)
  values(v_space,v_user,'owner');

  select count(*) into v_count
  from public.categories
  where space_id=v_space
    and kind='expense'
    and parent_id is null
    and category_role='economic'
    and active;

  if v_count <> 18 then
    raise exception 'expense_parent_count_failed:%',v_count;
  end if;

  if exists(
    select 1 from public.categories
    where space_id=v_space
      and name in ('Vestuário','Giovani')
      and active
  ) then
    raise exception 'legacy_category_visible';
  end if;

  if not exists(select 1 from public.categories where space_id=v_space and system_key='expense.transport.fuel' and name='Combustível') then raise exception 'fuel_mapping_missing'; end if;
  if not exists(select 1 from public.categories where space_id=v_space and system_key='expense.health.pharmacy' and name='Farmácia') then raise exception 'pharmacy_mapping_missing'; end if;
  if not exists(select 1 from public.categories where space_id=v_space and system_key='expense.shopping.clothes' and name='Roupas') then raise exception 'clothing_mapping_missing'; end if;
  if not exists(select 1 from public.categories where space_id=v_space and system_key='expense.debt.agreements' and name='Acordos / renegociações') then raise exception 'agreement_mapping_missing'; end if;

  select id into v_parent
  from public.categories
  where space_id=v_space and system_key='income.root';

  select count(*) into v_count
  from public.categories
  where space_id=v_space
    and kind='income'
    and parent_id=v_parent
    and active
    and category_role='economic';

  if v_count <> 11 then
    raise exception 'income_leaf_count_failed:%',v_count;
  end if;

  if exists(
    select 1
    from public.get_category_catalog(v_space,'expense')
    where name in (
      'A classificar',
      'Transferências',
      'Pagamento de cartão',
      'Reserva',
      'Investimentos',
      'Reembolso'
    )
  ) then
    raise exception 'movement_or_pending_leaked_to_expense_catalog';
  end if;

  insert into public.tags(space_id,name,tag_type)
  values(v_space,'Viagem Ouro Preto','project')
  returning id into v_tag;

  insert into public.financial_events(
    id,space_id,event_type,description,amount,currency,
    occurred_at,competence_date,status,source
  ) values(
    v_event,v_space,'expense','Restaurante',10,'BRL',
    now(),current_date,'confirmed','test'
  );

  perform public.set_event_annotations(
    v_space,v_event,'want','variable','one_off',array[v_tag]
  );

  if not exists(
    select 1 from public.financial_events
    where id=v_event
      and necessity_class='want'
      and behavior_class='variable'
      and frequency_class='one_off'
  ) then
    raise exception 'event_attributes_failed';
  end if;

  if not exists(
    select 1 from public.financial_event_tags
    where event_id=v_event and tag_id=v_tag and space_id=v_space
  ) then
    raise exception 'event_tag_failed';
  end if;

  v_custom := public.create_custom_category(
    v_space,
    'Minha categoria',
    'expense',
    null,
    false,
    '#8C8CA8',
    array['personalizada']
  );

  if not exists(
    select 1 from public.categories
    where id=v_custom and not is_system and category_role='economic'
  ) then
    raise exception 'custom_category_create_failed';
  end if;

  perform public.rename_custom_category(v_space,v_custom,'Categoria pessoal');
  perform public.set_category_visibility(v_space,v_custom,false);

  if exists(select 1 from public.categories where id=v_custom and active) then
    raise exception 'custom_category_hide_failed';
  end if;

  insert into public.accounts(id,space_id,name,type,available_for_spending,active)
  values(v_account,v_space,'Conta teste','checking',true,true);

  insert into public.credit_cards(
    id,space_id,name,closing_day,due_day,payment_account_id,active
  ) values(v_card,v_space,'Cartão teste',10,15,v_account,true);

  insert into public.card_invoices(
    id,space_id,card_id,reference_month,closing_date,due_date,opening_balance,status
  ) values(
    v_invoice,v_space,v_card,date_trunc('month',current_date)::date,
    current_date,current_date+5,100,'open'
  );

  v_payment := public.pay_card_invoice(
    v_space,v_invoice,v_account,100,'payment',now(),'test',null
  );

  if (
    select count(*)
    from public.financial_impacts i
    join public.card_payments p on p.event_id=i.event_id
    where p.id=v_payment and i.dimension in ('economic','budget')
  ) <> 0 then
    raise exception 'card_payment_double_expense_regression';
  end if;

  if (
    select count(*)
    from public.financial_impacts i
    join public.card_payments p on p.event_id=i.event_id
    where p.id=v_payment and i.dimension='cash' and i.amount=-100
  ) <> 1 then
    raise exception 'card_payment_cash_regression';
  end if;
end;
$test$;

rollback;
select 'universal_category_taxonomy_tests = ok' as result;
