create or replace function public.get_my_premium_grant()
returns table (
  grant_type text,
  valid_until timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select pg.grant_type, pg.valid_until
  from public.premium_grants pg
  where pg.user_id = (select auth.uid())
    and (pg.valid_until is null or pg.valid_until > now())
  limit 1;
$$;

revoke all on function public.get_my_premium_grant() from public;
revoke all on function public.get_my_premium_grant() from anon;
grant execute on function public.get_my_premium_grant() to authenticated;

comment on function public.get_my_premium_grant() is
  'Returns only the authenticated user''s active complimentary or lifetime Premium grant.';
