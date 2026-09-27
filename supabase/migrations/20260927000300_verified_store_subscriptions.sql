-- Store-verified subscriptions are separate from manually issued premium grants.
create table if not exists public.store_subscriptions (
 user_id uuid primary key references auth.users(id) on delete cascade,
 entitlement text not null check(entitlement='premium'),
 expires_at timestamptz,
 status text not null check(status in ('active','expired','revoked')),
 updated_at timestamptz not null default now()
);
alter table public.store_subscriptions enable row level security;
revoke all on public.store_subscriptions from anon,authenticated;
create table if not exists public.subscription_webhook_events (
 event_id text primary key,
 event_type text not null,
 received_at timestamptz not null default now()
);
alter table public.subscription_webhook_events enable row level security;
revoke all on public.subscription_webhook_events from anon,authenticated;
create or replace function public.consume_free_simulation()
returns table(allowed boolean,remaining integer)
language plpgsql security definer set search_path=''
as $$
declare v_uid uuid := (select auth.uid()); v_month date := date_trunc('month',now() at time zone 'UTC')::date; v_used integer;
begin
 if v_uid is null then raise exception 'Authentication required'; end if;
 if exists(select 1 from public.premium_grants pg where pg.user_id=v_uid and pg.grant_type in ('complimentary','lifetime') and (pg.valid_until is null or pg.valid_until>now()))
 or exists(select 1 from public.store_subscriptions s where s.user_id=v_uid and s.entitlement='premium' and s.status='active' and (s.expires_at is null or s.expires_at>now())) then
 return query select true,-1; return; end if;
 insert into public.financial_intelligence_usage(user_id,period_month,capability,used) values(v_uid,v_month,'simulation',0) on conflict do nothing;
 update public.financial_intelligence_usage set used=used+1 where user_id=v_uid and period_month=v_month and capability='simulation' and used<3 returning used into v_used;
 if v_used is null then return query select false,0; else return query select true,3-v_used; end if;
end; $$;
revoke all on function public.consume_free_simulation() from public;
grant execute on function public.consume_free_simulation() to authenticated;