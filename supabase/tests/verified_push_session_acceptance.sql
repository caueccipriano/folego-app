-- Real new migration, disposable synthetic roles and browser endpoints.
\set ON_ERROR_STOP on

DO $postmigration$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger t
    WHERE t.tgrelid='public.web_push_subscriptions'::regclass
      AND t.tgname='bind_web_push_to_auth_session'
      AND NOT t.tgisinternal
  ) THEN
    RAISE EXCEPTION 'session binding trigger not installed';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.web_push_subscriptions ws
    WHERE ws.session_id IS NULL AND ws.disabled_at IS NULL
  ) THEN
    RAISE EXCEPTION 'old unverified endpoint remained active after migration';
  END IF;

  IF has_function_privilege(
    'authenticated','public.get_active_web_push_subscriptions(uuid)','EXECUTE'
  ) OR has_function_privilege(
    'anon','public.get_active_web_push_subscriptions(uuid)','EXECUTE'
  ) OR has_function_privilege(
    'authenticated','private.bind_web_push_to_auth_session()','EXECUTE'
  ) THEN
    RAISE EXCEPTION 'privileged push session gate exposed to a public role';
  END IF;
  RAISE NOTICE 'PASS: legacy endpoint disabled; session trigger private; active-key API service-only';
END;
$postmigration$;

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

DO $a_device1$
DECLARE v_bound uuid; v_count integer;
BEGIN
  UPDATE public.web_push_subscriptions
  SET session_id='b0000000-0000-4000-8000-000000000001',
      disabled_at=NULL
  WHERE endpoint='https://push.synthetic.invalid/a-legacy'
  RETURNING session_id INTO v_bound;

  IF v_bound IS DISTINCT FROM
      'a0000000-0000-4000-8000-000000000001'::uuid THEN
    RAISE EXCEPTION 'caller forged or bypassed authenticated session binding';
  END IF;
  SELECT count(*) INTO v_count
  FROM public.web_push_subscriptions
  WHERE endpoint='https://push.synthetic.invalid/a-legacy'
    AND session_bound_at IS NOT NULL
    AND disabled_at IS NULL;
  IF v_count<>1 THEN
    RAISE EXCEPTION 'legitimate legacy re-registration was blocked';
  END IF;

  RAISE NOTICE 'PASS: old endpoint rebinds to actual signed A device session; forged B session overwritten';
END;
$a_device1$;

DO $invalid$
DECLARE v_error text;
BEGIN
  PERFORM set_config(
    'request.jwt.claims',
    '{"session_id":"a0000000-0000-4000-8000-000000000003"}',
    true
  );
  BEGIN
    INSERT INTO public.web_push_subscriptions(
      user_id,endpoint,p256dh,auth_secret
    ) VALUES(
      'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      'https://push.synthetic.invalid/a-expired','key','secret'
    );
    RAISE EXCEPTION 'expired_device_was_allowed';
  EXCEPTION WHEN insufficient_privilege THEN
    GET STACKED DIAGNOSTICS v_error=MESSAGE_TEXT;
    IF v_error<>'web_push_session_not_active' THEN
      RAISE EXCEPTION 'unexpected expired-session error: %',v_error;
    END IF;
  END;

  PERFORM set_config(
    'request.jwt.claims',
    '{"session_id":"b0000000-0000-4000-8000-000000000001"}',
    true
  );
  BEGIN
    INSERT INTO public.web_push_subscriptions(
      user_id,endpoint,p256dh,auth_secret
    ) VALUES(
      'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      'https://push.synthetic.invalid/a-claims-b','key','secret'
    );
    RAISE EXCEPTION 'other_user_session_was_allowed';
  EXCEPTION WHEN insufficient_privilege THEN
    GET STACKED DIAGNOSTICS v_error=MESSAGE_TEXT;
    IF v_error<>'web_push_session_not_active' THEN
      RAISE EXCEPTION 'unexpected mismatched-session error: %',v_error;
    END IF;
  END;

  PERFORM set_config(
    'request.jwt.claims',
    '{"session_id":"a0000000-0000-4000-8000-000000000001"}',
    true
  );
  BEGIN
    INSERT INTO public.web_push_subscriptions(
      user_id,endpoint,p256dh,auth_secret
    ) VALUES(
      'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      'https://push.synthetic.invalid/a-impersonate-b','key','secret'
    );
    RAISE EXCEPTION 'caller_impersonation_was_allowed';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;

  RAISE NOTICE 'PASS: expired session, stolen session_id and wrong user_id rejected';
