-- Fix SQLSTATE 42725 in Agenda/recurring-payment realization.
-- Before: get_upcoming_events(uuid,date,date) conflicts with the 4-arg
-- version because three trailing arguments on the latter have defaults.
-- Preserve BOTH existing signatures, result formats, grants and OIDs.
-- Canonical Flutter Agenda already supplies all four named arguments.
-- Existing 3-positional-argument consumers keep using the legacy wrapper.
-- Schema-only: no changes to financial_events, balances or other data.
DO $agenda_rpc_fix$
DECLARE
  v_canonical oid := to_regprocedure('public.get_upcoming_events(uuid,date,date,integer)');
  v_legacy oid := to_regprocedure('public.get_upcoming_events(uuid,date,date)');
  v_defaults integer;
  v_sql text;
  v_old_args constant text :=
    'p_start_date date DEFAULT NULL::date, p_end_date date DEFAULT NULL::date, p_limit integer DEFAULT 120';
  v_new_args constant text :=
    'p_start_date date, p_end_date date, p_limit integer';
BEGIN
  IF v_canonical IS NULL OR v_legacy IS NULL THEN
    RAISE EXCEPTION 'agenda_rpc_expected_signatures_missing';
  END IF;

  SELECT pronargdefaults INTO v_defaults
  FROM pg_proc WHERE oid = v_canonical;

  IF v_defaults = 0 THEN
    RAISE NOTICE 'get_upcoming_events canonical overload already disambiguated';
    RETURN;
  END IF;
  IF v_defaults <> 3 THEN
    RAISE EXCEPTION 'agenda_rpc_unexpected_default_count: %', v_defaults;
  END IF;

  SELECT pg_get_functiondef(v_canonical) INTO v_sql;
  IF position(v_old_args IN v_sql) = 0 THEN
    RAISE EXCEPTION 'agenda_rpc_original_signature_changed';
  END IF;
  v_sql := replace(v_sql, v_old_args, v_new_args);

  -- CREATE OR REPLACE keeps the original canonical signature/OID, definer
  -- status, function body, return type, existing grants and references.
  EXECUTE v_sql;

  SELECT pronargdefaults INTO v_defaults
  FROM pg_proc WHERE oid = v_canonical;
  IF v_defaults <> 0 THEN
    RAISE EXCEPTION 'agenda_rpc_postcondition_failed';
  END IF;
END;
$agenda_rpc_fix$;
