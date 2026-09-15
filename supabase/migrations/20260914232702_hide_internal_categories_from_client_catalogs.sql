do $$
begin
  alter table public.categories drop constraint if exists categories_role_check;
  alter table public.categories
    add constraint categories_role_check
    check (category_role in ('economic','group','movement','pending','legacy'));
end $$;

create or replace function private.normalize_internal_category_visibility(p_space_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform set_config('app.system_category_write','1',true);

  update public.categories
  set active = false,
      is_selectable = false,
      category_role = 'group',
      updated_at = now()
  where space_id = p_space_id
    and system_key = 'income.root';

  update public.categories
  set active = false,
      is_selectable = false,
      category_role = 'pending',
      updated_at = now()
  where space_id = p_space_id
    and system_key = 'special.unclassified';

  perform set_config('app.system_category_write','0',true);
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
  perform private.normalize_expense_parent_selection(new.id);
  perform private.normalize_internal_category_visibility(new.id);
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
  if auth.uid() is null or not private.can_write_space(p_space_id) then
    raise exception 'write_access_denied';
  end if;
  perform set_config('app.system_category_write','1',true);
  perform private.seed_universal_taxonomy(p_space_id);
  perform private.normalize_expense_parent_selection(p_space_id);
  perform private.normalize_internal_category_visibility(p_space_id);
  perform set_config('app.system_category_write','0',true);
end;
$$;

create or replace function public.get_category_catalog(p_space_id uuid, p_kind text)
returns table(
  id uuid,
  name text,
  kind text,
  parent_id uuid,
  parent_name text,
  essential boolean,
  is_system boolean,
  is_selectable boolean,
  search_aliases text[],
  sort_order integer,
  usage_count bigint,
  last_used_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or not private.is_space_member(p_space_id) then
    raise exception 'access_denied';
  end if;
  if p_kind not in ('expense','income') then
    raise exception 'invalid_category_kind';
  end if;

  return query
  select c.id,c.name,c.kind,c.parent_id,p.name,c.essential,c.is_system,c.is_selectable,
         c.search_aliases,c.sort_order,count(e.id),max(e.occurred_at)
  from public.categories c
  left join public.categories p on p.id=c.parent_id and p.space_id=c.space_id
  left join public.financial_events e
    on e.space_id=c.space_id and e.category_id=c.id and e.status='confirmed'
  where c.space_id=p_space_id
    and c.kind=p_kind
    and c.active
    and c.category_role='economic'
    and (
      c.parent_id is null
      or (
        p.category_role in ('economic','group')
        and (p.active or p.system_key='income.root')
      )
    )
  group by c.id,c.name,c.kind,c.parent_id,p.name,c.essential,c.is_system,c.is_selectable,c.search_aliases,c.sort_order
  order by c.sort_order,c.name;
end;
$$;

grant execute on function public.get_category_catalog(uuid,text) to authenticated;

drop policy if exists categories_select_member on public.categories;
create policy categories_select_member
on public.categories
for select
to authenticated
using (
  (select private.is_space_member(categories.space_id))
  and categories.category_role = 'economic'
);

do $$ declare s record; begin
  for s in select id from public.financial_spaces loop
    perform private.normalize_internal_category_visibility(s.id);
  end loop;
end $$;
