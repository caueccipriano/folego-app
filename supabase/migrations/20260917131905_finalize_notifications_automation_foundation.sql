-- Applied to Supabase Dev as 20260917131905_finalize_notifications_automation_foundation.
-- Final idempotent reconciliation for Notifications + Automation Foundation 1.0.

create index if not exists import_rows_automation_rule_id_idx
  on public.import_rows(automation_rule_id)
  where automation_rule_id is not null;

create or replace function private.guard_automation_rule_update()
returns trigger
language plpgsql
security invoker
set search_path to ''
as $function$
begin
  if new.space_id is distinct from old.space_id then
    raise exception 'automation_rule_space_immutable';
  end if;
  if new.created_by is distinct from old.created_by then
    raise exception 'automation_rule_creator_immutable';
  end if;
  new.updated_at := now();
  return new;
end;
$function$;

revoke all on function private.guard_automation_rule_update() from public, anon, authenticated;

do $trigger$
begin
  if not exists (
    select 1
    from pg_trigger
    where tgname = 'automation_rules_guard_update'
      and tgrelid = 'public.automation_rules'::regclass
      and not tgisinternal
  ) then
    create trigger automation_rules_guard_update
    before update on public.automation_rules
    for each row execute function private.guard_automation_rule_update();
  end if;
end
$trigger$;

create or replace function public.get_notification_upcoming_events(
  p_space_id uuid,
  p_offset_days smallint default 1,
  p_preferred_time time default '09:00',
  p_horizon_days integer default 30,
  p_limit integer default 200
)
returns table(
  event_key text,
  source text,
  source_id uuid,
  parent_id uuid,
  title text,
  subtitle text,
  due_date date,
  amount numeric,
  direction text,
  status text,
  category_id uuid,
  account_id uuid,
  card_id uuid,
  debt_id uuid,
  overdue boolean,
  realized boolean,
  recurring boolean,
  installment_number integer,
  installment_count integer,
  invoice_id uuid,
  navigation_target text,
  day_offset integer,
  cash_obligation boolean,
  recurrence_kind text,
  scheduled_at timestamptz,
  space_timezone text
)
language plpgsql
stable
security invoker
set search_path to ''
as $function$
declare
  v_timezone text;
  v_today date;
  v_horizon integer;
begin
  if auth.uid() is null or not private.is_space_member(p_space_id) then
    raise exception 'read_access_denied' using errcode = '42501';
  end if;
  if p_offset_days not in (0, 1, 3) then
    raise exception 'invalid_notification_offset';
  end if;
  v_horizon := least(greatest(coalesce(p_horizon_days, 30), 1), 30);
  select fs.timezone into v_timezone
  from public.financial_spaces fs
  where fs.id = p_space_id;
  if v_timezone is null then raise exception 'financial_space_not_found'; end if;
  v_today := (now() at time zone v_timezone)::date;
  return query
  select
    e.event_key,e.source,e.source_id,e.parent_id,e.title,e.subtitle,e.due_date,
    e.amount,e.direction,e.status,e.category_id,e.account_id,e.card_id,e.debt_id,
    e.overdue,e.realized,e.recurring,e.installment_number,e.installment_count,
    e.invoice_id,e.navigation_target,e.day_offset,e.cash_obligation,
    case when e.source = 'recurring' then r.recurrence_kind else null end,
    greatest(
      ((greatest(v_today, e.due_date - p_offset_days)::timestamp + p_preferred_time)
        at time zone v_timezone),
      now() + interval '1 minute'
    ),
    v_timezone
  from public.get_upcoming_events(
    p_space_id,
    v_today - 30,
    v_today + (v_horizon - 1),
    least(greatest(coalesce(p_limit, 200), 1), 200)
  ) e
  left join public.recurring_items r
    on e.source = 'recurring'
   and r.id = e.source_id
   and r.space_id = p_space_id
  where e.due_date <= v_today + (v_horizon - 1)
  order by e.due_date, e.title, e.event_key;
end;
$function$;

revoke all on function public.get_notification_upcoming_events(uuid,smallint,time,integer,integer)
from public, anon;
grant execute on function public.get_notification_upcoming_events(uuid,smallint,time,integer,integer)
to authenticated;
