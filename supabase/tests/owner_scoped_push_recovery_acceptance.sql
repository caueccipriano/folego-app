-- Disposable DB acceptance for one-tap recovery, separate from Supabase Dev.
-- Apply fixture + PR18 session-binding migration + new recovery RPC first.
\set ON_ERROR_STOP on
DO $permissions$
BEGIN
  IF has_function_privilege(
    'anon',
    'public.get_my_push_device_recovery_status(text)',
    'EXECUTE'
  ) OR NOT has_function_privilege(
    'authenticated',
    'public.get_my_push_device_recovery_status(text)',
    'EXECUTE'
  ) OR has_table_privilege(
    'authenticated','auth.sessions','SELECT'
  ) THEN
    RAISE EXCEPTION 'unsafe_privileges_in_recovery';
  END IF;
  RAISE NOTICE 'PASS: only authenticated users may ask owner-scoped status; auth.sessions is private';
END;
$permissions$;

-- A's former own browser endpoint is still present, but deliberately
-- disabled by PR18 until A explicitly asks to restore it.
SET ROLE authenticated;
SELECT set_config(
  'request.jwt.claim.sub','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false
);
SELECT set_config('request.jwt.claim.role','authenticated',false);
SELECT set_config(
  'request.jwt.claims',
  '{"session_id":"a0000000-0000-4000-8000-000000000001"}',
  false
);

DO $a_legacy$
BEGIN
  IF public.get_my_push_device_recovery_status(
    'https://push.synthetic.invalid/a-legacy'
  ) <> 'owned_rebind' THEN
    RAISE EXCEPTION 'A could not find own explicitly restorable legacy endpoint';
  END IF;

  IF public.get_my_push_device_recovery_status(
    'https://push.synthetic.invalid/unknown-browser'
  ) <> 'new_device' THEN
    RAISE EXCEPTION 'unknown device was mistaken for owned enrollment';
  END IF;
  RAISE NOTICE 'PASS: A sees own legacy rebind without silently enrolling any unknown device';
END;
$a_legacy$;

DO $a_rebind$
BEGIN
  UPDATE public.web_push_subscriptions
  SET disabled_at=NULL, updated_at=now()
  WHERE user_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
    AND endpoint='https://push.synthetic.invalid/a-legacy';

  IF public.get_my_push_device_recovery_status(
    'https://push.synthetic.invalid/a-legacy'
  ) <> 'owned_active' THEN
    RAISE EXCEPTION 'explicit A restoration failed signed session binding';
  END IF;
  RAISE NOTICE 'PASS: authenticated A explicitly rebinds own endpoint to signed A1 session';
END;
$a_rebind$;

-- A session A2 signs in on the SAME user's existing browser endpoint.
-- The old A1 session must not be mistaken for A2's current live session.
SELECT set_config(
  'request.jwt.claims',
  '{"session_id":"a0000000-0000-4000-8000-000000000002"}',
  false
);
DO $a2_recovery$
BEGIN
  IF public.get_my_push_device_recovery_status(
    'https://push.synthetic.invalid/a-legacy'
  ) <> 'owned_rebind' THEN
    RAISE EXCEPTION 'same-owner endpoint tied to another session was called active';
  END IF;
  UPDATE public.web_push_subscriptions
  SET disabled_at=NULL, updated_at=now()
  WHERE user_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
    AND endpoint='https://push.synthetic.invalid/a-legacy';

  IF public.get_my_push_device_recovery_status(
    'https://push.synthetic.invalid/a-legacy'
  ) <> 'owned_active' THEN
    RAISE EXCEPTION 'same owner failed to rebind explicit new session';
  END IF;
  RAISE NOTICE 'PASS: changed login for same owner requires explicit new-session rebind';
END;
$a2_recovery$;
RESET ROLE;

-- Different user B has their own valid session and sees only new_device
-- for A's endpoint. Same browser permission is NOT consent for B.
SET ROLE authenticated;
SELECT set_config(
  'request.jwt.claim.sub','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',false
);
SELECT set_config('request.jwt.claim.role','authenticated',false);
SELECT set_config(
  'request.jwt.claims',
  '{"session_id":"b0000000-0000-4000-8000-000000000001"}',
  false
);

