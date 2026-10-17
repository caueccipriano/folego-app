-- Sheet delivery receipts v1: purely operational, no balance/event mutation.
-- Apply only after CI. Apps Script must explicitly acknowledge a successful
-- row write; a pull request to the existing sheet-sync endpoint is not an ACK.
create table if not exists public.sheet_sync_delivery_receipts (
  integration_id uuid not null references public.sheet_sync_integrations(id) on delete cascade,
  space_id uuid not null references public.financial_spaces(id) on delete cascade,
  event_id uuid not null references public.financial_events(id) on delete cascade,
  sheet_row_id text not null check (char_length(sheet_row_id) between 1 and 160),
  event_updated_at timestamptz not null,
  content_sha256 text not null check (content_sha256 ~ '^[0-9a-f]{64}$'),
  acknowledged_at timestamptz not null default now(),
  primary key (integration_id, event_id, event_updated_at)
);

create index if not exists sheet_sync_receipts_space_event_idx
  on public.sheet_sync_delivery_receipts (space_id, event_id, event_updated_at);

alter table public.sheet_sync_delivery_receipts enable row level security;
revoke all on public.sheet_sync_delivery_receipts from public, anon, authenticated;
grant select, insert on public.sheet_sync_delivery_receipts to service_role;

-- Only the separately authenticated sheet-row-ack Edge Function calls this.
-- Function revalidates integration, space, row identity and event version.
create or replace function public.record_folego_sheet_delivery_ack(
  p_integration_id uuid,
  p_event_id uuid,
  p_sheet_row_id text,
  p_expected_updated_at timestamptz,
  p_content_sha256 text
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_space_id uuid;
  v_updated_at timestamptz;
  v_external_id text;
  v_current record;
begin
  if p_sheet_row_id is null or char_length(p_sheet_row_id) < 1
     or char_length(p_sheet_row_id) > 160
     or p_content_sha256 is null
     or p_content_sha256 !~ '^[0-9a-f]{64}$'
     or p_expected_updated_at is null then
    return pg_catalog.jsonb_build_object('status', 'invalid_request');
  end if;

  select i.space_id into v_space_id
    from public.sheet_sync_integrations i
    where i.id = p_integration_id and i.enabled = true;
  if v_space_id is null then
    return pg_catalog.jsonb_build_object('status', 'integration_disabled');
  end if;

  select e.updated_at, e.external_id
    into v_updated_at, v_external_id
    from public.financial_events e
    where e.id = p_event_id
      and e.space_id = v_space_id
      and e.status = 'confirmed'
    for share;
  if not found then
    return pg_catalog.jsonb_build_object('status', 'event_not_found');
  end if;

  if p_sheet_row_id <> ('event:' || p_event_id::text)
    and coalesce(v_external_id, '') <> p_sheet_row_id
    and coalesce(v_external_id, '') <> ('sheet:' || p_sheet_row_id) then
    return pg_catalog.jsonb_build_object('status', 'row_identity_conflict');
  end if;

  if v_updated_at is distinct from p_expected_updated_at then
    return pg_catalog.jsonb_build_object('status', 'stale_version');
  end if;

  insert into public.sheet_sync_delivery_receipts (
    integration_id, space_id, event_id, sheet_row_id,
    event_updated_at, content_sha256
  ) values (
    p_integration_id, v_space_id, p_event_id, p_sheet_row_id,
    p_expected_updated_at, p_content_sha256
  ) on conflict do nothing;

  if found then
    return pg_catalog.jsonb_build_object('status', 'applied', 'event_id', p_event_id);
  end if;

  select r.sheet_row_id, r.content_sha256 into v_current
    from public.sheet_sync_delivery_receipts r
    where r.integration_id = p_integration_id
      and r.event_id = p_event_id
      and r.event_updated_at = p_expected_updated_at;

  if found and v_current.sheet_row_id = p_sheet_row_id
     and v_current.content_sha256 = p_content_sha256 then
    return pg_catalog.jsonb_build_object('status', 'already_acknowledged', 'event_id', p_event_id);
  end if;
  return pg_catalog.jsonb_build_object('status', 'receipt_conflict', 'event_id', p_event_id);
end;
$fn$;

revoke all on function public.record_folego_sheet_delivery_ack(uuid,uuid,text,timestamptz,text)
  from public, anon, authenticated;
grant execute on function public.record_folego_sheet_delivery_ack(uuid,uuid,text,timestamptz,text)
  to service_role;

-- Read-only member-scoped receipt status for the exact CURRENT event version.
-- Historical ACKs remain in the table but are not returned as current proof.
create or replace function public.get_folego_sheet_delivery_receipts(
  p_space_id uuid,
  p_event_ids uuid[]
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_result jsonb;
begin
  if (select auth.uid()) is null
     or not exists (
       select 1 from public.space_members m
       where m.space_id = p_space_id and m.user_id = (select auth.uid())
     ) then
    raise exception 'not authorized for financial space'
      using errcode = '42501';
  end if;

  if p_event_ids is null or cardinality(p_event_ids) > 150 then
    raise exception 'too many event IDs'
      using errcode = '22023';
  end if;

  select coalesce(
    pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'event_id', r.event_id,
      'acknowledged_at', r.acknowledged_at
    ) order by r.acknowledged_at desc),
    '[]'::jsonb
  ) into v_result
  from public.sheet_sync_delivery_receipts r
  join public.financial_events e
    on e.id = r.event_id and e.space_id = r.space_id
      and e.updated_at = r.event_updated_at
      and e.status = 'confirmed'
  join public.sheet_sync_integrations i
    on i.id = r.integration_id and i.space_id = r.space_id
      and i.enabled = true
  where r.space_id = p_space_id
    and r.event_id = any(p_event_ids);

  return v_result;
end;
$fn$;

revoke all on function public.get_folego_sheet_delivery_receipts(uuid,uuid[])
  from public, anon, authenticated;
grant execute on function public.get_folego_sheet_delivery_receipts(uuid,uuid[])
  to authenticated;
