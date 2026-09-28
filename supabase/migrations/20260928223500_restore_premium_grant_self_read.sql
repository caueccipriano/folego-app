-- All-user Premium consistency: get_my_premium_grant() is SECURITY INVOKER
-- and reads premium_grants, but authenticated had zero SELECT privileges.
-- Therefore complimentary/lifetime users could be classified as Free in
-- Flutter even though backend security-definer quota routines accepted them.
--
-- Grant ONLY the three existing public-facing entitlement columns. Keep the
-- private admin note and timestamps unreadable and all writes server-only.
-- RLS "premium_grants_select_own" must continue enforcing auth.uid().
DO $preconditions$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies p
    WHERE p.schemaname='public'
      AND p.tablename='premium_grants'
      AND p.policyname='premium_grants_select_own'
      AND p.cmd='SELECT'
      AND p.qual LIKE '%auth.uid()%'
  ) THEN
    RAISE EXCEPTION 'premium_self_read_policy_missing_or_changed';
  END IF;

  IF NOT (
    SELECT c.relrowsecurity FROM pg_class c
    WHERE c.oid='public.premium_grants'::regclass
  ) THEN
    RAISE EXCEPTION 'premium_grants_rls_must_be_enabled';
  END IF;
END;
$preconditions$;

GRANT SELECT (user_id,grant_type,valid_until)
ON TABLE public.premium_grants TO authenticated;

DO $postconditions$
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
  ) OR has_table_privilege(
    'authenticated','public.premium_grants','DELETE'
  ) OR has_column_privilege(
    'anon','public.premium_grants','user_id','SELECT'
  ) THEN
    RAISE EXCEPTION 'premium_grants_column_grants_incorrect';
  END IF;
END;
$postconditions$;
