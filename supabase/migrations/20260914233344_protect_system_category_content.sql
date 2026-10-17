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

  if old.is_system and v_authenticated and not v_internal and (
    new.name is distinct from old.name or
    new.essential is distinct from old.essential or
    new.color_hex is distinct from old.color_hex or
    new.is_selectable is distinct from old.is_selectable or
    new.search_aliases is distinct from old.search_aliases or
    new.sort_order is distinct from old.sort_order
  ) then
    raise exception 'system_category_content_cannot_be_changed';
  end if;

  return new;
end;
$$;
