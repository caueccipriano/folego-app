drop function if exists public.get_category_catalog(uuid,text);

create function public.get_category_catalog(p_space_id uuid, p_kind text)
returns table(
  id uuid,
  name text,
  kind text,
  parent_id uuid,
  parent_name text,
  essential boolean,
  is_system boolean,
  is_selectable boolean,
  color_hex text,
  system_key text,
  category_role text,
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
  select
    c.id,
    c.name,
    c.kind,
    c.parent_id,
    p.name as parent_name,
    c.essential,
    c.is_system,
    c.is_selectable,
    c.color_hex,
    c.system_key,
    c.category_role,
    c.search_aliases,
    c.sort_order,
    count(e.id) as usage_count,
    max(e.occurred_at) as last_used_at
  from public.categories c
  left join public.categories p
    on p.id = c.parent_id
   and p.space_id = c.space_id
  left join public.financial_events e
    on e.space_id = c.space_id
   and e.category_id = c.id
   and e.status = 'confirmed'
  where c.space_id = p_space_id
    and c.kind = p_kind
    and c.active
    and c.category_role = 'economic'
    and (
      c.parent_id is null
      or (
        p.category_role in ('economic','group')
        and (p.active or p.system_key = 'income.root')
      )
    )
  group by
    c.id,c.name,c.kind,c.parent_id,p.name,c.essential,c.is_system,
    c.is_selectable,c.color_hex,c.system_key,c.category_role,c.search_aliases,c.sort_order
  order by c.sort_order,c.name;
end;
$$;

grant execute on function public.get_category_catalog(uuid,text) to authenticated;
