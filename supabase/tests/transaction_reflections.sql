-- Transaction reflection RLS and behavioral-layer regression tests.
-- Runs inside a transaction and rolls back every fixture.

begin;

create temp table diary_test_context (
  owner_id uuid,
  viewer_id uuid,
  nonmember_id uuid,
  space_id uuid,
  event_id uuid,
  category_id uuid
) on commit drop;

grant select on diary_test_context to authenticated;

do $setup$
declare
  v_owner uuid;
  v_viewer uuid := gen_random_uuid();
  v_nonmember uuid := gen_random_uuid();
  v_space uuid := gen_random_uuid();
  v_event uuid := gen_random_uuid();
  v_category uuid := gen_random_uuid();
  v_instance uuid;
begin
  select id, instance_id into v_owner, v_instance
  from auth.users
  order by created_at
  limit 1;

  if v_owner is null then
    raise exception 'diary_test_requires_existing_user';
  end if;

  insert into auth.users(
    instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
    raw_app_meta_data,raw_user_meta_data,created_at,updated_at,is_sso_user,is_anonymous
  ) values (
    v_instance,v_viewer,'authenticated','authenticated',
    'diary-viewer-' || v_viewer::text || '@example.invalid','',now(),
    '{}'::jsonb,'{}'::jsonb,now(),now(),false,false
  );

  insert into public.financial_spaces(id,owner_id,name,type,currency,timezone)
  values(v_space,v_owner,'Diary RLS test','personal','BRL','America/Sao_Paulo');

  insert into public.space_members(space_id,user_id,role)
  values(v_space,v_owner,'owner')
  on conflict(space_id,user_id) do update set role='owner';

  insert into public.space_members(space_id,user_id,role)
  values(v_space,v_viewer,'viewer')
  on conflict(space_id,user_id) do update set role='viewer';

  insert into public.categories(id,space_id,name,kind,essential,active)
  values(v_category,v_space,'Diary expense test','expense',false,true);

  insert into public.financial_events(
    id,space_id,event_type,description,amount,currency,occurred_at,
    competence_date,category_id,status,source
  ) values (
    v_event,v_space,'expense','Diary test expense',100,'BRL',now(),
    current_date,v_category,'confirmed','manual'
  );

  insert into diary_test_context
  values(v_owner,v_viewer,v_nonmember,v_space,v_event,v_category);
end;
$setup$;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  (select owner_id::text from diary_test_context),
  true
);

do $owner_tests$
declare
  v_space uuid := (select space_id from diary_test_context);
  v_event uuid := (select event_id from diary_test_context);
  v_count integer;
begin
  insert into public.transaction_reflections(space_id,event_id,reflection_type,note)
  values(v_space,v_event,'necessary',null);

  if not exists (
    select 1 from public.transaction_reflections
    where space_id=v_space and event_id=v_event and note is null
  ) then raise exception 'note_nullable_failed'; end if;

  begin
    insert into public.transaction_reflections(space_id,event_id,reflection_type)
    values(v_space,v_event,'want');
    raise exception 'duplicate_reflection_was_accepted';
  exception
    when unique_violation then null;
  end;

  begin
    update public.transaction_reflections
    set reflection_type='moralized_bad'
    where space_id=v_space and event_id=v_event;
    raise exception 'invalid_reflection_type_was_accepted';
  exception
    when check_violation then null;
  end;

  begin
    update public.transaction_reflections
    set note=repeat('x',301)
    where space_id=v_space and event_id=v_event;
    raise exception 'long_note_was_accepted';
  exception
    when check_violation then null;
  end;

  update public.transaction_reflections
  set reflection_type='want',note='sem julgamento'
  where space_id=v_space and event_id=v_event;

  if not exists (
    select 1 from public.transaction_reflections
    where space_id=v_space and event_id=v_event
      and reflection_type='want' and note='sem julgamento'
  ) then raise exception 'writer_update_failed'; end if;

  select count(*) into v_count
  from public.financial_impacts
  where space_id=v_space and event_id=v_event;
  if v_count <> 0 then raise exception 'reflection_created_financial_impacts'; end if;
end;
$owner_tests$;

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  (select viewer_id::text from diary_test_context),
  true
);

do $viewer_tests$
declare
  v_space uuid := (select space_id from diary_test_context);
  v_event uuid := (select event_id from diary_test_context);
  v_count integer;
begin
  select count(*) into v_count
  from public.transaction_reflections
  where space_id=v_space and event_id=v_event;
  if v_count <> 1 then raise exception 'viewer_cannot_read'; end if;

  update public.transaction_reflections
  set note='viewer should not write'
  where space_id=v_space and event_id=v_event;

  if exists (
    select 1 from public.transaction_reflections
    where space_id=v_space and event_id=v_event
      and note='viewer should not write'
  ) then raise exception 'viewer_write_was_allowed'; end if;
end;
$viewer_tests$;

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  (select nonmember_id::text from diary_test_context),
  true
);

do $nonmember_tests$
declare
  v_space uuid := (select space_id from diary_test_context);
  v_count integer;
begin
  select count(*) into v_count
  from public.transaction_reflections
  where space_id=v_space;
  if v_count <> 0 then raise exception 'nonmember_read_was_allowed'; end if;
end;
$nonmember_tests$;

reset role;
rollback;
