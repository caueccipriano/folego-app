-- Fix SQLSTATE 42725 from overlapping public.get_upcoming_events signatures.
--
-- Keep both 3-argument legacy and 4-argument Agenda RPCs intact: dropping
-- either would risk API compatibility and dependent financial functions.
-- Instead disambiguate the ONLY two stored routines that use 3 positional
-- arguments. Named p_from/p_until uniquely resolve the legacy 3-arg function.
-- No financial rows or balances are modified. Function OIDs, return types,
-- grants, security modes and existing authorization checks are preserved.
DO $agenda_rpc_fix$
DECLARE
  v_realize oid := to_regprocedure('private.realize_recurring(uuid,uuid,date,numeric)');
  v_overview oid := to_regprocedure('public.get_app_overview(uuid,date)');
  v_definition text;
  v_old text;
  v_new text;
BEGIN
  IF v_realize IS NULL OR v_overview IS NULL THEN
    RAISE EXCEPTION 'agenda_42725_expected_consumers_missing';
  END IF;

  v_old := 'public.get_upcoming_events(p_space_id, p_due_date, p_due_date)';
  v_new := 'public.get_upcoming_events(p_space_id => p_space_id, p_from => p_due_date, p_until => p_due_date)';
  SELECT pg_get_functiondef(v_realize) INTO v_definition;
  IF position(v_new IN v_definition) = 0 THEN
    IF position(v_old IN v_definition) = 0 THEN
      RAISE EXCEPTION 'agenda_42725_realize_recurring_definition_changed';
    END IF;
    EXECUTE replace(v_definition, v_old, v_new);
  END IF;

  v_old := 'public.get_upcoming_events(p_space_id,least(today,month_start),greatest(today+60,next_month-1))';
  v_new := 'public.get_upcoming_events(p_space_id => p_space_id, p_from => least(today,month_start), p_until => greatest(today+60,next_month-1))';
  SELECT pg_get_functiondef(v_overview) INTO v_definition;
  IF position(v_new IN v_definition) = 0 THEN
    IF position(v_old IN v_definition) = 0 THEN
      RAISE EXCEPTION 'agenda_42725_get_app_overview_definition_changed';
    END IF;
    EXECUTE replace(v_definition, v_old, v_new);
  END IF;

  -- Fail atomically if the original ambiguous calls survive.
  SELECT pg_get_functiondef(v_realize) INTO v_definition;
  IF position('public.get_upcoming_events(p_space_id, p_due_date, p_due_date)' IN v_definition) > 0 THEN
    RAISE EXCEPTION 'agenda_42725_postcondition_realize_failed';
  END IF;
  SELECT pg_get_functiondef(v_overview) INTO v_definition;
  IF position('public.get_upcoming_events(p_space_id,least(today,month_start),greatest(today+60,next_month-1))' IN v_definition) > 0 THEN
    RAISE EXCEPTION 'agenda_42725_postcondition_overview_failed';
  END IF;
END;
$agenda_rpc_fix$;
