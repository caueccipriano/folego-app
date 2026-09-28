-- Multi-tenant invariant: a staged import row may only refer to objects
-- belonging to the SAME financial space as the row itself.
--
-- RLS already restricts the import row's space_id, and the normal RPCs
-- validate related IDs. Direct authenticated INSERT/UPDATE had single-column
-- FKs that could nevertheless accept references to other tenants' objects.
-- Keep the existing FK ON DELETE semantics; enforce the missing relationship
-- on every future write, including calls that bypass the normal review RPC.
--
-- Preflight the live DB for legacy cross-space references before deployment.
-- This migration does not modify existing imports, transactions, or balances.

CREATE OR REPLACE FUNCTION private.enforce_import_row_space_refs()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $enforce_refs$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.import_batches b
    WHERE b.id = NEW.batch_id AND b.space_id = NEW.space_id
  ) THEN
    RAISE EXCEPTION 'import_batch_not_in_space'
      USING ERRCODE = '23503';
  END IF;

  IF NEW.category_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.categories c
    WHERE c.id = NEW.category_id AND c.space_id = NEW.space_id
  ) THEN
    RAISE EXCEPTION 'import_category_not_in_space'
      USING ERRCODE = '23503';
  END IF;

  IF NEW.counterpart_account_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.accounts a
    WHERE a.id = NEW.counterpart_account_id
      AND a.space_id = NEW.space_id
  ) THEN
    RAISE EXCEPTION 'import_counterpart_not_in_space'
      USING ERRCODE = '23503';
  END IF;

  IF NEW.invoice_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.card_invoices i
    WHERE i.id = NEW.invoice_id AND i.space_id = NEW.space_id
  ) THEN
    RAISE EXCEPTION 'import_invoice_not_in_space'
      USING ERRCODE = '23503';
  END IF;

  -- Legacy callers can submit an in-space card purchase/payment *backing ID*
  -- on UPDATE; the pre-existing import_rows_resolve_backing_event_id trigger
  -- normalizes it to an in-space financial event later in the trigger chain.
  -- Those accepted IDs still have to belong to this import row's space.
  IF NEW.imported_event_id IS NOT NULL AND NOT (
    EXISTS (
      SELECT 1 FROM public.financial_events e
      WHERE e.id = NEW.imported_event_id AND e.space_id = NEW.space_id
    ) OR EXISTS (
      SELECT 1 FROM public.card_purchases p
      WHERE p.id = NEW.imported_event_id AND p.space_id = NEW.space_id
    ) OR EXISTS (
      SELECT 1 FROM public.card_payments p
      WHERE p.id = NEW.imported_event_id AND p.space_id = NEW.space_id
    )
  ) THEN
    RAISE EXCEPTION 'import_backing_event_not_in_space'
      USING ERRCODE = '23503';
  END IF;

  RETURN NEW;
END;
$enforce_refs$;

REVOKE ALL ON FUNCTION private.enforce_import_row_space_refs()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS import_rows_enforce_space_refs ON public.import_rows;
CREATE TRIGGER import_rows_enforce_space_refs
BEFORE INSERT OR UPDATE OF
  batch_id, space_id, category_id, counterpart_account_id,
  invoice_id, imported_event_id
ON public.import_rows
FOR EACH ROW
EXECUTE FUNCTION private.enforce_import_row_space_refs();

COMMENT ON FUNCTION private.enforce_import_row_space_refs() IS
  'Rejects any imported batch, category, counterpart, invoice or backing event reference that belongs to another tenant space.';
