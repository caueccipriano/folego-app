-- Confirm the old schema cannot bind an endpoint to an Auth session.
-- Test only synthetic records in disposable CI database.
\set ON_ERROR_STOP on
DO $old_behavior$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public'
      AND table_name='web_push_subscriptions'
      AND column_name='session_id'
  ) THEN
    RAISE EXCEPTION 'fixture is not an unpatched push schema';
  END IF;
  IF (SELECT count(*) FROM public.web_push_subscriptions ws
      WHERE ws.user_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
        AND ws.disabled_at IS NULL)<>1
  THEN
    RAISE EXCEPTION 'expected legacy unverified delivery candidate';
  END IF;
  RAISE NOTICE 'PASS: original delivery could select legacy A endpoint without any device session';
END;
$old_behavior$;
