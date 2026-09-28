-- Prevent a personal account deletion from cascading into financial data
-- shared with another authenticated user. auth.users is the cascade root:
-- public.financial_spaces.owner_id -> auth.users ON DELETE CASCADE and
-- almost all financial tables -> financial_spaces ON DELETE CASCADE.
--
-- The existing Edge Function was deleting automation_rules *before*
-- auth.admin.deleteUser. Move that cleanup to this SAME PostgreSQL DELETE
-- transaction: no partially deleted rules when auth deletion is rejected.
--
-- Keep account deletion for sole owners and for participants who own no
-- shared financial spaces. Shared owners must first resolve memberships,
-- ownership and data-retention consent through the supported account
-- management workflow. Never silently remove other users' financial data.

DO $check_account_delete_schema$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint c
    WHERE c.conrelid = 'public.financial_spaces'::regclass
      AND c.confrelid = 'auth.users'::regclass
      AND c.contype = 'f'
      AND c.confdeltype = 'c'
      AND pg_get_constraintdef(c.oid) LIKE
        'FOREIGN KEY (owner_id) REFERENCES auth.users(id)%'
  ) THEN
    RAISE EXCEPTION 'unexpected_financial_space_owner_delete_schema';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint c
    WHERE c.conrelid = 'public.automation_rules'::regclass
      AND c.confrelid = 'auth.users'::regclass
      AND c.contype = 'f'
      AND c.confdeltype = 'r'
      AND pg_get_constraintdef(c.oid) LIKE
        'FOREIGN KEY (created_by) REFERENCES auth.users(id)%'
  ) THEN
    RAISE EXCEPTION 'unexpected_automation_rule_creator_delete_schema';
  END IF;
END;
$check_account_delete_schema$;

CREATE OR REPLACE FUNCTION private.protect_shared_financial_space_owner_delete()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $protect_delete$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.financial_spaces fs
    JOIN public.space_members sm ON sm.space_id = fs.id
    WHERE fs.owner_id = OLD.id
      AND sm.user_id <> OLD.id
  ) THEN
    RAISE EXCEPTION 'shared_space_owner_deletion_requires_resolution'
      USING ERRCODE = '23514';
  END IF;

  -- automation_rules.created_by currently uses a RESTRICT foreign key.
  -- Cleanup here participates in the SAME transaction as auth.users
  -- deletion. An error in either operation undoes both changes.
  DELETE FROM public.automation_rules ar
  WHERE ar.created_by = OLD.id;

  RETURN OLD;
END;
$protect_delete$;

REVOKE ALL ON FUNCTION
  private.protect_shared_financial_space_owner_delete()
FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS
  protect_shared_financial_space_owner_delete ON auth.users;

CREATE TRIGGER protect_shared_financial_space_owner_delete
BEFORE DELETE ON auth.users
FOR EACH ROW
EXECUTE FUNCTION
  private.protect_shared_financial_space_owner_delete();

COMMENT ON FUNCTION
  private.protect_shared_financial_space_owner_delete()
IS 'Blocks accidental deletion of other members financial data and keeps creator-rule cleanup atomic with auth deletion.';
