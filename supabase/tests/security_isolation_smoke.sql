-- Security isolation smoke tests.
-- Structural checks only; no persistent writes.
begin;

do $test$
declare
  v_bad text;
begin
  select string_agg(format('%I.%I', n.nspname, c.relname), ', ' order by c.relname)
    into v_bad
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relkind in ('r', 'p')
    and not c.relrowsecurity;

  if v_bad is not null then
    raise exception 'public_tables_without_rls:%', v_bad;
  end if;

  select string_agg(format('%I(%s)', p.proname, pg_get_function_identity_arguments(p.oid)), ', ' order by p.proname)
    into v_bad
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.prosecdef
    and has_function_privilege('anon', p.oid, 'EXECUTE');

  if v_bad is not null then
    raise exception 'anon_can_execute_security_definer:%', v_bad;
  end if;

  select string_agg(format('%I(%s)', p.proname, pg_get_function_identity_arguments(p.oid)), ', ' order by p.proname)
    into v_bad
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.prosecdef
    and coalesce(array_to_string(p.proconfig, ','), '') not like '%search_path=%';

  if v_bad is not null then
    raise exception 'security_definer_without_fixed_search_path:%', v_bad;
  end if;

  select string_agg(format('%I(%s)', p.proname, pg_get_function_identity_arguments(p.oid)), ', ' order by p.proname)
    into v_bad
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.prosecdef
    and has_function_privilege('authenticated', p.oid, 'EXECUTE')
    and p.proname not in (
      'apply_automation_rules_to_import_batch',
      'cancel_benefit_expense',
      'cancel_card_purchase',
      'cancel_transfer_transaction',
      'get_category_catalog',
      'register_benefit_at',
      'reverse_card_payment',
      'update_benefit_expense',
      'update_card_purchase',
      'update_transfer_transaction'
    );

  if v_bad is not null then
    raise exception 'unexpected_authenticated_security_definer_rpc:%', v_bad;
  end if;

  select string_agg(format('%I(%s)', p.proname, pg_get_function_identity_arguments(p.oid)), ', ' order by p.proname)
    into v_bad
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.prosecdef
    and has_function_privilege('authenticated', p.oid, 'EXECUTE')
    and (
      position('auth.uid()' in lower(pg_get_functiondef(p.oid))) = 0
      or (
        position('private.can_write_space' in lower(pg_get_functiondef(p.oid))) = 0
        and position('private.is_space_member' in lower(pg_get_functiondef(p.oid))) = 0
      )
    );

  if v_bad is not null then
    raise exception 'client_security_definer_missing_access_guard:%', v_bad;
  end if;

  select string_agg(format('%I(%s)', p.proname, pg_get_function_identity_arguments(p.oid)), ', ' order by p.proname)
    into v_bad
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname in (
      'get_daily_summary_push_candidates',
      'get_web_push_candidates',
      'get_web_push_server_config',
      'mark_web_push_delivered',
      'verify_web_push_cron_token',
      'web_push_should_deliver'
    )
    and (
      has_function_privilege('anon', p.oid, 'EXECUTE')
      or has_function_privilege('authenticated', p.oid, 'EXECUTE')
    );

  if v_bad is not null then
    raise exception 'push_server_rpc_exposed_to_client:%', v_bad;
  end if;
end;
$test$;

rollback;
