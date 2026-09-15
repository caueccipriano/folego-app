-- Document three known historical financial exceptions without changing ledger semantics.
-- This migration is intentionally metadata-only and idempotent.

update public.financial_events
set metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object(
  'legacy_exception', true,
  'legacy_exception_kind', 'one_sided_transfer',
  'legacy_reason', 'missing_source_account',
  'legacy_counterparty_unavailable', true,
  'historical_record', true
)
where id = 'f77206c1-cbc7-406a-a1ff-799213b15814'::uuid
  and event_type = 'transfer'
  and source = 'sheet-sync';

update public.financial_events
set metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object(
  'legacy_exception', true,
  'legacy_exception_kind', 'card_payment_missing_invoice',
  'legacy_reason', 'original_invoice_not_imported',
  'legacy_invoice_unavailable', true,
  'historical_record', true
)
where id = 'e0339915-d275-48e1-82ef-4e6e01d7a4f1'::uuid
  and event_type = 'card_payment'
  and source = 'sheet-sync';

update public.financial_events
set metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object(
  'legacy_exception', true,
  'legacy_exception_kind', 'financing_inflow_missing_liability_details',
  'legacy_reason', 'liability_details_not_imported',
  'liability_details_unavailable', true,
  'historical_record', true
)
where id = '0acdfcdb-d0ee-4660-b6a8-c6b217824e6a'::uuid
  and event_type = 'transfer'
  and source = 'sheet-sync';
