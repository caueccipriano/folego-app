-- Fôlego Autopilot v1: opt-in, bounded, transactionally safe classification.
-- Does NOT create events, impacts, payments, installments or invoices.
-- Only categories are changed after approval of an exact, account-scoped rule.
CREATE OR REPLACE FUNCTION public.autopilot_apply_approved_categories(p_space_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $fn$
DECLARE
  v_event public.financial_events%rowtype;
  v_account uuid;
  v_cash_count integer;
  v_normalized text;
  v_category uuid;
  v_rule_categories integer;
  v_hist_count integer;
  v_hist_categories integer;
  v_hist_category uuid;
  v_seen integer := 0;
  v_applied integer := 0;
  v_direction text;
  v_kind text;
BEGIN
  IF auth.uid() IS NULL OR NOT private.can_write_space(p_space_id) THEN
    RAISE EXCEPTION 'write_access_denied' USING ERRCODE = '42501';
  END IF;
  -- Lock before examining the category and current review flag, and never
  -- touch a row that another worker is updating.
  FOR v_event IN
    SELECT e.*
    FROM public.financial_events e
    WHERE e.space_id=p_space_id
      AND e.status='confirmed'
      AND e.source='sheet-sync'
      AND e.event_type IN ('income','expense')
      AND lower(coalesce(e.metadata->>'needs_classification','false'))='true'
      AND (
        e.category_id IS NULL OR EXISTS(
          SELECT 1 FROM public.categories c
          WHERE c.id=e.category_id
            AND c.space_id=e.space_id
            AND c.category_role='pending'
        )
      )
    ORDER BY e.occurred_at,e.id
    LIMIT 25 FOR UPDATE OF e SKIP LOCKED
  LOOP
    v_seen := v_seen + 1;
    v_account := NULL;
    SELECT count(*),min(fi.account_id::text)::uuid
    INTO v_cash_count,v_account
    FROM public.financial_impacts fi
    JOIN public.accounts a ON a.id=fi.account_id
      AND a.space_id=p_space_id AND a.active
      AND a.type<>'benefit'
    WHERE fi.event_id=v_event.id AND fi.space_id=p_space_id
      AND fi.dimension='cash';
    IF v_cash_count<>1 OR v_account IS NULL THEN CONTINUE; END IF;
    v_normalized := private.normalize_automation_text(v_event.description);
    IF length(v_normalized)<10 OR v_normalized IN (
      'pix enviada - santander',
      'pix enviado - santander',
      'pix recebida - santander',
      'pix recebido - santander',
      'pix enviado',
      'pix recebida',
      'transferencia',
      'compra cartao',
      'compra no cartao',
      'pagamento pix'
    ) THEN CONTINUE; END IF;
    v_kind := CASE WHEN v_event.event_type='income' THEN 'income' ELSE 'expense' END;
    v_direction := CASE WHEN v_event.event_type='income' THEN 'credit' ELSE 'debit' END;

    -- Rule author explicitly opted in to 'automatic'. Rule must be exact,
    -- specific to the account and compatible with a current economic category.
    SELECT count(DISTINCT ar.category_id),min(ar.category_id::text)::uuid
    INTO v_rule_categories,v_category
    FROM public.automation_rules ar
    JOIN public.categories c ON c.id=ar.category_id
      AND c.space_id=ar.space_id
      AND c.active AND c.is_selectable
      AND c.category_role='economic' AND c.kind=v_kind
    WHERE ar.space_id=p_space_id
      AND ar.active
      AND ar.execution_mode='automatic'
      AND ar.trigger_type='statement_candidate'
      AND ar.action_type='review_category'
      AND ar.match_field='description'
      AND ar.match_type='equals'
      AND ar.source_scope_type='account'
      AND ar.source_account_id=v_account
      AND ar.direction=v_direction
      AND private.normalize_automation_text(ar.match_value)=v_normalized;
    IF v_rule_categories<>1 OR v_category IS NULL THEN CONTINUE; END IF;

    -- Fresh, non-circular proof of >=3 user/previously categorized records
    -- with NO category disagreement. Same account, source, direction and text.
    SELECT count(*),count(DISTINCT h.category_id),min(h.category_id::text)::uuid
    INTO v_hist_count,v_hist_categories,v_hist_category
    FROM public.financial_events h
    JOIN public.categories hc ON hc.id=h.category_id
      AND hc.space_id=p_space_id
      AND hc.category_role='economic'
    WHERE h.space_id=p_space_id
      AND h.status='confirmed'
      AND h.event_type=v_event.event_type
      AND h.source=v_event.source
      AND private.normalize_automation_text(h.description)=v_normalized
      AND lower(coalesce(h.metadata->>'needs_classification','false'))<>'true'
      AND coalesce(h.metadata->>'classified_via','') <> 'autopilot_v1'
      AND EXISTS (
        SELECT 1 FROM public.financial_impacts hi
        WHERE hi.event_id=h.id AND hi.space_id=p_space_id
          AND hi.dimension='cash'
          AND hi.account_id=v_account
      )
      AND (SELECT count(*) FROM public.financial_impacts hx
           WHERE hx.event_id=h.id AND hx.space_id=p_space_id
           AND hx.dimension='cash')=1;
    IF v_hist_count<3 OR v_hist_categories<>1 OR
       v_hist_category IS DISTINCT FROM v_category THEN CONTINUE; END IF;

    UPDATE public.financial_events
    SET category_id=v_category,
        metadata=coalesce(metadata,'{}'::jsonb)
          || jsonb_build_object(
            'needs_classification',false,
            'classified_at',clock_timestamp(),
            'classified_via','autopilot_v1'),
        updated_at=clock_timestamp()
    WHERE id=v_event.id AND space_id=p_space_id
      AND status='confirmed'
      AND category_id IS NOT DISTINCT FROM v_event.category_id
      AND updated_at=v_event.updated_at;
    IF NOT FOUND THEN CONTINUE; END IF;

    UPDATE public.financial_impacts
    SET category_id=v_category
    WHERE event_id=v_event.id AND space_id=p_space_id
      AND dimension IN ('economic','budget');
    v_applied := v_applied+1;
  END LOOP;

  RETURN jsonb_build_object('analyzed',v_seen,'applied',v_applied);
END;
$fn$;
REVOKE ALL ON FUNCTION public.autopilot_apply_approved_categories(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.autopilot_apply_approved_categories(uuid) TO authenticated, service_role;
