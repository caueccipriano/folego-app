revoke execute on function public.cancel_benefit_expense(uuid, uuid) from public, anon;
revoke execute on function public.cancel_card_purchase(uuid, uuid) from public, anon;
revoke execute on function public.cancel_transfer_transaction(uuid, uuid) from public, anon;
revoke execute on function public.get_category_catalog(uuid, text) from public, anon;
revoke execute on function public.register_benefit_at(uuid, uuid, numeric, text, boolean, uuid, timestamptz) from public, anon;
revoke execute on function public.reverse_card_payment(uuid, uuid) from public, anon;
revoke execute on function public.update_benefit_expense(uuid, uuid, uuid, numeric, text, uuid, timestamptz) from public, anon;
revoke execute on function public.update_card_purchase(uuid, uuid, numeric, text, uuid, text, uuid, timestamptz) from public, anon;
revoke execute on function public.update_transfer_transaction(uuid, uuid, uuid, uuid, numeric, text, timestamptz) from public, anon;

grant execute on function public.cancel_benefit_expense(uuid, uuid) to authenticated, service_role;
grant execute on function public.cancel_card_purchase(uuid, uuid) to authenticated, service_role;
grant execute on function public.cancel_transfer_transaction(uuid, uuid) to authenticated, service_role;
grant execute on function public.get_category_catalog(uuid, text) to authenticated, service_role;
grant execute on function public.register_benefit_at(uuid, uuid, numeric, text, boolean, uuid, timestamptz) to authenticated, service_role;
grant execute on function public.reverse_card_payment(uuid, uuid) to authenticated, service_role;
grant execute on function public.update_benefit_expense(uuid, uuid, uuid, numeric, text, uuid, timestamptz) to authenticated, service_role;
grant execute on function public.update_card_purchase(uuid, uuid, numeric, text, uuid, text, uuid, timestamptz) to authenticated, service_role;
grant execute on function public.update_transfer_transaction(uuid, uuid, uuid, uuid, numeric, text, timestamptz) to authenticated, service_role;
