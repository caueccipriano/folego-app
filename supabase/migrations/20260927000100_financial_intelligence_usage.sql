-- Server-authoritative usage accounting. Client flags must not grant paid access.
create table if not exists public.financial_intelligence_usage (
  user_id uuid not null references auth.users(id) on delete cascade,
  period_month date not null,
  capability text not null check (capability in ('simulation','ai_question')),
  used integer not null default 0 check (used >= 0),
  primary key (user_id, period_month, capability)
);
alter table public.financial_intelligence_usage enable row level security;
revoke all on public.financial_intelligence_usage from anon, authenticated;
create or replace function public.consume_free_simulation()
returns table (allowed boolean, remaining integer)
language plpgsql security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_month date := date_trunc('month', now() at time zone 'UTC')::date;
  v_used integer;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  insert into public.financial_intelligence_usage(user_id, period_month, capability, used)
    values(v_uid,v_month,'simulation',0)
    on conflict do nothing;
  update public.financial_intelligence_usage
    set used = used + 1
    where user_id=v_uid and period_month=v_month
      and capability='simulation' and used < 3
    returning used into v_used;
  if v_used is null then
    return query select false, 0;
  else
    return query select true, 3-v_used;
  end if;
end;
$$;
revoke all on function public.consume_free_simulation() from public;
grant execute on function public.consume_free_simulation() to authenticated;
