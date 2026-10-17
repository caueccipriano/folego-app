create or replace function private.protect_system_category()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if current_user = 'authenticated' and (
      new.is_system
      or new.system_key is not null
      or new.category_role <> 'economic'
    ) then
      raise exception 'custom_category_cannot_claim_system_identity';
    end if;
    return new;
  end if;

  if tg_op = 'DELETE' then
    if old.is_system then
      raise exception 'system_category_cannot_be_deleted';
    end if;
    return old;
  end if;

  if current_user = 'authenticated' and not old.is_system and (
    new.is_system
    or new.system_key is not null
    or new.category_role <> 'economic'
  ) then
    raise exception 'custom_category_cannot_claim_system_identity';
  end if;

  if old.is_system and (
    new.space_id is distinct from old.space_id or
    new.kind is distinct from old.kind or
    new.parent_id is distinct from old.parent_id or
    new.system_key is distinct from old.system_key or
    new.is_system is distinct from old.is_system or
    new.category_role is distinct from old.category_role
  ) then
    raise exception 'system_category_identity_cannot_be_changed';
  end if;

  return new;
end;
$$;

drop trigger if exists categories_protect_system on public.categories;
create trigger categories_protect_system
before insert or update or delete on public.categories
for each row execute function private.protect_system_category();

create or replace function public.create_custom_category(
  p_space_id uuid,
  p_name text,
  p_kind text,
  p_parent_id uuid default null,
  p_essential boolean default false,
  p_color_hex text default '#8C8CA8',
  p_search_aliases text[] default '{}'::text[]
)
returns uuid
language plpgsql
set search_path = ''
as $$
declare
  v_id uuid;
begin
  if auth.uid() is null or not private.can_write_space(p_space_id) then
    raise exception 'write_access_denied';
  end if;
  if p_kind not in ('expense','income') then raise exception 'invalid_category_kind'; end if;
  if nullif(btrim(p_name),'') is null then raise exception 'category_name_required'; end if;

  if p_parent_id is not null and not exists(
    select 1 from public.categories p
    where p.id=p_parent_id and p.space_id=p_space_id and p.kind=p_kind
      and p.parent_id is null and p.active and p.category_role='economic'
  ) then raise exception 'invalid_parent_category'; end if;

  insert into public.categories(
    space_id,name,kind,parent_id,essential,active,color_hex,
    is_system,system_key,category_role,is_selectable,search_aliases,sort_order
  ) values (
    p_space_id,btrim(p_name),p_kind,p_parent_id,p_essential,true,coalesce(nullif(btrim(p_color_hex),''),'#8C8CA8'),
    false,null,'economic',true,coalesce(p_search_aliases,'{}'::text[]),900
  ) returning id into v_id;

  return v_id;
end;
$$;
grant execute on function public.create_custom_category(uuid,text,text,uuid,boolean,text,text[]) to authenticated;

create or replace function public.rename_custom_category(
  p_space_id uuid,
  p_category_id uuid,
  p_name text
)
returns void
language plpgsql
set search_path = ''
as $$
begin
  if auth.uid() is null or not private.can_write_space(p_space_id) then raise exception 'write_access_denied'; end if;
  if nullif(btrim(p_name),'') is null then raise exception 'category_name_required'; end if;
  update public.categories
  set name=btrim(p_name),updated_at=now()
  where id=p_category_id and space_id=p_space_id and not is_system and category_role='economic';
  if not found then raise exception 'custom_category_not_found'; end if;
end;
$$;
grant execute on function public.rename_custom_category(uuid,uuid,text) to authenticated;

create or replace function public.set_category_visibility(
  p_space_id uuid,
  p_category_id uuid,
  p_active boolean
)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_parent_id uuid;
begin
  if auth.uid() is null or not private.can_write_space(p_space_id) then raise exception 'write_access_denied'; end if;

  select parent_id into v_parent_id
  from public.categories
  where id=p_category_id and space_id=p_space_id and category_role='economic';
  if not found then raise exception 'category_not_found'; end if;

  update public.categories set active=p_active,updated_at=now()
  where id=p_category_id and space_id=p_space_id;

  if v_parent_id is null and not p_active then
    update public.categories set active=false,updated_at=now()
    where parent_id=p_category_id and space_id=p_space_id;
  end if;
end;
$$;
grant execute on function public.set_category_visibility(uuid,uuid,boolean) to authenticated;
