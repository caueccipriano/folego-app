-- Fictional, disposable Postgres fixture. Never run on the linked Fôlego Dev
-- database or on any database containing personal financial records.
\set ON_ERROR_STOP on
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE service_role NOLOGIN;

CREATE SCHEMA auth;
CREATE SCHEMA private;
GRANT USAGE ON SCHEMA auth, private TO authenticated;

-- Mimic auth.uid() without creating Supabase users or issuing real tokens.
CREATE FUNCTION auth.uid() RETURNS uuid
LANGUAGE sql STABLE
AS $$
  SELECT nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;

CREATE TABLE private.fixture_spaces (
  user_id uuid NOT NULL,
  space_id uuid NOT NULL,
  has_projection_inputs boolean NOT NULL DEFAULT true,
  PRIMARY KEY (user_id,space_id)
);
REVOKE ALL ON private.fixture_spaces FROM PUBLIC, anon, authenticated;

CREATE FUNCTION private.is_space_member(p_space_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1 FROM private.fixture_spaces
    WHERE user_id = auth.uid() AND space_id = p_space_id
  )
$$;
REVOKE ALL ON FUNCTION private.is_space_member(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.is_space_member(uuid) TO authenticated;

-- This fake legacy engine tests the migration's source-cloning mechanism,
-- API grants, quota timing and rollback. It deliberately replaces the real
-- 31k-character heavy finance engine ONLY in this disposable fixture.
CREATE FUNCTION public.get_projection(
  p_space_id uuid,
  p_horizon_months integer DEFAULT 12,
  p_adjustments jsonb DEFAULT '[]'::jsonb,
  p_disabled_variable_income_keys text[] DEFAULT '{}'::text[]
)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_inputs boolean;
BEGIN
  IF auth.uid() IS NULL OR NOT private.is_space_member(p_space_id) THEN
    RAISE EXCEPTION 'read_access_denied' USING ERRCODE = '42501';
  END IF;
  IF p_adjustments IS NULL OR jsonb_typeof(p_adjustments) <> 'array' THEN
    RAISE EXCEPTION 'invalid_projection_adjustments';
  END IF;
  IF jsonb_array_length(p_adjustments) > 40 THEN
    RAISE EXCEPTION 'too_many_projection_adjustments';
  END IF;
  IF EXISTS (
    SELECT 1 FROM jsonb_array_elements(p_adjustments) AS a(item)
    WHERE a.item ->> 'fixture_error' = 'true'
  ) THEN
    RAISE EXCEPTION 'fixture_engine_failure';
  END IF;
  SELECT fs.has_projection_inputs INTO v_inputs
  FROM private.fixture_spaces fs
  WHERE fs.user_id = auth.uid() AND fs.space_id = p_space_id;
  RETURN jsonb_build_object(
    'has_projection_inputs', v_inputs,
    'horizon_months', p_horizon_months,
    'months', '[]'::jsonb,
    'disabled_income', to_jsonb(p_disabled_variable_income_keys)
  );
END;
$$;

CREATE TABLE public.financial_intelligence_usage (
  user_id uuid NOT NULL,
  period_month date NOT NULL,
  capability text NOT NULL CHECK (capability IN ('simulation','ai_question')),
  used integer NOT NULL DEFAULT 0 CHECK (used >= 0),
  PRIMARY KEY(user_id,period_month,capability)
);
CREATE TABLE public.premium_grants (
  user_id uuid NOT NULL,
  grant_type text NOT NULL,
  valid_until timestamptz
);
CREATE TABLE public.store_subscriptions (
  user_id uuid NOT NULL,
  entitlement text NOT NULL,
  status text NOT NULL,
  expires_at timestamptz
);
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC, anon, authenticated;

-- Mirror the deployed Dev helper: server-issued grants and verified store
-- subscriptions skip the free counter; otherwise UPDATE is an atomic cap.
CREATE FUNCTION public.consume_free_simulation()
RETURNS TABLE(allowed boolean, remaining integer)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_uid uuid := (SELECT auth.uid());
  v_month date := date_trunc('month',now() AT TIME ZONE 'UTC')::date;
  v_used integer;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
  IF EXISTS (
    SELECT 1 FROM public.premium_grants pg
    WHERE pg.user_id=v_uid
      AND pg.grant_type IN ('complimentary','lifetime')
      AND (pg.valid_until IS NULL OR pg.valid_until>now())
  ) OR EXISTS (
    SELECT 1 FROM public.store_subscriptions s
    WHERE s.user_id=v_uid AND s.entitlement='premium'
      AND s.status='active'
      AND (s.expires_at IS NULL OR s.expires_at>now())
  ) THEN
    RETURN QUERY SELECT true,-1;
    RETURN;
  END IF;

  INSERT INTO public.financial_intelligence_usage(
    user_id,period_month,capability,used
  )
  VALUES(v_uid,v_month,'simulation',0)
  ON CONFLICT DO NOTHING;

  UPDATE public.financial_intelligence_usage
  SET used=used+1
  WHERE user_id=v_uid AND period_month=v_month
    AND capability='simulation' AND used<3
  RETURNING used INTO v_used;

  IF v_used IS NULL THEN
    RETURN QUERY SELECT false,0;
  ELSE
    RETURN QUERY SELECT true,3-v_used;
  END IF;
END;
$$;
REVOKE ALL ON FUNCTION public.consume_free_simulation() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.consume_free_simulation() TO authenticated;

INSERT INTO private.fixture_spaces(user_id,space_id,has_projection_inputs)
VALUES
('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','11111111-1111-4111-8111-111111111111',true),
('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','22222222-2222-4222-8222-222222222222',true),
('cccccccc-cccc-4ccc-8ccc-cccccccccccc','33333333-3333-4333-8333-333333333333',false),
('dddddddd-dddd-4ddd-8ddd-dddddddddddd','44444444-4444-4444-8444-444444444444',true);
