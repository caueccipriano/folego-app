create table if not exists public.ai_question_usage (
 user_id uuid not null references auth.users(id) on delete cascade,
 period_month date not null,
 used integer not null default 0 check (used between 0 and 30),
 primary key(user_id,period_month)
);
alter table public.ai_question_usage enable row level security;
revoke all on public.ai_question_usage from anon,authenticated;
create or replace function public.consume_premium_ai_question(p_user_id uuid)
returns boolean language plpgsql security definer set search_path='' as $$
declare v_month date := date_trunc('month',now() at time zone 'UTC')::date;
begin
 if auth.role() <> 'service_role' then raise exception 'service role required'; end if;
 if not exists(select 1 from public.premium_grants g where g.user_id=p_user_id and g.grant_type in ('complimentary','lifetime') and (g.valid_until is null or g.valid_until>now()))
 and not exists(select 1 from public.store_subscriptions s where s.user_id=p_user_id and s.entitlement='premium' and s.status='active' and (s.expires_at is null or s.expires_at>now())) then return false; end if;
 insert into public.ai_question_usage(user_id,period_month,used) values(p_user_id,v_month,1)
 on conflict(user_id,period_month) do update set used=public.ai_question_usage.used+1 where public.ai_question_usage.used<30;
 return found;
end;$$;
revoke all on function public.consume_premium_ai_question(uuid) from public,anon,authenticated;
grant execute on function public.consume_premium_ai_question(uuid) to service_role;