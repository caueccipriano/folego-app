create or replace function private.protect_system_category()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_authenticated boolean := coalesce(auth.role(),'') = 'authenticated';
  v_internal boolean := coalesce(current_setting('app.system_category_write', true),'') = '1';
begin
  if tg_op = 'INSERT' then
    if v_authenticated and not v_internal and (
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

  if v_authenticated and not v_internal and not old.is_system and (
    new.is_system
    or new.system_key is not null
    or new.category_role <> 'economic'
  ) then
    raise exception 'custom_category_cannot_claim_system_identity';
  end if;

  if old.is_system and not v_internal and (
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

create or replace function private.seed_default_categories()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform set_config('app.system_category_write','1',true);
  perform private.seed_universal_taxonomy(new.id);
  perform set_config('app.system_category_write','0',true);
  return new;
end;
$$;

create or replace function public.ensure_app_categories(p_space_id uuid)
returns void
language plpgsql
set search_path = ''
as $$
begin
  if auth.uid() is null or not private.can_write_space(p_space_id) then raise exception 'write_access_denied'; end if;
  perform set_config('app.system_category_write','1',true);
  perform private.seed_universal_taxonomy(p_space_id);
  perform set_config('app.system_category_write','0',true);
end;
$$;
