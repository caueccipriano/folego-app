-- Plano 2.0: recurring monthly limits + explicit monthly overrides.
-- Recurring budget rules are independent from recurring income/expense items.

create table if not exists public.budget_recurring_rules (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.financial_spaces(id) on delete cascade,
  category_id uuid not null,
  planned_amount numeric not null check (planned_amount > 0),
  warning_threshold numeric not null default 0.70
    check (warning_threshold > 0 and warning_threshold <= 1),
  critical_threshold numeric not null default 0.90
    check (
      critical_threshold > 0
      and critical_threshold <= 1
      and critical_threshold >= warning_threshold
    ),
  effective_from date not null
    check (extract(day from effective_from) = 1),
  effective_until date null
    check (
      effective_until is null
      or (
        extract(day from effective_until) = 1
        and effective_until >= effective_from
      )
    ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint budget_recurring_rules_space_category_from_key
    unique (space_id, category_id),
  constraint budget_recurring_rules_category_fk
    foreign key (category_id, space_id)
    references public.categories(id, space_id)
    on delete restrict
);

-- The live project originally used one row per version start. Keep that shape
-- if this migration is replayed after direct deployment.
alter table public.budget_recurring_rules
  drop constraint if exists budget_recurring_rules_space_category_from_key;

alter table public.budget_recurring_rules
  add constraint budget_recurring_rules_space_category_from_key
  unique (space_id, category_id, effective_from);

create index if not exists budget_recurring_rules_lookup_idx
  on public.budget_recurring_rules(
    space_id,
    category_id,
    effective_from desc,
    effective_until
  );

alter table public.budget_recurring_rules enable row level security;

revoke all on public.budget_recurring_rules from anon;
revoke insert, update, delete on public.budget_recurring_rules from authenticated;
grant select on public.budget_recurring_rules to authenticated;
grant all on public.budget_recurring_rules to service_role;

drop policy if exists budget_recurring_rules_select_member
  on public.budget_recurring_rules;
create policy budget_recurring_rules_select_member
  on public.budget_recurring_rules
  for select
  to authenticated
  using ((select private.is_space_member(space_id)));

create or replace function private.onboarding_set_budget_item_impl(
  p_space_id uuid,
  p_period_month date,
  p_category_id uuid,
  p_planned_amount numeric,
  p_warning_threshold numeric default 0.70,
  p_critical_threshold numeric default 0.90
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_budget_id uuid;
  v_item_id uuid;
  v_month date;
begin
  if not private.can_write_space(p_space_id) then
    raise exception 'Not allowed to write this financial space' using errcode='42501';
  end if;

  if p_planned_amount < 0 then
    raise exception 'Budget amount cannot be negative';
  end if;

  if p_warning_threshold <= 0
     or p_warning_threshold > 1
     or p_critical_threshold <= 0
     or p_critical_threshold > 1
     or p_critical_threshold < p_warning_threshold then
    raise exception 'Invalid budget thresholds';
  end if;

  if not exists(
    select 1
    from public.categories c
    where c.id = p_category_id
      and c.space_id = p_space_id
      and c.kind = 'expense'
      and c.active
      and c.category_role = 'economic'
      and c.parent_id is not null
  ) then
    raise exception 'Budget requires an expense subcategory';
  end if;

  v_month := date_trunc('month', p_period_month)::date;

  insert into public.budgets(space_id, period_month, status)
  values(p_space_id, v_month, 'active')
  on conflict(space_id, period_month)
  do update set status = 'active', updated_at = now()
  returning id into v_budget_id;

  insert into public.budget_items(
    space_id,
    budget_id,
    category_id,
    planned_amount,
    warning_threshold,
    critical_threshold
  )
  values(
    p_space_id,
    v_budget_id,
    p_category_id,
    p_planned_amount,
    p_warning_threshold,
    p_critical_threshold
  )
  on conflict(budget_id, category_id)
  do update set
    planned_amount = excluded.planned_amount,
    warning_threshold = excluded.warning_threshold,
    critical_threshold = excluded.critical_threshold,
    updated_at = now()
  returning id into v_item_id;

  return v_item_id;
end;
$function$;

create or replace function private.set_budget_limit_impl(
  p_space_id uuid,
  p_period_month date,
  p_category_id uuid,
  p_planned_amount numeric,
  p_scope text,
  p_warning_threshold numeric default 0.70,
  p_critical_threshold numeric default 0.90
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_month date := date_trunc('month', p_period_month)::date;
  v_current_month date;
  v_previous_month date;
  v_budget_id uuid;
  v_has_recurring boolean := false;
begin
  if auth.uid() is null then
    raise exception 'authentication_required';
  end if;

  if not private.can_write_space(p_space_id) then
    raise exception 'write_access_denied' using errcode='42501';
  end if;

  if p_planned_amount is null or p_planned_amount < 0 then
    raise exception 'budget_amount_cannot_be_negative';
  end if;

  if p_scope not in ('month', 'from_month', 'cancel_from_month') then
    raise exception 'invalid_budget_scope';
  end if;

  if p_warning_threshold <= 0
     or p_warning_threshold > 1
     or p_critical_threshold <= 0
     or p_critical_threshold > 1
     or p_critical_threshold < p_warning_threshold then
    raise exception 'invalid_budget_thresholds';
  end if;

  if not exists(
    select 1
    from public.categories c
    where c.id = p_category_id
      and c.space_id = p_space_id
      and c.kind = 'expense'
      and c.active
      and c.category_role = 'economic'
      and c.parent_id is not null
  ) then
    raise exception 'budget_requires_subcategory';
  end if;

  select date_trunc(
           'month',
           (now() at time zone coalesce(fs.timezone, 'America/Sao_Paulo'))::date
         )::date
    into v_current_month
  from public.financial_spaces fs
  where fs.id = p_space_id;

  if p_scope in ('from_month', 'cancel_from_month')
     and v_month < v_current_month then
    raise exception 'historical_recurring_budget_is_immutable';
  end if;

  select exists(
    select 1
    from public.budget_recurring_rules r
    where r.space_id = p_space_id
      and r.category_id = p_category_id
      and r.effective_from <= v_month
      and (r.effective_until is null or r.effective_until >= v_month)
  ) into v_has_recurring;

  if p_scope = 'month' then
    if p_planned_amount = 0 and not v_has_recurring then
      delete from public.budget_items bi
      using public.budgets b
      where bi.budget_id = b.id
        and bi.space_id = p_space_id
        and b.space_id = p_space_id
        and b.period_month = v_month
        and bi.category_id = p_category_id;
      return true;
    end if;

    insert into public.budgets(space_id, period_month, status)
    values(p_space_id, v_month, 'active')
    on conflict(space_id, period_month)
    do update set status = 'active', updated_at = now()
    returning id into v_budget_id;

    insert into public.budget_items(
      space_id,
      budget_id,
      category_id,
      planned_amount,
      warning_threshold,
      critical_threshold
    )
    values(
      p_space_id,
      v_budget_id,
      p_category_id,
      p_planned_amount,
      p_warning_threshold,
      p_critical_threshold
    )
    on conflict(budget_id, category_id)
    do update set
      planned_amount = excluded.planned_amount,
      warning_threshold = excluded.warning_threshold,
      critical_threshold = excluded.critical_threshold,
      updated_at = now();

    return true;
  end if;

  v_previous_month := (v_month - interval '1 month')::date;

  delete from public.budget_recurring_rules r
  where r.space_id = p_space_id
    and r.category_id = p_category_id
    and r.effective_from >= v_month;

  update public.budget_recurring_rules r
  set effective_until = v_previous_month,
      updated_at = now()
  where r.space_id = p_space_id
    and r.category_id = p_category_id
    and r.effective_from < v_month
    and (r.effective_until is null or r.effective_until >= v_month);

  if p_scope = 'cancel_from_month' then
    return true;
  end if;

  if p_planned_amount <= 0 then
    raise exception 'recurring_budget_amount_must_be_positive';
  end if;

  insert into public.budget_recurring_rules(
    space_id,
    category_id,
    planned_amount,
    warning_threshold,
    critical_threshold,
    effective_from,
    effective_until
  )
  values(
    p_space_id,
    p_category_id,
    p_planned_amount,
    p_warning_threshold,
    p_critical_threshold,
    v_month,
    null
  );

  -- Keep the starting month compatible with existing monthly budget consumers
  -- without materializing any future months.
  insert into public.budgets(space_id, period_month, status)
  values(p_space_id, v_month, 'active')
  on conflict(space_id, period_month)
  do update set status = 'active', updated_at = now()
  returning id into v_budget_id;

  insert into public.budget_items(
    space_id,
    budget_id,
    category_id,
    planned_amount,
    warning_threshold,
    critical_threshold
  )
  values(
    p_space_id,
    v_budget_id,
    p_category_id,
    p_planned_amount,
    p_warning_threshold,
    p_critical_threshold
  )
  on conflict(budget_id, category_id)
  do update set
    planned_amount = excluded.planned_amount,
    warning_threshold = excluded.warning_threshold,
    critical_threshold = excluded.critical_threshold,
    updated_at = now();

  return true;
end;
$function$;

create or replace function public.set_budget_limit(
  p_space_id uuid,
  p_period_month date,
  p_category_id uuid,
  p_planned_amount numeric,
  p_scope text,
  p_warning_threshold numeric default 0.70,
  p_critical_threshold numeric default 0.90
)
returns boolean
language sql
set search_path = ''
as $function$
  select private.set_budget_limit_impl($1, $2, $3, $4, $5, $6, $7);
$function$;

drop function if exists public.get_budget_overview(uuid, date);

create function public.get_budget_overview(
  p_space_id uuid,
  p_period_month date
)
returns table(
  category_id uuid,
  category_name text,
  parent_id uuid,
  parent_name text,
  color_hex text,
  essential boolean,
  planned_amount numeric,
  actual_amount numeric,
  remaining_amount numeric,
  warning_threshold numeric,
  critical_threshold numeric,
  usage_ratio numeric,
  status text,
  budget_source text,
  is_recurring boolean
)
language sql
stable
set search_path = ''
as $function$
with access as (
  select private.is_space_member(p_space_id) as allowed
),
period as (
  select date_trunc('month', p_period_month)::date as month_start,
         (date_trunc('month', p_period_month) + interval '1 month')::date as next_month
),
selected_budget as (
  select b.id
  from public.budgets b, period p, access a
  where a.allowed
    and b.space_id = p_space_id
    and b.period_month = p.month_start
  order by b.created_at desc
  limit 1
),
monthly_values as (
  select bi.category_id,
         bi.planned_amount,
         bi.warning_threshold,
         bi.critical_threshold
  from public.budget_items bi
  join selected_budget sb on sb.id = bi.budget_id
  where bi.space_id = p_space_id
),
recurring_values as (
  select distinct on (r.category_id)
    r.category_id,
    r.planned_amount,
    r.warning_threshold,
    r.critical_threshold,
    r.id
  from public.budget_recurring_rules r
  cross join period p
  cross join access a
  where a.allowed
    and r.space_id = p_space_id
    and r.effective_from <= p.month_start
    and (r.effective_until is null or r.effective_until >= p.month_start)
  order by r.category_id, r.effective_from desc, r.created_at desc
),
effective_values as (
  select c.id as category_id,
    case
      when mv.category_id is not null then mv.planned_amount
      else coalesce(rv.planned_amount, 0::numeric)
    end as planned_amount,
    case
      when mv.category_id is not null then mv.warning_threshold
      else coalesce(rv.warning_threshold, 0.70::numeric)
    end as warning_threshold,
    case
      when mv.category_id is not null then mv.critical_threshold
      else coalesce(rv.critical_threshold, 0.90::numeric)
    end as critical_threshold,
    case
      when mv.category_id is not null and rv.category_id is not null then 'override'::text
      when mv.category_id is not null then 'month'::text
      when rv.category_id is not null then 'recurring'::text
      else 'none'::text
    end as budget_source,
    (rv.category_id is not null) as is_recurring
  from public.categories c
  left join monthly_values mv on mv.category_id = c.id
  left join recurring_values rv on rv.category_id = c.id
  cross join access a
  where a.allowed
    and c.space_id = p_space_id
    and c.kind = 'expense'
    and c.active
    and c.category_role = 'economic'
),
actuals_direct as (
  select coalesce(i.category_id, e.category_id) as category_id,
         greatest(0::numeric, -sum(i.amount)) as actual_amount
  from public.financial_impacts i
  join public.financial_events e
    on e.id = i.event_id
   and e.space_id = i.space_id
  cross join period p
  cross join access a
  where a.allowed
    and i.space_id = p_space_id
    and i.dimension = 'budget'
    and i.effective_date >= p.month_start
    and i.effective_date < p.next_month
    and e.status = 'confirmed'
    and coalesce(i.category_id, e.category_id) is not null
  group by coalesce(i.category_id, e.category_id)
),
rows as (
  select c.id as category_id,
         c.name as category_name,
         c.parent_id,
         pc.name as parent_name,
         c.color_hex,
         c.essential,
         case
           when c.parent_id is null then coalesce((
             select sum(ev_child.planned_amount)
             from public.categories child
             join effective_values ev_child on ev_child.category_id = child.id
             where child.space_id = p_space_id
               and child.parent_id = c.id
               and child.active
               and child.category_role = 'economic'
           ), 0::numeric)
           else coalesce(ev.planned_amount, 0::numeric)
         end as planned_amount,
         (
           coalesce(ad.actual_amount, 0::numeric)
           + case
               when c.parent_id is null then coalesce((
                 select sum(child_actual.actual_amount)
                 from public.categories child
                 join actuals_direct child_actual
                   on child_actual.category_id = child.id
                 where child.space_id = p_space_id
                   and child.parent_id = c.id
                   and child.active
                   and child.category_role = 'economic'
               ), 0::numeric)
               else 0::numeric
             end
         ) as actual_amount,
         case
           when c.parent_id is null then 0.70::numeric
           else coalesce(ev.warning_threshold, 0.70::numeric)
         end as warning_threshold,
         case
           when c.parent_id is null then 0.90::numeric
           else coalesce(ev.critical_threshold, 0.90::numeric)
         end as critical_threshold,
         case
           when c.parent_id is null then 'aggregate'::text
           else coalesce(ev.budget_source, 'none'::text)
         end as budget_source,
         case
           when c.parent_id is null then false
           else coalesce(ev.is_recurring, false)
         end as is_recurring
  from public.categories c
  left join public.categories pc
    on pc.id = c.parent_id
   and pc.space_id = c.space_id
  left join effective_values ev on ev.category_id = c.id
  left join actuals_direct ad on ad.category_id = c.id
  cross join access a
  where a.allowed
    and c.space_id = p_space_id
    and c.kind = 'expense'
    and c.active
    and c.category_role = 'economic'
)
select r.category_id,
       r.category_name,
       r.parent_id,
       r.parent_name,
       r.color_hex,
       r.essential,
       r.planned_amount,
       r.actual_amount,
       (r.planned_amount - r.actual_amount) as remaining_amount,
       r.warning_threshold,
       r.critical_threshold,
       case
         when r.planned_amount > 0 then r.actual_amount / r.planned_amount
         else 0::numeric
       end as usage_ratio,
       case
         when r.planned_amount <= 0 then 'none'::text
         when (r.actual_amount / r.planned_amount) > 1 then 'exceeded'::text
         when (r.actual_amount / r.planned_amount) >= r.warning_threshold then 'warning'::text
         else 'ok'::text
       end as status,
       r.budget_source,
       r.is_recurring
from rows r
order by
  coalesce(r.parent_name, r.category_name),
  case when r.parent_id is null then 0 else 1 end,
  r.category_name;
$function$;

revoke execute on function private.set_budget_limit_impl(
  uuid, date, uuid, numeric, text, numeric, numeric
) from public, anon;
grant execute on function private.set_budget_limit_impl(
  uuid, date, uuid, numeric, text, numeric, numeric
) to authenticated, service_role;

revoke execute on function private.onboarding_set_budget_item_impl(
  uuid, date, uuid, numeric, numeric, numeric
) from public, anon;
grant execute on function private.onboarding_set_budget_item_impl(
  uuid, date, uuid, numeric, numeric, numeric
) to authenticated, service_role;

revoke execute on function public.set_budget_limit(
  uuid, date, uuid, numeric, text, numeric, numeric
) from public, anon;
grant execute on function public.set_budget_limit(
  uuid, date, uuid, numeric, text, numeric, numeric
) to authenticated, service_role;

revoke execute on function public.get_budget_overview(uuid, date)
  from public, anon;
grant execute on function public.get_budget_overview(uuid, date)
  to authenticated, service_role;
