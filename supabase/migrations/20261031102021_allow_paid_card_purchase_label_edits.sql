-- Deployed in Supabase migration 20261031102021_allow_paid_card_purchase_label_edits.
-- This is the canonical repository copy for reproducible deployments.
CREATE OR REPLACE FUNCTION public.update_card_purchase_labels(
  p_space_id uuid, p_event_id uuid, p_description text,
  p_category_id uuid, p_merchant text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_event public.financial_events%rowtype;
  v_purchase public.card_purchases%rowtype;
  v_description text := btrim(p_description);
  v_merchant text := nullif(btrim(p_merchant), '');
BEGIN
  IF (SELECT auth.uid()) IS NULL
     OR NOT private.can_write_space(p_space_id) THEN
    RAISE EXCEPTION 'write_access_denied';
  END IF;
  SELECT * INTO v_event FROM public.financial_events
    WHERE id=p_event_id AND space_id=p_space_id FOR UPDATE;
  SELECT * INTO v_purchase FROM public.card_purchases
    WHERE event_id=p_event_id AND space_id=p_space_id FOR UPDATE;
  IF v_event.id IS NULL OR v_event.event_type <> 'card_purchase'
    OR v_event.status <> 'confirmed' OR v_purchase.id IS NULL
    OR v_purchase.status <> 'confirmed' THEN
    RAISE EXCEPTION 'card_purchase_not_editable';
  END IF;
  IF coalesce((v_event.metadata->>'legacy_exception')::boolean,false) THEN
    RAISE EXCEPTION 'legacy_event_read_only';
  END IF;
  IF v_description IS NULL OR length(v_description) NOT BETWEEN 1 AND 240
    OR length(coalesce(v_merchant,'')) > 160 THEN
    RAISE EXCEPTION 'invalid_purchase_labels';
  END IF;
  IF p_category_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.categories c
    WHERE c.id=p_category_id AND c.space_id=p_space_id
      AND c.kind='expense' AND c.category_role='economic'
      AND c.active AND c.is_selectable
  ) THEN
    RAISE EXCEPTION 'invalid_category';
  END IF;
  UPDATE public.card_purchases SET
    description=v_description, merchant=v_merchant,
    category_id=p_category_id, updated_at=now()
  WHERE id=v_purchase.id AND space_id=p_space_id;
  UPDATE public.financial_events SET
    description=v_description,category_id=p_category_id,
    metadata=CASE
      WHEN p_category_id IS DISTINCT FROM v_event.category_id THEN
        coalesce(metadata,'{}'::jsonb) ||
        jsonb_build_object('needs_classification',p_category_id IS NULL,
          'classified_via','app',
          'classified_at',CASE WHEN p_category_id IS NOT NULL THEN now() ELSE NULL END)
      ELSE metadata END,
    updated_at=now()
  WHERE id=p_event_id AND space_id=p_space_id;
  IF p_category_id IS DISTINCT FROM v_event.category_id THEN
    UPDATE public.financial_impacts SET category_id=p_category_id
    WHERE event_id=p_event_id AND space_id=p_space_id
      AND dimension IN ('economic','budget');
  END IF;
  RETURN p_event_id;
END;
$function$;
REVOKE ALL ON FUNCTION public.update_card_purchase_labels(
  uuid,uuid,text,uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_card_purchase_labels(
  uuid,uuid,text,uuid,text) TO authenticated;
