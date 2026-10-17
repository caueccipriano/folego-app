-- Applied on Fôlego Dev at migration version 20261015091421.
-- Add-only guarded RPC; does not reclassify existing events.
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
