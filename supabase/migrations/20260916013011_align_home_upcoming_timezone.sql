-- Applied to Supabase Dev as 20260916013011_align_home_upcoming_timezone.
-- The legacy Home signature now delegates its date window to the space-timezone-aware Agenda source.

create or replace function public.get_upcoming_events(
  p_space_id uuid,
  p_from date,
  p_until date
)
returns table(
  id uuid,
  source text,
  name text,
  due_date date,
  amount numeric,
  direction text,
  category_id uuid,
  status text
)
language sql
stable
security invoker
set search_path to ''
as $function$
  select
    e.source_id as id,
    e.source,
    e.title as name,
    e.due_date,
    e.amount,
    case when e.direction = 'income' then 'income' else 'expense' end as direction,
    e.category_id,
    e.status
  from public.get_upcoming_events(p_space_id, null, null, 120) e;
$function$;

revoke all on function public.get_upcoming_events(uuid,date,date) from public, anon;
grant execute on function public.get_upcoming_events(uuid,date,date) to authenticated;
