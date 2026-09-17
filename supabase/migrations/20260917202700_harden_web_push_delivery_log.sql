-- The delivery log is service-only. Keep RLS explicit so client roles never
-- gain visibility even if table grants change later.
drop policy if exists web_push_delivery_log_no_client_access
on public.web_push_delivery_log;

create policy web_push_delivery_log_no_client_access
on public.web_push_delivery_log
for all
to anon, authenticated
using (false)
with check (false);
