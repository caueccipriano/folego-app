-- End-to-end SQL contract using ONLY synthetic users/spaces in ephemeral CI.
\set ON_ERROR_STOP on

DO $security$
BEGIN
  IF to_regprocedure('private.get_projection_core(uuid,integer,jsonb,text[])')
     IS NULL THEN
    RAISE EXCEPTION 'private core was not created';
  END IF;
  IF has_function_privilege(
    'authenticated','private.get_projection_core(uuid,integer,jsonb,text[])','EXECUTE'
  ) OR has_function_privilege(
    'anon','private.get_projection_core(uuid,integer,jsonb,text[])','EXECUTE'
  ) OR has_function_privilege(
    'anon','public.get_projection(uuid,integer,jsonb,text[])','EXECUTE'
  ) OR NOT has_function_privilege(
    'authenticated','public.get_projection(uuid,integer,jsonb,text[])','EXECUTE'
  ) THEN
    RAISE EXCEPTION 'exposed function grant contract failed';
  END IF;
  IF (SELECT p.provolatile <> 'v' FROM pg_proc p
      WHERE p.oid='public.get_projection(uuid,integer,jsonb,text[])'::regprocedure)
  THEN
    RAISE EXCEPTION 'public metered function must be VOLATILE';
  END IF;
  RAISE NOTICE 'PASS: function isolation and privileges';
END;
$security$;

-- A is a fictional free user; all four calls use RPC as authenticated,
-- not bypassing application restrictions with a service-role key.
SET ROLE authenticated;
SELECT set_config(
  'request.jwt.claim.sub', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', false
);

DO $free_user$
DECLARE
  v jsonb;
  v_a constant uuid := '11111111-1111-4111-8111-111111111111';
  v_b constant uuid := '22222222-2222-4222-8222-222222222222';
  v_adjust jsonb :=
    '[{"id":"scenario-a","name":"Fictional purchase",
       "component":"direct_expense","amount_delta":40,
       "frequency":"monthly","starts_on":"2026-09-29"}]'::jsonb;
BEGIN
  v := public.get_projection(v_a);
  IF v ? 'simulation_quota_enforced' THEN
    RAISE EXCEPTION 'baseline was incorrectly metered';
  END IF;

  v := public.get_projection(v_a, 12, v_adjust, '{}'::text[]);
  IF v->>'simulation_quota_enforced' IS DISTINCT FROM 'true' THEN
    RAISE EXCEPTION 'adjusted simulation was not metered';
  END IF;

  v := public.get_projection(v_a, 12, '[]'::jsonb, ARRAY['hypothetical-income']);
  IF v->>'simulation_quota_enforced' IS DISTINCT FROM 'true' THEN
    RAISE EXCEPTION 'disabled income simulation bypassed meter';
  END IF;

  v := public.get_projection(v_a, 12, v_adjust, '{}'::text[]);
  IF v->>'simulation_quota_enforced' IS DISTINCT FROM 'true' THEN
    RAISE EXCEPTION 'third free simulation failed unexpectedly';
  END IF;

  BEGIN
    PERFORM public.get_projection(v_a, 12, v_adjust, '{}'::text[]);
    RAISE EXCEPTION 'fourth_simulation_should_be_denied';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> 'free_simulation_limit_reached' THEN RAISE; END IF;
  END;

  -- This validation must run BEFORE quota; a malformed payload may not be
  -- mistakenly classified as a quota-exhaustion error.
  BEGIN
    PERFORM public.get_projection(v_a, 12, '{}'::jsonb, '{}'::text[]);
    RAISE EXCEPTION 'invalid_payload_should_be_denied';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> 'invalid_projection_adjustments' THEN RAISE; END IF;
  END;

  BEGIN
    PERFORM public.get_projection(v_b);
    RAISE EXCEPTION 'cross_space_should_be_denied';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> 'read_access_denied' THEN RAISE; END IF;
  END;

  RAISE NOTICE 'PASS: free baseline, 3 allowed, 4th denied, validation and cross-space';
END;
$free_user$;
RESET ROLE;

DO $check_a$
BEGIN
  IF (SELECT used FROM public.financial_intelligence_usage
       WHERE user_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
         AND capability='simulation') IS DISTINCT FROM 3 THEN
    RAISE EXCEPTION 'free usage counter does not equal three';
  END IF;
END;
$check_a$;

