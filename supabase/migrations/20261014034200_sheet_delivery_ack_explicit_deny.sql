-- Defense-in-depth for the service-only receipt ledger.
-- Explicit RESTRICTIVE deny prevents a future permissive RLS policy from
-- accidentally exposing operational receipts to application users.
do $$
begin
  if not exists (
    select 1 from pg_catalog.pg_policies
    where schemaname = 'public'
      and tablename = 'sheet_sync_delivery_receipts'
      and policyname = 'sheet_delivery_ack_no_direct_client_access'
  ) then
    execute '
      create policy sheet_delivery_ack_no_direct_client_access
      on public.sheet_sync_delivery_receipts
      as restrictive
      for all
      to anon, authenticated
      using (false)
      with check (false)
    ';
  end if;
end;
$$;
