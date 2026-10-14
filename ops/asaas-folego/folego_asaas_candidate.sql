-- FÔLEGO / Asaas PWA: additive candidate, NOT applied to a live database.
-- For sandbox validation. Never reuse Editalume tables or store subscriptions.
-- No access privileges are granted to browser clients for billing writes.
begin;
create table if not exists public.folego_asaas_billing_intents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  environment text not null default 'sandbox' check (environment in ('sandbox','production')),
  plan text not null check (plan in ('monthly','yearly')),
  verified_email text not null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now()+interval '30 minutes'),
  constraint folego_asaas_intents_email_unique unique (environment,verified_email)
);
create index if not exists folego_asaas_intents_user_idx on public.folego_asaas_billing_intents(user_id,environment);

create table if not exists public.folego_asaas_events (
  environment text not null check (environment in ('sandbox','production')),
  event_id text not null check(length(event_id) between 4 and 180),
  event_type text not null,
  subscription_id text,
  payment_id text,
  processing_state text not null default 'pending' check (processing_state in ('pending','processed','unmatched','ignored','error')),
  received_at timestamptz not null default now(),
  processed_at timestamptz,
  primary key(environment,event_id)
);

create table if not exists public.folego_asaas_subscriptions (
  environment text not null check(environment in ('sandbox','production')),
  subscription_id text not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  customer_id text not null,
  plan text not null check (plan in ('monthly','yearly')),
  payment_link_id text not null,
  billing_status text not null,
  verified_payment_id text,
  paid_until timestamptz,
  source_verified boolean not null default false,
  updated_at timestamptz not null default now(),
  primary key(environment,subscription_id)
);
create index if not exists folego_asaas_subs_owner_idx on public.folego_asaas_subscriptions(user_id,environment,paid_until);

alter table public.folego_asaas_billing_intents enable row level security;
alter table public.folego_asaas_events enable row level security;
alter table public.folego_asaas_subscriptions enable row level security;
revoke all on public.folego_asaas_billing_intents from public,anon,authenticated;
revoke all on public.folego_asaas_events from public,anon,authenticated;
revoke all on public.folego_asaas_subscriptions from public,anon,authenticated;
-- Deliberately no table policies. Only server-side service-role processes billing.
-- Own-user read access is limited to this function; sandbox can never unlock Premium.
create or replace function public.get_my_folego_asaas_premium()
returns table(active boolean,paid_until timestamptz)
language sql stable security definer
set search_path=''
as $func$
  select exists(
    select 1 from public.folego_asaas_subscriptions s
    where s.user_id=(select auth.uid()) and s.environment='production'
      and s.source_verified=true and s.billing_status='ACTIVE'
      and s.verified_payment_id is not null and s.paid_until>now()
  ) as active,
  (select max(s.paid_until) from public.folego_asaas_subscriptions s
    where s.user_id=(select auth.uid()) and s.environment='production'
      and s.source_verified=true and s.billing_status='ACTIVE'
      and s.verified_payment_id is not null and s.paid_until>now()
  ) as paid_until;
$func$;
revoke all on function public.get_my_folego_asaas_premium() from public,anon;
grant execute on function public.get_my_folego_asaas_premium() to authenticated;
commit;
