create or replace function private.normalize_internal_category_visibility(p_space_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform set_config('app.system_category_write','1',true);

  update public.categories
  set active = true,
      is_selectable = false,
      category_role = 'group',
      updated_at = now()
  where space_id = p_space_id
    and system_key = 'income.root';

  update public.categories
  set active = true,
      is_selectable = false,
      category_role = 'pending',
      updated_at = now()
  where space_id = p_space_id
    and system_key = 'special.unclassified';

  perform set_config('app.system_category_write','0',true);
end;
$$;

do $$ declare s record; begin
  for s in select id from public.financial_spaces loop
    perform private.normalize_internal_category_visibility(s.id);
  end loop;
end $$;
