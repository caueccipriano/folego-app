-- Regression test for the three explicitly documented historical ledger exceptions.
-- The migration is metadata-only: financial values, impacts and backings must remain unchanged.

begin;

do $test$
declare
  v_event_count_before integer;
  v_event_count_after integer;
  v_impact_count_before integer;
  v_impact_count_after integer;
  v_invoice_count_before integer;
  v_invoice_count_after integer;
  v_payment_count_before integer;
  v_payment_count_after integer;
  v_bradesco_before numeric;
  v_bradesco_after numeric;
  v_santander_before numeric;
  v_santander_after numeric;
  v_legacy_count integer;
  v_invalid_count integer;
begin
  -- Fixed imported facts must exist exactly as audited.
  if not exists (
    select 1 from public.financial_events
    where id = 'f77206c1-cbc7-406a-a1ff-799213b15814'::uuid
      and event_type = 'transfer'
      and amount = 836.00
      and status = 'confirmed'
      and source = 'sheet-sync'
  ) then raise exception 'legacy_one_sided_transfer_fixture_changed'; end if;

  if not exists (
    select 1 from public.financial_events
    where id = 'e0339915-d275-48e1-82ef-4e6e01d7a4f1'::uuid
      and event_type = 'card_payment'
      and amount = 2988.81
      and status = 'confirmed'
      and source = 'sheet-sync'
  ) then raise exception 'legacy_card_payment_fixture_changed'; end if;

  if not exists (
    select 1 from public.financial_events
    where id = '0acdfcdb-d0ee-4660-b6a8-c6b217824e6a'::uuid
      and event_type = 'transfer'
      and amount = 806.51
      and status = 'confirmed'
      and source = 'sheet-sync'
  ) then raise exception 'legacy_financing_inflow_fixture_changed'; end if;

  select count(*) into v_event_count_before from public.financial_events;
  select count(*) into v_impact_count_before from public.financial_impacts;
  select count(*) into v_invoice_count_before from public.card_invoices;
  select count(*) into v_payment_count_before from public.card_payments;

  select coalesce(sum(fi.amount), 0) into v_bradesco_before
  from public.financial_impacts fi
  where fi.dimension = 'cash'
    and fi.account_id = 'c1ce5d37-1afc-4197-9a94-b4d9a9a3b038'::uuid;

  select coalesce(sum(fi.amount), 0) into v_santander_before
  from public.financial_impacts fi
  where fi.dimension = 'cash'
    and fi.account_id = '11a13457-257a-4143-9e42-962d1bd87999'::uuid;

  -- Reapply the exact metadata-only migration to prove idempotency.
  update public.financial_events
  set metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object(
    'legacy_exception', true,
    'legacy_exception_kind', 'one_sided_transfer',
    'legacy_reason', 'missing_source_account',
    'legacy_counterparty_unavailable', true,
    'historical_record', true
  )
  where id = 'f77206c1-cbc7-406a-a1ff-799213b15814'::uuid
    and event_type = 'transfer' and source = 'sheet-sync';

  update public.financial_events
  set metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object(
    'legacy_exception', true,
    'legacy_exception_kind', 'card_payment_missing_invoice',
    'legacy_reason', 'original_invoice_not_imported',
    'legacy_invoice_unavailable', true,
    'historical_record', true
  )
  where id = 'e0339915-d275-48e1-82ef-4e6e01d7a4f1'::uuid
    and event_type = 'card_payment' and source = 'sheet-sync';

  update public.financial_events
  set metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object(
    'legacy_exception', true,
    'legacy_exception_kind', 'financing_inflow_missing_liability_details',
    'legacy_reason', 'liability_details_not_imported',
    'liability_details_unavailable', true,
    'historical_record', true
  )
  where id = '0acdfcdb-d0ee-4660-b6a8-c6b217824e6a'::uuid
    and event_type = 'transfer' and source = 'sheet-sync';

  -- Metadata is explicit and user-facing code can distinguish these cases.
  if not exists (
    select 1 from public.financial_events
    where id = 'f77206c1-cbc7-406a-a1ff-799213b15814'::uuid
      and metadata @> '{"legacy_exception":true,"legacy_exception_kind":"one_sided_transfer","legacy_counterparty_unavailable":true}'::jsonb
  ) then raise exception 'one_sided_transfer_not_documented'; end if;

  if not exists (
    select 1 from public.financial_events
    where id = 'e0339915-d275-48e1-82ef-4e6e01d7a4f1'::uuid
      and metadata @> '{"legacy_exception":true,"legacy_exception_kind":"card_payment_missing_invoice","legacy_invoice_unavailable":true}'::jsonb
  ) then raise exception 'legacy_card_payment_not_documented'; end if;

  if not exists (
    select 1 from public.financial_events
    where id = '0acdfcdb-d0ee-4660-b6a8-c6b217824e6a'::uuid
      and metadata @> '{"legacy_exception":true,"legacy_exception_kind":"financing_inflow_missing_liability_details","liability_details_unavailable":true}'::jsonb
  ) then raise exception 'financing_inflow_not_documented'; end if;

  -- The ledger facts themselves remain exactly as before.
  if (select count(*) from public.financial_impacts where event_id = 'f77206c1-cbc7-406a-a1ff-799213b15814'::uuid) <> 1
    or (select coalesce(sum(amount),0) from public.financial_impacts where event_id = 'f77206c1-cbc7-406a-a1ff-799213b15814'::uuid and dimension='cash') <> 836.00
  then raise exception 'one_sided_transfer_ledger_changed'; end if;

  if (select count(*) from public.financial_impacts where event_id = 'e0339915-d275-48e1-82ef-4e6e01d7a4f1'::uuid) <> 1
    or (select coalesce(sum(amount),0) from public.financial_impacts where event_id = 'e0339915-d275-48e1-82ef-4e6e01d7a4f1'::uuid and dimension='cash') <> -2988.81
  then raise exception 'legacy_card_payment_ledger_changed'; end if;

  if exists (select 1 from public.card_payments where event_id = 'e0339915-d275-48e1-82ef-4e6e01d7a4f1'::uuid)
  then raise exception 'fictional_card_payment_backing_created'; end if;

  if (select count(*) from public.financial_impacts where event_id = '0acdfcdb-d0ee-4660-b6a8-c6b217824e6a'::uuid) <> 1
    or (select coalesce(sum(amount),0) from public.financial_impacts where event_id = '0acdfcdb-d0ee-4660-b6a8-c6b217824e6a'::uuid and dimension='cash') <> 806.51
  then raise exception 'financing_inflow_ledger_changed'; end if;

  if exists (
    select 1 from public.financial_impacts
    where event_id in (
      'f77206c1-cbc7-406a-a1ff-799213b15814'::uuid,
      'e0339915-d275-48e1-82ef-4e6e01d7a4f1'::uuid,
      '0acdfcdb-d0ee-4660-b6a8-c6b217824e6a'::uuid
    ) and dimension in ('economic','budget')
  ) then raise exception 'legacy_exception_economic_or_budget_impact_created'; end if;

  select count(*) into v_event_count_after from public.financial_events;
  select count(*) into v_impact_count_after from public.financial_impacts;
  select count(*) into v_invoice_count_after from public.card_invoices;
  select count(*) into v_payment_count_after from public.card_payments;
  select coalesce(sum(fi.amount), 0) into v_bradesco_after
  from public.financial_impacts fi where fi.dimension='cash'
    and fi.account_id='c1ce5d37-1afc-4197-9a94-b4d9a9a3b038'::uuid;
  select coalesce(sum(fi.amount), 0) into v_santander_after
  from public.financial_impacts fi where fi.dimension='cash'
    and fi.account_id='11a13457-257a-4143-9e42-962d1bd87999'::uuid;

  if v_event_count_after <> v_event_count_before then raise exception 'financial_event_count_changed'; end if;
  if v_impact_count_after <> v_impact_count_before then raise exception 'financial_impact_count_changed'; end if;
  if v_invoice_count_after <> v_invoice_count_before then raise exception 'fictional_invoice_created'; end if;
  if v_payment_count_after <> v_payment_count_before then raise exception 'card_payment_count_changed'; end if;
  if v_bradesco_after <> v_bradesco_before or v_santander_after <> v_santander_before then
    raise exception 'reconciled_cash_balance_changed';
  end if;

  select count(*) into v_legacy_count
  from public.financial_events
  where status = 'confirmed' and coalesce((metadata->>'legacy_exception')::boolean, false);
  if v_legacy_count <> 3 then raise exception 'expected_three_documented_legacy_exceptions, got %', v_legacy_count; end if;

  -- Canonical audit: documented exceptions are visible but excluded from corruption.
  with audit as (
    select e.id,
      case
        when coalesce((e.metadata->>'legacy_exception')::boolean, false) then 'legacy_exception'
        when e.event_type = 'card_purchase' and
             (select count(*) from public.card_purchases cp where cp.event_id=e.id and cp.space_id=e.space_id)=1 and
             not exists (select 1 from public.financial_impacts fi where fi.event_id=e.id and fi.dimension='cash') and
             coalesce((select sum(fi.amount) from public.financial_impacts fi where fi.event_id=e.id and fi.dimension='economic'),0)=-e.amount and
             coalesce((select sum(fi.amount) from public.financial_impacts fi where fi.event_id=e.id and fi.dimension='budget'),0)=-e.amount
          then 'canonical'
        when e.event_type = 'card_payment' and
             (select count(*) from public.card_payments cp where cp.event_id=e.id and cp.space_id=e.space_id)=1 and
             coalesce((select sum(fi.amount) from public.financial_impacts fi where fi.event_id=e.id and fi.dimension='cash'),0)=-e.amount and
             coalesce((select sum(fi.amount) from public.financial_impacts fi where fi.event_id=e.id and fi.dimension in ('economic','budget')),0)=0
          then 'canonical'
        when e.event_type = 'transfer' and
             (select count(*) from public.financial_impacts fi where fi.event_id=e.id and fi.dimension='cash')=2 and
             coalesce((select sum(fi.amount) from public.financial_impacts fi where fi.event_id=e.id and fi.dimension='cash'),0)=0 and
             coalesce((select sum(fi.amount) from public.financial_impacts fi where fi.event_id=e.id and fi.dimension in ('economic','budget')),0)=0
          then 'canonical'
        when e.event_type = 'benefit_expense' and
             coalesce((select sum(fi.amount) from public.financial_impacts fi where fi.event_id=e.id and fi.dimension='benefit'),0)=-e.amount and
             coalesce((select sum(fi.amount) from public.financial_impacts fi where fi.event_id=e.id and fi.dimension='economic'),0)=-e.amount and
             coalesce((select sum(fi.amount) from public.financial_impacts fi where fi.event_id=e.id and fi.dimension='budget'),0)=-e.amount and
             not exists (select 1 from public.financial_impacts fi where fi.event_id=e.id and fi.dimension='cash')
          then 'canonical'
        else 'not_checked'
      end as classification
    from public.financial_events e
    where e.status='confirmed'
      and e.event_type in ('card_purchase','card_payment','transfer','benefit_expense')
  )
  select count(*) into v_invalid_count from audit where classification not in ('canonical','legacy_exception');

  if v_invalid_count <> 0 then raise exception 'canonical_integrity_audit_found_%_invalid_records', v_invalid_count; end if;
end;
$test$;

rollback;
