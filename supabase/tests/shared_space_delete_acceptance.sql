-- Exercises the real migration (not a mock) against fake auth users.
-- All deletion operations occur ONLY in disposable CI PostgreSQL 17.
\set ON_ERROR_STOP on

DO $assert_trigger$
DECLARE
  v_priv boolean;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_trigger t
    WHERE t.tgrelid='auth.users'::regclass
      AND t.tgname='protect_shared_financial_space_owner_delete'
      AND NOT t.tgisinternal
  ) THEN
    RAISE EXCEPTION 'shared-owner delete trigger not installed';
  END IF;
  v_priv := has_function_privilege(
    'authenticated',
    'private.protect_shared_financial_space_owner_delete()',
    'EXECUTE'
  );
  IF v_priv OR has_function_privilege(
    'anon',
    'private.protect_shared_financial_space_owner_delete()',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'account delete guard exposed to client roles';
  END IF;
  RAISE NOTICE 'PASS: guard installed on auth.users and cannot be called by clients';
END;
$assert_trigger$;

DO $shared_owner_denial$
DECLARE
  v_caught boolean := false;
  v_message text;
BEGIN
  BEGIN
    DELETE FROM auth.users
    WHERE id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
  EXCEPTION WHEN check_violation THEN
    GET STACKED DIAGNOSTICS v_message=MESSAGE_TEXT;
    IF v_message IS DISTINCT FROM
      'shared_space_owner_deletion_requires_resolution'
    THEN
      RAISE EXCEPTION 'unexpected shared delete rejection: %',v_message;
    END IF;
    v_caught := true;
  END;
  IF NOT v_caught THEN
    RAISE EXCEPTION 'shared owner was deleted despite another member';
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users
      WHERE id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb')
    OR NOT EXISTS(SELECT 1 FROM auth.users
      WHERE id='cccccccc-cccc-4ccc-8ccc-cccccccccccc')
    OR NOT EXISTS(SELECT 1 FROM public.financial_spaces
      WHERE id='22222222-2222-4222-8222-222222222222')
    OR (SELECT count(*) FROM public.space_members
      WHERE space_id='22222222-2222-4222-8222-222222222222')<>2
    OR (SELECT count(*) FROM public.automation_rules
      WHERE space_id='22222222-2222-4222-8222-222222222222')<>2
  THEN
    RAISE EXCEPTION 'denied shared deletion unexpectedly mutated data';
  END IF;
  RAISE NOTICE 'PASS: shared owner denied; both users, space, memberships and authored automations preserved';
END;
$shared_owner_denial$;

-- An unrelated error that fires AFTER the safety trigger must not leave
-- any automation rule partially cleaned up.
CREATE FUNCTION private.force_account_delete_failure()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'fixture_auth_deletion_failure';
END;
$$;
CREATE TRIGGER zz_force_account_delete_failure
BEFORE DELETE ON auth.users
FOR EACH ROW
WHEN (
  OLD.id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'::uuid
)
EXECUTE FUNCTION private.force_account_delete_failure();

DO $atomic_failure$
DECLARE
  v_blocked boolean := false;
BEGIN
  BEGIN
    DELETE FROM auth.users
    WHERE id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM IS DISTINCT FROM 'fixture_auth_deletion_failure' THEN
      RAISE;
    END IF;
    v_blocked := true;
  END;
  IF NOT v_blocked
    OR NOT EXISTS(SELECT 1 FROM auth.users
        WHERE id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')
    OR NOT EXISTS(SELECT 1 FROM public.automation_rules
        WHERE id='10000000-0000-4000-8000-000000000001')
  THEN
    RAISE EXCEPTION 'failed user deletion partially removed authored rules';
  END IF;
  RAISE NOTICE 'PASS: failed auth deletion rolls back authored-rule cleanup in the same transaction';
END;
$atomic_failure$;

DROP TRIGGER zz_force_account_delete_failure ON auth.users;
DROP FUNCTION private.force_account_delete_failure();

DO $sole_owner$
BEGIN
  DELETE FROM auth.users
  WHERE id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  IF EXISTS(SELECT 1 FROM auth.users
        WHERE id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')
    OR EXISTS(SELECT 1 FROM public.financial_spaces
        WHERE id='11111111-1111-4111-8111-111111111111')
    OR EXISTS(SELECT 1 FROM public.automation_rules
        WHERE id='10000000-0000-4000-8000-000000000001')
  THEN
    RAISE EXCEPTION 'sole owner legitimate deletion was prevented';
  END IF;
  IF NOT EXISTS(SELECT 1 FROM public.financial_spaces
      WHERE id='55555555-5555-4555-8555-555555555555') THEN
    RAISE EXCEPTION 'unrelated user space disappeared';
  END IF;
  RAISE NOTICE 'PASS: sole owner deletes own space/rules without affecting unrelated E';
END;
$sole_owner$;

DO $member_exit$
BEGIN
  DELETE FROM auth.users
  WHERE id='cccccccc-cccc-4ccc-8ccc-cccccccccccc';
  IF EXISTS(SELECT 1 FROM auth.users
      WHERE id='cccccccc-cccc-4ccc-8ccc-cccccccccccc')
    OR EXISTS(SELECT 1 FROM public.automation_rules
      WHERE id='10000000-0000-4000-8000-000000000003')
    OR NOT EXISTS(SELECT 1 FROM public.financial_spaces
      WHERE id='22222222-2222-4222-8222-222222222222')
    OR NOT EXISTS(SELECT 1 FROM public.automation_rules
      WHERE id='10000000-0000-4000-8000-000000000002')
  THEN
    RAISE EXCEPTION 'member exit damaged another owner''s shared space';
  END IF;
  RAISE NOTICE 'PASS: member can delete own account; shared owner keeps space and own rules';
END;
$member_exit$;

DO $after_resolution$
BEGIN
  -- The member has voluntarily left, so B no longer has anyone sharing
  -- the financial space. B must retain the right to close the account.
  DELETE FROM auth.users
  WHERE id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
  IF EXISTS(SELECT 1 FROM public.financial_spaces
      WHERE id='22222222-2222-4222-8222-222222222222')
    OR EXISTS(SELECT 1 FROM auth.users
      WHERE id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb')
  THEN
    RAISE EXCEPTION 'formerly shared owner could not delete after resolution';
  END IF;
  RAISE NOTICE 'PASS: owner deletion works once shared membership has been resolved';
END;
$after_resolution$;

DO $household_sole_owner$
BEGIN
  DELETE FROM auth.users
  WHERE id='dddddddd-dddd-4ddd-8ddd-dddddddddddd';
  IF EXISTS(SELECT 1 FROM public.financial_spaces
    WHERE id='33333333-3333-4333-8333-333333333333') THEN
    RAISE EXCEPTION 'empty household owner was incorrectly prevented from deleting';
  END IF;
  IF (SELECT count(*) FROM auth.users)<>1 THEN
    RAISE EXCEPTION 'unrelated E user was lost';
  END IF;
  RAISE NOTICE 'PASS: unshared household owner may delete; unrelated account and space remain';
END;
$household_sole_owner$;
