-- Applied to Supabase Dev as 20260916012350_preserve_upcoming_events_compatibility.
-- Keeps the pre-Agenda 2.0 RPC signature working while delegating to the unified source.

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
  from public.get_upcoming_events(p_space_id, p_from, p_until, 120) e;
$function$;

revoke all on function public.get_upcoming_events(uuid,date,date) from public, anon;
grant execute on function public.get_upcoming_events(uuid,date,date) to authenticated;
