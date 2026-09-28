-- PRIVACY / MULTIUSER: send financial Web Push only to browser endpoints
-- bound to a server-verified Supabase Auth session of the SAME owner.
--
-- Do not run in a project containing customer data until both dispatch
-- Edge Functions have been staged with fail-closed RPC-only subscription
-- lookup. Applying this migration alone is NOT full session revocation.
--
-- Supabase Auth's signed JWT includes session_id, matching auth.sessions.id.
-- New and existing web clients already send their signed access JWT with
-- RLS table writes. A BEFORE trigger binds the endpoint server-side, without
-- trusting the caller's session_id/user_id or exposing auth.sessions via API.
--
-- Existing endpoints cannot be proven to belong to a currently active
-- session. Disable those legacy entries for privacy. On their next normal
-- authenticated upsert with browser Push permission, the trigger binds
-- their current session and permits reactivation.
--
-- Note: auth.sessions entries can linger after some timeout modes; check
-- auth.sessions.not_after and require end-to-end session revocation tests.
-- This migration does not claim to detect all revoked refresh tokens.

DO $preflight$
BEGIN
  IF to_regclass('auth.sessions') IS NULL OR
     to_regclass('public.web_push_subscriptions') IS NULL THEN
    RAISE EXCEPTION 'expected_auth_or_push_schema_missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='auth' AND table_name='sessions'
      AND column_name='not_after'
  ) THEN
    RAISE EXCEPTION 'unsupported_auth_sessions_schema';
  END IF;

  IF NOT (
    SELECT c.relrowsecurity
    FROM pg_class c
    WHERE c.oid='public.web_push_subscriptions'::regclass
  ) THEN
    RAISE EXCEPTION 'web_push_subscriptions_must_use_rls';
  END IF;
END;
$preflight$;

ALTER TABLE public.web_push_subscriptions
  ADD COLUMN IF NOT EXISTS session_id uuid,
  ADD COLUMN IF NOT EXISTS session_bound_at timestamptz;

-- Unbound old endpoints MUST NOT receive any financial notifications.
-- This does not delete subscriptions, VAPID keys, financial records or
-- notification preferences. The user's next authenticated opt-in upsert
-- (which already sends disabled_at=null) rebinds/re-enables the endpoint.
UPDATE public.web_push_subscriptions
SET disabled_at=coalesce(disabled_at,now()),
    updated_at=now()
WHERE session_id IS NULL AND disabled_at IS NULL;

-- Reject unauthenticated or forged session claims during any client
-- subscription registration or key changes. service_role updates for
-- dispatch delivery bookkeeping / disabling must continue to work.
CREATE OR REPLACE FUNCTION private.bind_web_push_to_auth_session()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $bind$
DECLARE
  v_sid_claim text;
  v_sid uuid;
BEGIN
  IF auth.role() = 'service_role' THEN
    RETURN NEW;
  END IF;

  IF auth.role() <> 'authenticated'
     OR auth.uid() IS NULL
     OR NEW.user_id IS DISTINCT FROM auth.uid()
     OR (
       TG_OP='UPDATE'
       AND OLD.user_id IS DISTINCT FROM NEW.user_id
     )
  THEN
    RAISE EXCEPTION 'web_push_user_mismatch'
      USING ERRCODE='42501';
  END IF;

  v_sid_claim := nullif(auth.jwt()->>'session_id','');
  IF v_sid_claim IS NULL THEN
    RAISE EXCEPTION 'web_push_session_required'
      USING ERRCODE='42501';
  END IF;

  BEGIN
    v_sid := v_sid_claim::uuid;
  EXCEPTION WHEN invalid_text_representation THEN
    RAISE EXCEPTION 'web_push_invalid_session_claim'
      USING ERRCODE='42501';
  END;

  IF NOT EXISTS (
    SELECT 1
    FROM auth.sessions s
    WHERE s.id=v_sid
      AND s.user_id=NEW.user_id
      AND (s.not_after IS NULL OR s.not_after>now())
  ) THEN
    RAISE EXCEPTION 'web_push_session_not_active'
      USING ERRCODE='42501';
  END IF;

  -- Replace even a maliciously supplied session_id: it is not client data.
  NEW.session_id := v_sid;
  NEW.session_bound_at := now();
  RETURN NEW;
END;
$bind$;

REVOKE ALL ON FUNCTION private.bind_web_push_to_auth_session()
FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS bind_web_push_to_auth_session
ON public.web_push_subscriptions;

CREATE TRIGGER bind_web_push_to_auth_session
BEFORE INSERT OR UPDATE OF
  user_id, endpoint, p256dh, auth_secret, disabled_at, session_id
ON public.web_push_subscriptions
FOR EACH ROW
EXECUTE FUNCTION private.bind_web_push_to_auth_session();

CREATE INDEX IF NOT EXISTS web_push_bound_active_session_idx
ON public.web_push_subscriptions(user_id,session_id)
WHERE disabled_at IS NULL AND session_id IS NOT NULL;

-- Only the service-role dispatchers may retrieve endpoint secrets.
-- Access is checked EVERY time subscriptions are selected, not merely
-- when a browser endpoint was first registered.
CREATE OR REPLACE FUNCTION public.get_active_web_push_subscriptions(
  p_user_id uuid
)
RETURNS TABLE(
  id uuid,
  endpoint text,
  p256dh text,
  auth_secret text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $active$
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required'
      USING ERRCODE='42501';
  END IF;

  RETURN QUERY
    SELECT ws.id,ws.endpoint,ws.p256dh,ws.auth_secret
    FROM public.web_push_subscriptions ws
    JOIN auth.sessions s
      ON s.id=ws.session_id
     AND s.user_id=ws.user_id
     AND (s.not_after IS NULL OR s.not_after>now())
    WHERE ws.user_id=p_user_id
      AND ws.disabled_at IS NULL
      AND ws.session_id IS NOT NULL;
END;
$active$;

REVOKE ALL ON FUNCTION public.get_active_web_push_subscriptions(uuid)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_active_web_push_subscriptions(uuid)
  TO service_role;

COMMENT ON FUNCTION public.get_active_web_push_subscriptions(uuid)
IS 'Returns financial push endpoints only for currently present, non-expired session-linked records of the selected user. service_role only.';

COMMENT ON COLUMN public.web_push_subscriptions.session_id
IS 'Authoritatively bound from a signed authenticated JWT session_id on client writes; NULL legacy endpoints are not deliverable.';

COMMENT ON COLUMN public.web_push_subscriptions.session_bound_at
IS 'Time of last successful session-bound browser registration; audit only, not a substitute for checking auth.sessions.';
