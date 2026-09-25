create table if not exists public.premium_grants (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  grant_type text not null check (grant_type in ('complimentary', 'lifetime')),
  valid_until timestamptz,
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.premium_grants enable row level security;

revoke all on table public.premium_grants from anon;
revoke all on table public.premium_grants from authenticated;

comment on table public.premium_grants is
  'Server-controlled complimentary/lifetime Premium access. Paid/trial access is resolved by RevenueCat.';
