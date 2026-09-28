-- Reproduces the former Edge Function sequence on disposable SQL only:
-- 1. clean B-authored rules; 2. delete auth.users B; cascade silently deletes
-- C's *shared* financial data. ROLLBACK leaves the fixture intact.
\set ON_ERROR_STOP on
BEGIN;
DELETE FROM public.automation_rules
WHERE created_by='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
DELETE FROM auth.users
WHERE id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

DO $prove_legacy$
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.financial_spaces
    WHERE id='22222222-2222-4222-8222-222222222222'
  ) OR EXISTS (
    SELECT 1 FROM public.automation_rules
    WHERE id='10000000-0000-4000-8000-000000000003'
  ) OR NOT EXISTS (
    SELECT 1 FROM auth.users
    WHERE id='cccccccc-cccc-4ccc-8ccc-cccccccccccc'
  ) THEN
    RAISE EXCEPTION 'legacy shared-space cascade fixture did not reproduce';
  END IF;
  RAISE NOTICE 'PASS: reproduced old deletion cascade that erased another still-active shared member''s space and authored rule';
END;
$prove_legacy$;
ROLLBACK;
