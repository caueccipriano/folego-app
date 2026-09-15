begin;

do $test$
declare
  v_user uuid;
  v_space uuid := gen_random_uuid();
  v_count int;
  v_custom uuid;
  v_color text;
  v_key text;
  v_role text;
begin
  select owner_id into v_user
  from public.financial_spaces
  order by created_at
  limit 1;

  if v_user is null then
    raise exception 'test_setup_no_user';
  end if;

  perform set_config('request.jwt.claim.sub', v_user::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);

  insert into public.financial_spaces(id,owner_id,name,type,currency,timezone)
  values(v_space,v_user,'Category visual metadata test','personal','BRL','America/Sao_Paulo');

  insert into public.space_members(space_id,user_id,role)
  values(v_space,v_user,'owner');

  select count(*) into v_count
  from public.get_category_catalog(v_space,'income')
  where is_selectable;

  if v_count <> 11 then
    raise exception 'income_catalog_count_failed:%',v_count;
  end if;

  select color_hex,system_key,category_role
  into v_color,v_key,v_role
  from public.get_category_catalog(v_space,'expense')
  where name='Viagens' and parent_id is null;

  if v_color <> '#167D91'
     or v_key <> 'expense.travel'
     or v_role <> 'economic' then
    raise exception 'travel_visual_metadata_failed:%,%,%',v_color,v_key,v_role;
  end if;

  v_custom := public.create_custom_category(
    v_space,
    'Categoria coral',
    'expense',
    null,
    false,
    '#123456',
    array['coral']
  );

  select color_hex into v_color
  from public.get_category_catalog(v_space,'expense')
  where id=v_custom;

  if v_color <> '#123456' then
    raise exception 'custom_color_not_exposed:%',v_color;
  end if;
end;
$test$;

rollback;
select 'category_visual_metadata_tests = ok' as result;