-- Failed computation rolls back its provisional reservation. B has an
-- independent quota and cannot access A's space.
SET ROLE authenticated;
SELECT set_config(
  'request.jwt.claim.sub', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', false
);
DO $failure$
BEGIN
  BEGIN
    PERFORM public.get_projection(
      '22222222-2222-4222-8222-222222222222',
      12,'[{"fixture_error":true}]'::jsonb,'{}'::text[]
    );
    RAISE EXCEPTION 'engine_error_should_be_reported';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> 'fixture_engine_failure' THEN RAISE; END IF;
  END;
  BEGIN
    PERFORM public.get_projection(
      '11111111-1111-4111-8111-111111111111'
    );
    RAISE EXCEPTION 'B_must_not_read_A';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> 'read_access_denied' THEN RAISE; END IF;
  END;
  RAISE NOTICE 'PASS: engine failure and cross-space isolation for B';
END;
$failure$;
RESET ROLE;

DO $check_b$
BEGIN
  IF coalesce((
    SELECT used FROM public.financial_intelligence_usage
    WHERE user_id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'
      AND capability='simulation'
  ),0) <> 0 THEN
    RAISE EXCEPTION 'failed projection leaked a quota debit';
  END IF;
END;
$check_b$;

-- Incomplete planning data returns an unmetered response and undoes the
-- tentative free quota debit while keeping other users' counters unchanged.
SET ROLE authenticated;
SELECT set_config(
  'request.jwt.claim.sub', 'cccccccc-cccc-4ccc-8ccc-cccccccccccc', false
);
DO $no_inputs$
DECLARE v jsonb;
BEGIN
  v := public.get_projection(
    '33333333-3333-4333-8333-333333333333',
    12,'[{"id":"synthetic"}]'::jsonb,'{}'::text[]
  );
  IF v ? 'simulation_quota_enforced'
    OR coalesce((v->>'has_projection_inputs')::boolean,true)
  THEN
    RAISE EXCEPTION 'incomplete plan was treated as a paid scenario';
  END IF;
  RAISE NOTICE 'PASS: missing-input refund and no premium handshake';
END;
$no_inputs$;
RESET ROLE;

DO $check_c$
BEGIN
  IF coalesce((
    SELECT used FROM public.financial_intelligence_usage
    WHERE user_id='cccccccc-cccc-4ccc-8ccc-cccccccccccc'
      AND capability='simulation'
  ),0) <> 0 THEN
    RAISE EXCEPTION 'missing-input refund did not restore free quota';
  END IF;
END;
$check_c$;

-- Only the server-side fixture can issue Premium. Client-supplied flags
-- were never part of this RPC contract.
INSERT INTO public.premium_grants(user_id,grant_type,valid_until)
VALUES('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','complimentary',now()+interval '1 day');

SET ROLE authenticated;
SELECT set_config(
  'request.jwt.claim.sub', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', false
);
DO $premium$
DECLARE v jsonb;
BEGIN
  v := public.get_projection(
    '11111111-1111-4111-8111-111111111111',
    12,'[{"id":"premium-what-if"}]'::jsonb,'{}'::text[]
  );
  IF v->>'simulation_quota_enforced' IS DISTINCT FROM 'true' THEN
    RAISE EXCEPTION 'verified Premium was not allowed';
  END IF;
  RAISE NOTICE 'PASS: verified Premium may simulate beyond free cap';
END;
$premium$;
RESET ROLE;

DELETE FROM public.premium_grants
WHERE user_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

SET ROLE authenticated;
SELECT set_config(
  'request.jwt.claim.sub', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', false
);
DO $revoked$
BEGIN
  BEGIN
    PERFORM public.get_projection(
      '11111111-1111-4111-8111-111111111111',
      12,'[{"id":"revoked"}]'::jsonb,'{}'::text[]
    );
    RAISE EXCEPTION 'revoked_grant_should_not_allow_unlimited_scenarios';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> 'free_simulation_limit_reached' THEN RAISE; END IF;
  END;
  RAISE NOTICE 'PASS: revoked Premium enforces exhausted free cap';
END;
$revoked$;
RESET ROLE;

-- A fourth fictional user starts with 2/3 used for the parallel process test.
INSERT INTO public.financial_intelligence_usage(
  user_id,period_month,capability,used
)
VALUES(
  'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
  date_trunc('month',now() AT TIME ZONE 'UTC')::date,
  'simulation',2
);
\echo 'PASS: isolated SQL acceptance completed. Concurrent last-attempt test follows.'