END;
$invalid$;

SELECT set_config(
  'request.jwt.claims',
  '{"session_id":"a0000000-0000-4000-8000-000000000002"}',
  false
);
INSERT INTO public.web_push_subscriptions(user_id,endpoint,p256dh,auth_secret)
VALUES(
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'https://push.synthetic.invalid/a-device-2','key-a2','secret-a2'
);
RESET ROLE;

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
INSERT INTO public.web_push_subscriptions(user_id,endpoint,p256dh,auth_secret)
VALUES(
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
  'https://push.synthetic.invalid/b-device-1','key-b1','secret-b1'
);

DO $cross_tenant$
DECLARE v_updated integer; v_rejected boolean := false;
BEGIN
  UPDATE public.web_push_subscriptions
  SET p256dh='stolen'
  WHERE endpoint='https://push.synthetic.invalid/a-legacy';
  GET DIAGNOSTICS v_updated=ROW_COUNT;
  IF v_updated<>0 THEN
    RAISE EXCEPTION 'B modified A endpoint';
  END IF;

  BEGIN
    INSERT INTO public.web_push_subscriptions(
      user_id,endpoint,p256dh,auth_secret
    ) VALUES (
      'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      'https://push.synthetic.invalid/a-device-2',
      'stolen','stolen'
    )
    ON CONFLICT(endpoint) DO UPDATE
    SET user_id=excluded.user_id, p256dh=excluded.p256dh;
  EXCEPTION WHEN OTHERS THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'B stole live A browser endpoint via global unique conflict';
  END IF;
  RAISE NOTICE 'PASS: user B cannot modify or claim active A endpoint';
END;
$cross_tenant$;
RESET ROLE;

SET ROLE service_role;
SELECT set_config('request.jwt.claim.role','service_role',false);
DO $valid_delivery$
BEGIN
  IF (SELECT count(*) FROM public.get_active_web_push_subscriptions(
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
  ))<>2 THEN
    RAISE EXCEPTION 'both valid A devices must remain deliverable';
  END IF;
  IF (SELECT count(*) FROM public.get_active_web_push_subscriptions(
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'
  ))<>1 THEN
    RAISE EXCEPTION 'independent B device not deliverable';
  END IF;
  RAISE NOTICE 'PASS: both independent A sessions and B session are deliverable only to their owner';
END;
$valid_delivery$;
RESET ROLE;

-- Changing the same A1 Auth session to expired must block only that device.
UPDATE auth.sessions
SET not_after=now()-interval '1 minute'
WHERE id='a0000000-0000-4000-8000-000000000001';

SET ROLE service_role;
SELECT set_config('request.jwt.claim.role','service_role',false);
DO $expired$
BEGIN
  IF (SELECT count(*) FROM public.get_active_web_push_subscriptions(
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
  ))<>1 THEN
    RAISE EXCEPTION 'expired A device remains deliverable or valid A2 disappeared';
  END IF;
  RAISE NOTICE 'PASS: device A1 expired while A2 remains deliverable';
END;
$expired$;
RESET ROLE;

-- Deleting a revoked session is the server-side boundary even if browser
-- A2 is closed and can no longer execute local unsubscribe.
DELETE FROM auth.sessions
WHERE id='a0000000-0000-4000-8000-000000000002';

SET ROLE service_role;
SELECT set_config('request.jwt.claim.role','service_role',false);
DO $revoked$
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.get_active_web_push_subscriptions(
      'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
    )
  ) THEN
    RAISE EXCEPTION 'revoked closed-browser A2 received a financial push';
  END IF;
  IF (SELECT count(*) FROM public.get_active_web_push_subscriptions(
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'
  ))<>1 THEN
    RAISE EXCEPTION 'A session revocation disabled independent B';
  END IF;
  RAISE NOTICE 'PASS: revoked closed A devices blocked; independent B remains enabled';
END;
$revoked$;
RESET ROLE;

-- Revoke B independently and ensure the old endpoint cannot come back.
DELETE FROM auth.sessions
WHERE id='b0000000-0000-4000-8000-000000000001';
SET ROLE service_role;
SELECT set_config('request.jwt.claim.role','service_role',false);
DO $all_revoked$
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.get_active_web_push_subscriptions(
      'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'
    )
  ) THEN
    RAISE EXCEPTION 'revoked B device was still eligible';
  END IF;
  RAISE NOTICE 'PASS: all closed/revoked synthetic device endpoints are now ineligible';
END;
$all_revoked$;
RESET ROLE;
