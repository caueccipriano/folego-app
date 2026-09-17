-- Notifications + Automation Foundation structural/contract regression tests.
-- No persistent writes: the entire file runs in a rollback transaction.
begin;

do $test$
declare
  v_def text;
  v_norm text;
begin
  if not exists (
    select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relname='notification_preferences' and c.relrowsecurity
  ) then raise exception 'notification_preferences_rls_missing'; end if;

  if not exists (
    select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relname='automation_rules' and c.relrowsecurity
  ) then raise exception 'automation_rules_rls_missing'; end if;

  if not exists (
    select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relname='automation_rule_runs' and c.relrowsecurity
  ) then raise exception 'automation_rule_runs_rls_missing'; end if;

  if has_table_privilege('authenticated','public.automation_rule_runs','INSERT')
     or has_table_privilege('authenticated','public.automation_rule_runs','UPDATE')
     or has_table_privilege('authenticated','public.automation_rule_runs','DELETE') then
    raise exception 'automation_rule_runs_client_write_grant';
  end if;

  if not has_table_privilege('authenticated','public.automation_rule_runs','SELECT') then
    raise exception 'automation_rule_runs_select_missing';
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid='public.notification_preferences'::regclass
      and pg_get_constraintdef(oid) like '%reminder_offset_days%0%1%3%'
  ) then raise exception 'notification_offset_constraint_missing'; end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid='public.automation_rules'::regclass
      and pg_get_constraintdef(oid) like '%source_scope_type%'
  ) then raise exception 'automation_source_scope_constraint_missing'; end if;

  if not exists (
    select 1 from pg_trigger
    where tgrelid='public.automation_rules'::regclass
      and tgname='automation_rules_guard_update'
      and not tgisinternal
  ) then raise exception 'automation_rule_update_guard_missing'; end if;

  select private.normalize_automation_text('  CAFÉ   São   PAULO  ') into v_norm;
  if v_norm <> 'cafe sao paulo' then
    raise exception 'automation_normalization_invalid:%', v_norm;
  end if;

  select pg_get_functiondef('public.apply_automation_rules_to_import_batch(uuid,uuid)'::regprocedure)
    into v_def;
  if position('financial_events' in lower(v_def)) > 0
     or position('financial_impacts' in lower(v_def)) > 0 then
    raise exception 'automation_rpc_touches_ledger';
  end if;
  if position('exact_duplicate' in v_def) = 0
     or position('already_imported' in v_def) = 0 then
    raise exception 'automation_rpc_dedupe_guard_missing';
  end if;
  if position('execution_mode in (''suggest'',''review'')' in replace(v_def,' ','')) = 0
     and position('execution_modein(''suggest'',''review'')' in replace(v_def,' ','')) = 0 then
    raise exception 'automation_rpc_execution_mode_guard_missing';
  end if;

  select pg_get_functiondef('public.get_notification_upcoming_events(uuid,smallint,time without time zone,integer,integer)'::regprocedure)
    into v_def;
  if position('get_upcoming_events' in v_def) = 0 then
    raise exception 'notification_projection_bypasses_agenda';
  end if;
  if position('financial_spaces' in v_def) = 0 or position('timezone' in lower(v_def)) = 0 then
    raise exception 'notification_timezone_contract_missing';
  end if;
  if position('least(greatest(coalesce(p_horizon_days, 30), 1), 30)' in v_def) = 0 then
    raise exception 'notification_horizon_not_bounded';
  end if;
end;
$test$;

rollback;
