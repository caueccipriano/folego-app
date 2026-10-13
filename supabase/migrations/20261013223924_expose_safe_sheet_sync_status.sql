-- Initial read-only, member-scoped status RPC as recorded in Fôlego Dev.
-- The follow-up migration fixes COALESCE qualification.
create or replace function public.get_folego_sheet_sync_status(p_space_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_record record;
begin
  if (select auth.uid()) is null
     or not exists (
       select 1 from public.space_members m
       where m.space_id = p_space_id
         and m.user_id = (select auth.uid())
     ) then
    raise exception 'not authorized for financial space'
      using errcode = '42501';
  end if;

  select i.enabled, i.last_push_at, i.last_pull_at
    into v_record
  from public.sheet_sync_integrations i
  where i.space_id = p_space_id
  order by i.updated_at desc, i.id
  limit 1;

  if not found then
    return pg_catalog.jsonb_build_object(
      'configured', false,
      'enabled', false,
      'last_push_at', null,
      'last_pull_at', null
    );
  end if;

  return pg_catalog.jsonb_build_object(
    'configured', true,
    'enabled', pg_catalog.coalesce(v_record.enabled, false),
    'last_push_at', v_record.last_push_at,
    'last_pull_at', v_record.last_pull_at
  );
end;
$function$;

revoke all on function public.get_folego_sheet_sync_status(uuid)
  from public, anon, authenticated;
grant execute on function public.get_folego_sheet_sync_status(uuid)
  to authenticated;
comment on function public.get_folego_sheet_sync_status(uuid) is
  'Space-scoped read-only status: push = sheet to app attempted, pull = app to sheet polled. Timestamps do not guarantee row-by-row reconciliation.';
