-- Archived pre-release SQL review copy; not executed by CI.
-- Applied on Fôlego Dev using Supabase migration version 20261015091421.
-- Canonical recorded file: supabase/migrations/20261015091421_folego_atomic_spending_behavior_cas.sql
-- The function has been verified with a rolled-back, synthetic 5-case suite.
--
-- This function purposefully updates ONE annotation on an existing expense.
-- No tags, necessity_class, frequency_class, value, card, or category changes.
-- Postgres row lock serializes concurrent attempts before CAS comparison.
-- Unlike public.set_event_annotations, there is no read-modify-write of tags.
--
-- SECURITY DEFINER is needed because authenticated cannot UPDATE this column
-- directly; security is enforced by auth.uid() AND private.can_write_space.
CREATE OR REPLACE FUNCTION public.set_event_behavior_class(
  p_space_id uuid,
  p_event_id uuid,
  p_expected_behavior_class text,
  p_behavior_class text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $folego_atomic_behavior$
DECLARE
  v_current text;
BEGIN
  IF auth.uid() IS NULL
    OR p_space_id IS NULL
    OR p_event_id IS NULL
    OR NOT private.can_write_space(p_space_id)
  THEN
    RAISE EXCEPTION 'write_access_denied' USING ERRCODE = '42501';
  END IF;

  IF p_expected_behavior_class IS NOT NULL
    AND p_expected_behavior_class NOT IN ('fixed', 'variable')
  THEN
    RAISE EXCEPTION 'invalid_expected_behavior_class' USING ERRCODE = '22023';
  END IF;
  IF p_behavior_class IS NOT NULL
    AND p_behavior_class NOT IN ('fixed', 'variable')
  THEN
    RAISE EXCEPTION 'invalid_behavior_class' USING ERRCODE = '22023';
  END IF;

  SELECT e.behavior_class
    INTO v_current
    FROM public.financial_events e
    WHERE e.id = p_event_id
      AND e.space_id = p_space_id
      AND e.status = 'confirmed'
      AND e.event_type IN ('expense', 'card_purchase', 'benefit_expense')
    FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'invalid_event' USING ERRCODE = 'P0002';
  END IF;

  IF v_current IS DISTINCT FROM p_expected_behavior_class THEN
    RAISE EXCEPTION 'annotation_conflict' USING ERRCODE = '40001';
  END IF;

  IF v_current IS DISTINCT FROM p_behavior_class THEN
    UPDATE public.financial_events
       SET behavior_class = p_behavior_class,
           updated_at = now()
     WHERE id = p_event_id
       AND space_id = p_space_id;
  END IF;
END;
$folego_atomic_behavior$;

REVOKE ALL ON FUNCTION public.set_event_behavior_class(uuid,uuid,text,text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_event_behavior_class(uuid,uuid,text,text)
  TO authenticated;

-- Explicit post-deployment smoke for the reviewer (read-only):
-- SELECT has_function_privilege('anon',
--   'public.set_event_behavior_class(uuid,uuid,text,text)','EXECUTE');
-- SELECT has_function_privilege('authenticated',
--   'public.set_event_behavior_class(uuid,uuid,text,text)','EXECUTE');
-- SELECT prosecdef, proconfig FROM pg_proc
--   WHERE oid='public.set_event_behavior_class(uuid,uuid,text,text)'::regprocedure;
--
-- The global financial_events AFTER UPDATE statement trigger currently queues
-- a generic push-dispatch check. Validate in staging that this annotation-only
-- edit does not create user-facing push duplicates (separate push fix if it does).