DO $b_isolation$
DECLARE v_count integer;
BEGIN
  IF public.get_my_push_device_recovery_status(
    'https://push.synthetic.invalid/a-legacy'
  ) <> 'new_device' THEN
    RAISE EXCEPTION 'B inherited ownership of A device by browser permission';
  END IF;

  UPDATE public.web_push_subscriptions
  SET disabled_at=NULL
  WHERE endpoint='https://push.synthetic.invalid/a-legacy';
  GET DIAGNOSTICS v_count=ROW_COUNT;
  IF v_count<>0 THEN
    RAISE EXCEPTION 'B modified A row across RLS';
  END IF;
  RAISE NOTICE 'PASS: B neither sees nor modifies A historical device';
END;
$b_isolation$;

-- B taps explicit "activate this device", first unsubscribes A locally,
-- and then receives a NEW browser subscription. Browser simulation is
-- asserted by Flutter JS contract tests; SQL covers the new B row.
INSERT INTO public.web_push_subscriptions(
  user_id,endpoint,p256dh,auth_secret
) VALUES(
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
  'https://push.synthetic.invalid/b-new-endpoint',
  'b-synthetic-key','b-synthetic-auth'
);

DO $b_enrollment$
BEGIN
  IF public.get_my_push_device_recovery_status(
    'https://push.synthetic.invalid/b-new-endpoint'
  ) <> 'owned_active' THEN
    RAISE EXCEPTION 'B explicit new device was not bound to B session';
  END IF;
  RAISE NOTICE 'PASS: B explicit opt-in gets own fresh independent endpoint';
END;
$b_enrollment$;

-- B cannot use an otherwise valid A session UUID in their claims.
SELECT set_config(
  'request.jwt.claims',
  '{"session_id":"a0000000-0000-4000-8000-000000000002"}',
  false
);
DO $b_forged$
DECLARE v_error text; v_rejected boolean:=false;
BEGIN
  BEGIN
    PERFORM public.get_my_push_device_recovery_status(
      'https://push.synthetic.invalid/b-new-endpoint'
    );
  EXCEPTION WHEN insufficient_privilege THEN
    GET STACKED DIAGNOSTICS v_error=MESSAGE_TEXT;
    IF v_error <> 'session_not_active' THEN RAISE; END IF;
    v_rejected:=true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'B could fake A signed session when reading own endpoint';
  END IF;
  RAISE NOTICE 'PASS: mismatched signed session claims fail closed';
END;
$b_forged$;
RESET ROLE;

-- A2's session is revoked, including when its browser is completely closed.
-- The RPC must not report active after an actual auth.sessions removal.
DELETE FROM auth.sessions
WHERE id='a0000000-0000-4000-8000-000000000002';

SET ROLE authenticated;
SELECT set_config(
  'request.jwt.claim.sub','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false
);
SELECT set_config('request.jwt.claim.role','authenticated',false);
SELECT set_config(
  'request.jwt.claims',
  '{"session_id":"a0000000-0000-4000-8000-000000000002"}',
  false
);
DO $revoked$
DECLARE v_blocked boolean:=false;
BEGIN
  BEGIN
    PERFORM public.get_my_push_device_recovery_status(
      'https://push.synthetic.invalid/a-legacy'
    );
  EXCEPTION WHEN insufficient_privilege THEN
    v_blocked:=true;
  END;
  IF NOT v_blocked THEN
    RAISE EXCEPTION 'revoked session was allowed to recover legacy push';
  END IF;
  RAISE NOTICE 'PASS: revoked A session cannot restore a browser endpoint';
END;
$revoked$;
RESET ROLE;

SET ROLE service_role;
SELECT set_config('request.jwt.claim.role','service_role',false);
DO $delivery$
BEGIN
  IF EXISTS(
    SELECT 1 FROM public.get_active_web_push_subscriptions(
      'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
    )
  ) OR (SELECT count(*) FROM public.get_active_web_push_subscriptions(
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'
  ))<>1 THEN
    RAISE EXCEPTION 'restoring A/B devices weakened server verified-delivery rules';
  END IF;
  RAISE NOTICE 'PASS: revoked A device not deliverable; unrelated B remains deliverable';
END;
$delivery$;
RESET ROLE;
