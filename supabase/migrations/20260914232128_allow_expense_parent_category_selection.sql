create or replace function private.normalize_expense_parent_selection(p_space_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.categories
  set is_selectable = true,
      updated_at = now()
  where space_id = p_space_id
    and kind = 'expense'
    and category_role = 'economic'
    and parent_id is null
    and active;
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
  perform private.normalize_expense_parent_selection(new.id);
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
  perform private.normalize_expense_parent_selection(p_space_id);
  perform set_config('app.system_category_write','0',true);
end;
$$;

do $$ declare s record; begin
  perform set_config('app.system_category_write','1',true);
  for s in select id from public.financial_spaces loop
    perform private.normalize_expense_parent_selection(s.id);
  end loop;
  perform set_config('app.system_category_write','0',true);
end $$;
