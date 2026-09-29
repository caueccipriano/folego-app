-- Follow-up to 20260929100000_bind_web_push_to_verified_auth_session.sql.
-- Client upgrade may be shipped in advance: until THIS RPC exists, the
-- Flutter client does not offer restoration of older endpoint records.
--
-- This intentionally exposes ONLY a coarse status of the currently signed-in
-- user's EXACT local endpoint. The browser's granted permission is NOT
-- evidence that an endpoint belongs to the currently signed-in user.
DO $preflight$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public'
      AND table_name='web_push_subscriptions'
      AND column_name='session_id'
  ) OR NOT (
    SELECT c.relrowsecurity
    FROM pg_class c
    WHERE c.oid='public.web_push_subscriptions'::regclass
  ) THEN
    RAISE EXCEPTION 'verified_push_session_migration_required';
  END IF;
END;
$preflight$;

CREATE OR REPLACE FUNCTION public.get_my_push_device_recovery_status(
  p_endpoint text
)
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $own_push$
DECLARE
  v_row public.web_push_subscriptions%rowtype;
  v_sid uuid;
  v_sid_text text;
BEGIN
  IF auth.role() <> 'authenticated' OR auth.uid() IS NULL THEN
    RAISE EXCEPTION 'authentication_required' USING ERRCODE='42501';
  END IF;

  v_sid_text := nullif(auth.jwt()->>'session_id','');
  IF v_sid_text IS NULL THEN
    RAISE EXCEPTION 'current_session_required' USING ERRCODE='42501';
  END IF;
  BEGIN
    v_sid := v_sid_text::uuid;
  EXCEPTION WHEN invalid_text_representation THEN
    RAISE EXCEPTION 'invalid_session_claim' USING ERRCODE='42501';
  END;

  IF NOT EXISTS(
    SELECT 1 FROM auth.sessions s
    WHERE s.id=v_sid AND s.user_id=auth.uid()
      AND (s.not_after IS NULL OR s.not_after>now())
  ) THEN
    RAISE EXCEPTION 'session_not_active' USING ERRCODE='42501';
  END IF;

  -- SECURITY DEFINER is required ONLY for the current auth.sessions check.
  -- Every endpoint lookup has a strict auth.uid() equality guard; this
  -- returns no URL or key, including when another account owns p_endpoint.
  SELECT * INTO v_row
  FROM public.web_push_subscriptions ws
  WHERE ws.user_id = auth.uid()
    AND ws.endpoint = p_endpoint
  LIMIT 1;

  IF NOT FOUND THEN RETURN 'new_device'; END IF;

  IF v_row.disabled_at IS NOT NULL
     AND v_row.session_id IS NULL
  THEN RETURN 'owned_rebind'; END IF;

  IF v_row.disabled_at IS NULL
     AND v_row.session_id IS NOT NULL
     AND v_row.session_id=v_sid
  THEN RETURN 'owned_active'; END IF;

  -- The SAME owner's existing browser subscription may be bound to an
  -- older session. Rebinding still requires this user's explicit action
  -- and a fresh server-authenticated session; never silently reassign it.
  IF v_row.disabled_at IS NULL
     AND v_row.session_id IS NOT NULL
  THEN RETURN 'owned_rebind'; END IF;

  -- No automatic reactivation of previously disabled, session-bound
  -- endpoints, and no claim of safety for an impossible legacy-active row.
  RETURN 'not_eligible';
END;
$own_push$;

REVOKE ALL ON FUNCTION
  public.get_my_push_device_recovery_status(text)
FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION
  public.get_my_push_device_recovery_status(text)
TO authenticated;

COMMENT ON FUNCTION public.get_my_push_device_recovery_status(text)
IS 'Returns only signed-in user ownership/status of one exact browser Push endpoint with strict auth.uid filter and verified current session; never leaks another account endpoint.';
