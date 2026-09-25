revoke execute on function public.cancel_simple_transaction(uuid, uuid) from public;
revoke execute on function public.create_custom_category(uuid, text, text, uuid, boolean, text, text[]) from public;
revoke execute on function public.get_wallet_overview(uuid) from public;
revoke execute on function public.rename_custom_category(uuid, uuid, text) from public;
revoke execute on function public.set_category_visibility(uuid, uuid, boolean) from public;
revoke execute on function public.set_event_annotations(uuid, uuid, text, text, text, uuid[]) from public;
revoke execute on function public.set_recurring_annotations(uuid, uuid, text, text, uuid[]) from public;
