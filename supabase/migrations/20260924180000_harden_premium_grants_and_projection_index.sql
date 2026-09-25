drop policy if exists premium_grants_select_own on public.premium_grants;

create policy premium_grants_select_own
on public.premium_grants
for select
to authenticated
using ((select auth.uid()) = user_id);

revoke all on table public.premium_grants from authenticated;
grant select (user_id, grant_type, valid_until) on public.premium_grants to authenticated;

create or replace function public.get_my_premium_grant()
returns table (
  grant_type text,
  valid_until timestamptz
)
language sql
stable
security invoker
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

create index if not exists projection_planned_items_category_space_idx
on public.projection_planned_items (category_id, space_id);
