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
SECURITY INVOKER
SET search_path = ''
AS $own_push$
DECLARE
  v_row public.web_push_subscriptions%rowtype;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'authentication_required' USING ERRCODE='42501';
  END IF;

  -- Direct user-owned RLS SELECT, never a SECURITY DEFINER cross-user
  -- endpoint lookup. Identical browser permission on another account is
  -- intentionally insufficient to produce an owned result.
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
  THEN RETURN 'owned_active'; END IF;

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
IS 'Returns only signed-in user ownership/status of one exact browser Push endpoint under existing RLS; never leaks another account endpoint.';
