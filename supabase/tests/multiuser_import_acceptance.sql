-- Post-migration authorization and cross-tenant referential integrity,
-- entirely on synthetic database rows. Never connect this test to Dev.
\set ON_ERROR_STOP on

DO $roles$
BEGIN
  IF has_function_privilege(
    'authenticated', 'private.enforce_import_row_space_refs()', 'EXECUTE'
  ) OR has_function_privilege(
    'anon', 'private.enforce_import_row_space_refs()', 'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'new privileged trigger unexpectedly directly executable';
  END IF;
  IF has_table_privilege('anon','public.import_rows','SELECT') THEN
    RAISE EXCEPTION 'anonymous role can read import staging';
  END IF;
  RAISE NOTICE 'PASS: private trigger and anonymous staging privileges';
END;
$roles$;

SET ROLE authenticated;
SELECT set_config(
  'request.jwt.claim.sub','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false
);

DO $owner_a$
DECLARE
  v_case record;
  v_msg text;
  v_rows integer;
  v_a constant uuid := 'a0000000-0000-4000-8000-000000000010';
  v_attempts integer := 0;
BEGIN
  IF (SELECT count(*) FROM public.import_rows) <> 1 THEN
    RAISE EXCEPTION 'A sees cross-tenant rows without membership';
  END IF;

  -- Seed all four foreign-key targets in B's space, plus the imported
  -- financial event. The normal UPDATE RLS allows writing only A's own row.
  FOR v_case IN
    SELECT *
    FROM (VALUES
      ('batch_id'::text,'b0000000-0000-4000-8000-000000000001'::uuid,
       'import_batch_not_in_space'::text),
      ('category_id','b0000000-0000-4000-8000-000000000002'::uuid,
       'import_category_not_in_space'),
      ('counterpart_account_id','b0000000-0000-4000-8000-000000000003'::uuid,
       'import_counterpart_not_in_space'),
      ('invoice_id','b0000000-0000-4000-8000-000000000004'::uuid,
       'import_invoice_not_in_space'),
      ('imported_event_id','b0000000-0000-4000-8000-000000000005'::uuid,
       'import_backing_event_not_in_space')
    ) AS x(target_column,target_id,expected_error)
  LOOP
    BEGIN
      EXECUTE format(
        'UPDATE public.import_rows SET %I = $1 WHERE id = $2',
        v_case.target_column
      ) USING v_case.target_id,v_a;

      RAISE EXCEPTION 'cross_reference_was_accepted: %',v_case.target_column;
    EXCEPTION WHEN foreign_key_violation THEN
      GET STACKED DIAGNOSTICS v_msg = MESSAGE_TEXT;
      IF v_msg IS DISTINCT FROM v_case.expected_error THEN
        RAISE EXCEPTION 'wrong rejection for %: %',
          v_case.target_column,v_msg;
      END IF;
    END;
    v_attempts := v_attempts + 1;
  END LOOP;

  IF v_attempts <> 5 THEN RAISE EXCEPTION 'missing cross-ref cases'; END IF;
  SELECT count(*) INTO v_rows FROM public.import_rows
  WHERE id=v_a
    AND batch_id='a0000000-0000-4000-8000-000000000001'
    AND category_id='a0000000-0000-4000-8000-000000000002'
    AND counterpart_account_id IS NULL AND invoice_id IS NULL
    AND imported_event_id IS NULL;
  IF v_rows <> 1 THEN RAISE EXCEPTION 'invalid cross refs modified A row'; END IF;

  -- Legitimate in-space category, counterpart and invoice remain writable.
  UPDATE public.import_rows SET
    category_id='a0000000-0000-4000-8000-000000000002',
    counterpart_account_id='a0000000-0000-4000-8000-000000000003',
    invoice_id='a0000000-0000-4000-8000-000000000004'
  WHERE id=v_a;
  IF NOT FOUND THEN RAISE EXCEPTION 'valid same-space review was blocked'; END IF;

  -- Backward-compatible card purchases are first accepted by the new guard,
  -- then normalized by the legacy resolver (both BEFORE UPDATE triggers).
  UPDATE public.import_rows SET status='imported',
    imported_event_id='a0000000-0000-4000-8000-000000000006'
  WHERE id=v_a;
  IF (SELECT imported_event_id FROM public.import_rows WHERE id=v_a)
     IS DISTINCT FROM
     'a0000000-0000-4000-8000-000000000005'::uuid
  THEN RAISE EXCEPTION 'existing card purchase ID resolver was broken'; END IF;

  UPDATE public.import_rows SET status='imported',
    imported_event_id='a0000000-0000-4000-8000-000000000007'
  WHERE id=v_a;
  IF (SELECT imported_event_id FROM public.import_rows WHERE id=v_a)
     IS DISTINCT FROM
     'a0000000-0000-4000-8000-000000000005'::uuid
  THEN RAISE EXCEPTION 'existing card payment ID resolver was broken'; END IF;

  RAISE NOTICE 'PASS: A denied all five cross-space references, valid imports and backing-ID resolvers preserved';
END;
$owner_a$;
RESET ROLE;

SET ROLE authenticated;
SELECT set_config(
  'request.jwt.claim.sub','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',false
);

DO $viewer_b$
DECLARE v_updated integer;
BEGIN
  -- B is an explicit VIEWER in A's shared space and owns B's independent
  -- space. Seeing A's row is correct only because a membership exists.
  IF (SELECT count(*) FROM public.import_rows) <> 2 THEN
    RAISE EXCEPTION 'viewer membership or B private rows not visible';
  END IF;

  UPDATE public.import_rows
  SET category_id='b0000000-0000-4000-8000-000000000002'
  WHERE id='a0000000-0000-4000-8000-000000000010';
  GET DIAGNOSTICS v_updated = ROW_COUNT;
  IF v_updated <> 0 THEN
    RAISE EXCEPTION 'viewer changed another owner''s shared data';
  END IF;

  UPDATE public.import_rows
  SET category_id='b0000000-0000-4000-8000-000000000002'
  WHERE id='b0000000-0000-4000-8000-000000000010';
  GET DIAGNOSTICS v_updated = ROW_COUNT;
  IF v_updated <> 1 THEN
    RAISE EXCEPTION 'B owner unexpectedly cannot update private import';
  END IF;

  RAISE NOTICE 'PASS: legitimate shared viewer reads A but cannot write; B controls only owned data';
END;
$viewer_b$;
RESET ROLE;

-- The two legitimate shared-space writers have separate identities.
-- Neither has any membership in B's independently owned space.
SET ROLE authenticated;
SELECT set_config(
  'request.jwt.claim.sub','cccccccc-cccc-4ccc-8ccc-cccccccccccc',false
);
DO $member_c$
DECLARE v_rows integer;
BEGIN
  IF (SELECT count(*) FROM public.import_rows) <> 1 THEN
    RAISE EXCEPTION 'C member saw an unrelated private space';
  END IF;
  UPDATE public.import_rows
  SET category_id='a0000000-0000-4000-8000-000000000002'
  WHERE id='a0000000-0000-4000-8000-000000000010';
  GET DIAGNOSTICS v_rows=ROW_COUNT;
  IF v_rows<>1 THEN RAISE EXCEPTION 'valid member was unable to write'; END IF;
  RAISE NOTICE 'PASS: a legitimate shared member writes only authorized space A';
END;
$member_c$;
RESET ROLE;

SET ROLE authenticated;
SELECT set_config(
  'request.jwt.claim.sub','dddddddd-dddd-4ddd-8ddd-dddddddddddd',false
);
DO $admin_d$
DECLARE v_rows integer;
BEGIN
  IF (SELECT count(*) FROM public.import_rows) <> 1 THEN
    RAISE EXCEPTION 'D admin saw an unrelated private space';
  END IF;
  UPDATE public.import_rows
  SET category_id='a0000000-0000-4000-8000-000000000002'
  WHERE id='a0000000-0000-4000-8000-000000000010';
  GET DIAGNOSTICS v_rows=ROW_COUNT;
  IF v_rows<>1 THEN RAISE EXCEPTION 'valid admin was unable to write'; END IF;
  RAISE NOTICE 'PASS: a legitimate shared admin writes only authorized space A';
END;
$admin_d$;
RESET ROLE;

DO $post$
BEGIN
  IF (SELECT count(*) FROM public.import_rows
       WHERE id='a0000000-0000-4000-8000-000000000010') <> 1
  OR (SELECT count(*) FROM public.import_rows
       WHERE id='b0000000-0000-4000-8000-000000000010') <> 1
  THEN
    RAISE EXCEPTION 'tenant records were lost or duplicated';
  END IF;
  RAISE NOTICE 'PASS: both synthetic tenant records survived unchanged in identity';
END;
$post$;
