alter table public.categories
add column if not exists icon_key text;

alter table public.categories
  drop constraint if exists categories_icon_key_valid;

alter table public.categories
  add constraint categories_icon_key_valid check (
    icon_key is null or icon_key = any (array[
      'food','groceries','restaurant','delivery','coffee',
      'transport','fuel','ride','bus','parking',
      'home','rent','building','maintenance','furniture',
      'bills','energy','water','internet','phone',
      'shopping','clothing','electronics','marketplace',
      'leisure','cinema','event','games',
      'health','pharmacy','doctor','fitness',
      'education','course','books','work',
      'finance','bank','cash','debt','subscription',
      'travel','pets','gift','family','beauty','insurance','services',
      'income','other'
    ]::text[])
  );

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
    new.icon_key is distinct from old.icon_key or
    new.is_selectable is distinct from old.is_selectable or
    new.search_aliases is distinct from old.search_aliases or
    new.sort_order is distinct from old.sort_order
  ) then
    raise exception 'system_category_content_cannot_be_changed';
  end if;

  return new;
end;
$$;

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
  icon_key text,
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
    c.icon_key,
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
    c.is_selectable,c.color_hex,c.icon_key,c.system_key,c.category_role,
    c.search_aliases,c.sort_order
  order by c.sort_order,c.name;
end;
$$;

grant execute on function public.get_category_catalog(uuid,text) to authenticated;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'categories'
  ) then
    alter publication supabase_realtime add table public.categories;
  end if;
end
$$;
