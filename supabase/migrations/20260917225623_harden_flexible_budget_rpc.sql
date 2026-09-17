-- Keep the public RPC endpoint callable only by authenticated users.
-- PostgreSQL grants EXECUTE to PUBLIC by default, so revoking anon alone is
-- not sufficient for SECURITY DEFINER write functions.

revoke execute on function public.set_flexible_budget_limit(uuid,date,numeric) from public;
revoke execute on function public.set_flexible_budget_limit(uuid,date,numeric) from anon;
grant execute on function public.set_flexible_budget_limit(uuid,date,numeric) to authenticated;

revoke execute on function public.get_flexible_budget_overview(uuid,date) from public;
revoke execute on function public.get_flexible_budget_overview(uuid,date) from anon;
grant execute on function public.get_flexible_budget_overview(uuid,date) to authenticated;
