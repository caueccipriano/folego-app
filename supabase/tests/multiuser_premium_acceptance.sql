-- Only three explicit entitlement columns are visible to the owning user.
\set ON_ERROR_STOP on
DO $privileges$
BEGIN
  IF NOT (
    has_column_privilege('authenticated','public.premium_grants','user_id','SELECT')
    AND has_column_privilege('authenticated','public.premium_grants','grant_type','SELECT')
    AND has_column_privilege('authenticated','public.premium_grants','valid_until','SELECT')
  ) OR has_column_privilege(
    'authenticated','public.premium_grants','note','SELECT'
  ) OR has_table_privilege(
    'authenticated','public.premium_grants','INSERT'
  ) OR has_table_privilege(
    'authenticated','public.premium_grants','UPDATE'
  ) OR has_column_privilege(
    'anon','public.premium_grants','user_id','SELECT'
  ) THEN
    RAISE EXCEPTION 'Premium grants violate least-privilege columns';
  END IF;
  RAISE NOTICE 'PASS: only entitlement columns can be read, no write or admin notes';
END;
$privileges$;

SET ROLE authenticated;
SELECT set_config(
  'request.jwt.claim.sub','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false
);
DO $owner$
DECLARE v_count integer; v_type text;
BEGIN
  SELECT count(*) INTO v_count FROM public.premium_grants;
  IF v_count <> 1 THEN RAISE EXCEPTION 'A saw another user''s grant'; END IF;
  SELECT grant_type INTO v_type FROM public.get_my_premium_grant();
  IF v_type IS DISTINCT FROM 'complimentary' THEN
    RAISE EXCEPTION 'complimentary owner still appears Free';
  END IF;
  RAISE NOTICE 'PASS: A reads own complimentary entitlement only';
END;
$owner$;
RESET ROLE;

SET ROLE authenticated;
SELECT set_config(
  'request.jwt.claim.sub','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',false
);
DO $free$
DECLARE v_count integer;
BEGIN
  SELECT count(*) INTO v_count FROM public.premium_grants;
  IF v_count <> 0 OR EXISTS(SELECT 1 FROM public.get_my_premium_grant()) THEN
    RAISE EXCEPTION 'B accessed another user''s Premium';
  END IF;
  RAISE NOTICE 'PASS: B remains Free and sees no third-party grants';
END;
$free$;
RESET ROLE;

SET ROLE authenticated;
SELECT set_config(
  'request.jwt.claim.sub','cccccccc-cccc-4ccc-8ccc-cccccccccccc',false
);
DO $lifetime$
DECLARE v_type text;
BEGIN
  SELECT grant_type INTO v_type FROM public.get_my_premium_grant();
  IF v_type IS DISTINCT FROM 'lifetime' THEN
    RAISE EXCEPTION 'lifetime owner still appears Free';
  END IF;
  RAISE NOTICE 'PASS: C reads own lifetime entitlement';
END;
$lifetime$;
RESET ROLE;
