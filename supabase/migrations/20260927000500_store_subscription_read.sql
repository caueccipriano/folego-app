-- Authenticated users can read only their own verified store access.
create or replace function public.get_my_store_subscription()
returns table(status text, expires_at timestamptz)
language sql stable security definer set search_path=''
as $$
 select s.status,s.expires_at from public.store_subscriptions s
 where s.user_id=(select auth.uid()) and s.entitlement='premium'
   and s.status='active' and (s.expires_at is null or s.expires_at>now())
 limit 1;
$$;
revoke all on function public.get_my_store_subscription() from public,anon;
grant execute on function public.get_my_store_subscription() to authenticated;