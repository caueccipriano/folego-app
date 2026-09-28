-- Meter advanced projections at the RPC boundary, not solely in Flutter.
-- Deploy the backward-compatible Flutter client BEFORE this migration: older
-- clients still call consume_free_simulation() after get_projection() and
-- would otherwise charge two simulations during a mixed-version rollout.
--
-- Keep the original heavy projection engine intact in the non-exposed schema.
-- The old public function name is replaced with a thin, quota-enforcing wrapper.
-- No financial event/balance is written; only a legitimate simulation consumes
-- the existing per-user usage counter in the same transaction.
DO $clone_projection$
DECLARE
  v_original text;
  v_original_signature constant text := 'CREATE OR REPLACE FUNCTION public.get_projection(';
BEGIN
  IF to_regprocedure('private.get_projection_core(uuid,integer,jsonb,text[])')
      IS NOT NULL THEN
    RAISE EXCEPTION 'private_projection_core_already_exists';
  END IF;

  SELECT pg_get_functiondef(
    to_regprocedure('public.get_projection(uuid,integer,jsonb,text[])')
  ) INTO v_original;

  IF v_original IS NULL
     OR left(v_original, length(v_original_signature)) <> v_original_signature
     OR position('has_projection_inputs' IN v_original) = 0
     OR position('private.is_space_member(p_space_id)' IN v_original) = 0
  THEN
    RAISE EXCEPTION 'unexpected_projection_core_version';
  END IF;

  EXECUTE replace(
    v_original,
    v_original_signature,
    'CREATE OR REPLACE FUNCTION private.get_projection_core('
  );
END;
$clone_projection$;

-- `authenticated` currently has USAGE on the private schema, so explicitly
-- revoke function EXECUTE, including PostgreSQL's default PUBLIC grant.
REVOKE ALL ON FUNCTION private.get_projection_core(
  uuid, integer, jsonb, text[]
) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.get_projection(
  p_space_id uuid,
  p_horizon_months integer DEFAULT 12,
  p_adjustments jsonb DEFAULT '[]'::jsonb,
  p_disabled_variable_income_keys text[] DEFAULT '{}'::text[]
)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = ''
AS $metered_projection$
DECLARE
  v_result jsonb;
  v_allowed boolean;
  v_remaining integer;
  v_is_scenario boolean;
BEGIN
  -- Preserve the existing per-space authorization even for baseline reads.
  IF auth.uid() IS NULL OR NOT private.is_space_member(p_space_id) THEN
    RAISE EXCEPTION 'read_access_denied' USING ERRCODE = '42501';
  END IF;

  -- Reject invalid adjustment arrays before checking the quota. The core
  -- applies the same checks again and validates each adjustment individually.
  IF p_adjustments IS NULL OR jsonb_typeof(p_adjustments) <> 'array' THEN
    RAISE EXCEPTION 'invalid_projection_adjustments';
  END IF;
  IF jsonb_array_length(p_adjustments) > 40 THEN
    RAISE EXCEPTION 'too_many_projection_adjustments';
  END IF;

  -- Plain baseline reads, including Home, never consume a simulation.
  -- Both hypothetical adjustments and disabled income are paid scenarios.
  v_is_scenario :=
    jsonb_array_length(p_adjustments) > 0
    OR coalesce(cardinality(p_disabled_variable_income_keys), 0) > 0;

  IF v_is_scenario THEN
    -- Reserve quota BEFORE the expensive projection engine runs. Concurrent
    -- calls share the existing UPDATE ... used < 3 row lock and cannot race.
    SELECT quota.allowed, quota.remaining INTO v_allowed, v_remaining
    FROM public.consume_free_simulation() AS quota
    LIMIT 1;

    IF NOT coalesce(v_allowed, false) THEN
      RAISE EXCEPTION 'free_simulation_limit_reached'
        USING ERRCODE = 'P0001';
    END IF;
    IF v_remaining IS NULL THEN
      RAISE EXCEPTION 'unexpected_simulation_quota_response';
    END IF;
  END IF;

  -- A failing computation raises an exception and the entire RPC transaction
  -- rolls back, including any provisional quota reservation above.
  v_result := private.get_projection_core(
    p_space_id,
    p_horizon_months,
    p_adjustments,
    p_disabled_variable_income_keys
  );

  IF v_is_scenario THEN
    IF coalesce((v_result ->> 'has_projection_inputs')::boolean, false)
    THEN
      -- Authoritative handshake: newer Flutter clients must not call the
      -- legacy quota helper again for this successful simulation.
      v_result := jsonb_set(
        v_result, '{simulation_quota_enforced}', 'true'::jsonb, true
      );
    ELSIF v_remaining >= 0 THEN
      -- Incomplete plans must not consume a free simulation. Refund inside
      -- this same transaction, with the user's own server-side identity.
      -- Paid grants return remaining=-1 and never touch the counter.
      UPDATE public.financial_intelligence_usage
      SET used = used - 1
      WHERE user_id = (SELECT auth.uid())
        AND period_month = date_trunc(
          'month', now() at time zone 'UTC'
        )::date
        AND capability = 'simulation'
        AND used > 0;

      IF NOT FOUND THEN
        RAISE EXCEPTION 'simulation_quota_refund_failed';
      END IF;
    END IF;
  END IF;

  RETURN v_result;
END;
$metered_projection$;

REVOKE ALL ON FUNCTION public.get_projection(
  uuid, integer, jsonb, text[]
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_projection(
  uuid, integer, jsonb, text[]
) TO authenticated;

COMMENT ON FUNCTION public.get_projection(uuid,integer,jsonb,text[]) IS
  'Space-scoped projection RPC. Baseline is free; hypothetical scenarios are metered atomically at the database boundary.';

DO $assert_projection_permissions$
BEGIN
  IF has_function_privilege(
    'authenticated',
    'private.get_projection_core(uuid,integer,jsonb,text[])',
    'EXECUTE'
  ) OR has_function_privilege(
    'anon',
    'private.get_projection_core(uuid,integer,jsonb,text[])',
    'EXECUTE'
  ) OR has_function_privilege(
    'anon',
    'public.get_projection(uuid,integer,jsonb,text[])',
    'EXECUTE'
  ) OR NOT has_function_privilege(
    'authenticated',
    'public.get_projection(uuid,integer,jsonb,text[])',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'projection_quota_permission_postcondition_failed';
  END IF;
END;
$assert_projection_permissions$;

NOTIFY pgrst, 'reload schema';
