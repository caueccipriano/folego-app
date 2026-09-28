-- Reproduce the CURRENT unpatched cross-space staging gap in a disposable
-- fixture before the hardening migration is applied. This is NOT executed
-- against a live project or any real user's imports.
\set ON_ERROR_STOP on
SET ROLE authenticated;
SELECT set_config(
  'request.jwt.claim.sub','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false
);

DO $reproduce$
DECLARE v_count integer;
BEGIN
  SELECT count(*) INTO v_count FROM public.categories
  WHERE id='b0000000-0000-4000-8000-000000000002';
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'fixture error: A must not see B category';
  END IF;

  -- The original single-column FK succeeds even though the referenced
  -- category is hidden by RLS and belongs to a different tenant.
  UPDATE public.import_rows
  SET category_id='b0000000-0000-4000-8000-000000000002'
  WHERE id='a0000000-0000-4000-8000-000000000010';
  IF NOT FOUND THEN RAISE EXCEPTION 'fixture error: A row is not writable'; END IF;

  SELECT count(*) INTO v_count FROM public.import_rows
  WHERE id='a0000000-0000-4000-8000-000000000010'
    AND category_id='b0000000-0000-4000-8000-000000000002';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'expected pre-migration cross-tenant reference gap';
  END IF;

  UPDATE public.import_rows
  SET category_id='a0000000-0000-4000-8000-000000000002'
  WHERE id='a0000000-0000-4000-8000-000000000010';

  RAISE NOTICE 'PASS: reproduced legacy cross-space staging link with fictional users; restored fixture';
END;
$reproduce$;
RESET ROLE;
