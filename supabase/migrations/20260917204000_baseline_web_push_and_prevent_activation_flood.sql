create or replace function private.baseline_web_push_state(
  p_user_id uuid,
  p_space_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  pref record;
  evt record;
  budget_row record;
  card_row jsonb;
  wallet jsonb;
  today_local date;
  month_start date;
  planned_at timestamptz;
  entity_type text;
  candidate_kind text;
  candidate_key text;
  ratio numeric;
  limit_amount numeric;
  invoice_balance numeric;
  warn_pct integer;
  crit_pct integer;
begin
  for pref in
    select np.*, fs.timezone
    from public.notification_preferences np
    join public.financial_spaces fs on fs.id = np.space_id
    where np.user_id = p_user_id
      and (p_space_id is null or np.space_id = p_space_id)
  loop
    perform set_config('request.jwt.claim.sub', pref.user_id::text, true);
    today_local := (now() at time zone pref.timezone)::date;
    month_start := date_trunc('month', today_local)::date;

    for evt in
      select *
      from public.get_upcoming_events(
        pref.space_id,
        today_local - 30,
        today_local + 30,
        500
      )
    loop
      candidate_kind := case
        when evt.overdue then 'overdue'
        when evt.source = 'invoice' then 'invoice'
        when evt.source = 'debt' then 'debtInstallment'
        when evt.source = 'recurring' and evt.direction = 'income' then 'recurringIncome'
        when evt.navigation_target = 'subscription' then 'subscription'
        when evt.source = 'recurring' then 'recurrence'
        else 'commitment'
      end;

      planned_at := ((evt.due_date - pref.reminder_offset_days)::timestamp + pref.preferred_time)
                    at time zone pref.timezone;

      if not evt.overdue and planned_at > now() then
        continue;
      end if;

      entity_type := case
        when evt.source = 'invoice' then 'invoice'
        when evt.source = 'debt' then 'debt_installment'
        when evt.navigation_target = 'subscription' then 'subscription'
        when evt.source = 'recurring' then 'recurring'
        else evt.source
      end;

      candidate_key := entity_type || ':' || evt.source_id::text || ':' ||
                       evt.due_date::text || ':' || pref.reminder_offset_days::text ||
                       ':' || candidate_kind;

      insert into public.web_push_delivery_log(user_id, space_id, stable_key, kind)
      values (pref.user_id, pref.space_id, candidate_key, candidate_kind)
      on conflict (user_id, stable_key) do nothing;
    end loop;

    for budget_row in
      select *
      from public.get_budget_overview(pref.space_id, month_start)
      where planned_amount > 0
        and budget_source <> 'aggregate'
    loop
      ratio := budget_row.usage_ratio;
      warn_pct := round(budget_row.warning_threshold * 100)::int;
      crit_pct := round(budget_row.critical_threshold * 100)::int;

      if ratio >= budget_row.warning_threshold then
        candidate_key := 'plan:' || budget_row.category_id::text || ':' || month_start::text || ':' || warn_pct::text;
        insert into public.web_push_delivery_log(user_id, space_id, stable_key, kind)
        values (pref.user_id, pref.space_id, candidate_key, 'planThreshold')
        on conflict (user_id, stable_key) do nothing;
      end if;

      if ratio >= budget_row.critical_threshold then
        candidate_key := 'plan:' || budget_row.category_id::text || ':' || month_start::text || ':' || crit_pct::text;
        insert into public.web_push_delivery_log(user_id, space_id, stable_key, kind)
        values (pref.user_id, pref.space_id, candidate_key, 'planThreshold')
        on conflict (user_id, stable_key) do nothing;
      end if;

      if ratio >= 1 then
        candidate_key := 'plan:' || budget_row.category_id::text || ':' || month_start::text || ':100';
        insert into public.web_push_delivery_log(user_id, space_id, stable_key, kind)
        values (pref.user_id, pref.space_id, candidate_key, 'planThreshold')
        on conflict (user_id, stable_key) do nothing;
      end if;
    end loop;

    wallet := public.get_wallet_overview(pref.space_id);
    for card_row in
      select value
      from jsonb_array_elements(coalesce(wallet->'cards', '[]'::jsonb))
    loop
      limit_amount := coalesce(
        nullif(card_row->>'personal_limit', '')::numeric,
        nullif(card_row->>'issuer_limit', '')::numeric
      );
      invoice_balance := coalesce(nullif(card_row->>'invoice_balance', '')::numeric, 0);
      if limit_amount is null or limit_amount <= 0 then
        continue;
      end if;

      ratio := invoice_balance / limit_amount;

      if ratio >= .70 then
        candidate_key := 'card:' || (card_row->>'id') || ':' || month_start::text || ':70';
        insert into public.web_push_delivery_log(user_id, space_id, stable_key, kind)
        values (pref.user_id, pref.space_id, candidate_key, 'cardLimitThreshold')
        on conflict (user_id, stable_key) do nothing;
      end if;

      if ratio >= .90 then
        candidate_key := 'card:' || (card_row->>'id') || ':' || month_start::text || ':90';
        insert into public.web_push_delivery_log(user_id, space_id, stable_key, kind)
        values (pref.user_id, pref.space_id, candidate_key, 'cardLimitThreshold')
        on conflict (user_id, stable_key) do nothing;
      end if;

      if ratio >= 1 then
        candidate_key := 'card:' || (card_row->>'id') || ':' || month_start::text || ':100';
        insert into public.web_push_delivery_log(user_id, space_id, stable_key, kind)
        values (pref.user_id, pref.space_id, candidate_key, 'cardLimitThreshold')
        on conflict (user_id, stable_key) do nothing;
      end if;
    end loop;

    for evt in
      select fe.id
      from public.financial_events fe
      where fe.space_id = pref.space_id
        and fe.status = 'confirmed'
        and fe.event_type in ('expense', 'card_purchase')
        and fe.amount >= pref.large_expense_threshold
        and fe.created_at >= now() - interval '15 minutes'
    loop
      candidate_key := 'large_expense:' || evt.id::text;
      insert into public.web_push_delivery_log(user_id, space_id, stable_key, kind)
      values (pref.user_id, pref.space_id, candidate_key, 'largeExpense')
      on conflict (user_id, stable_key) do nothing;
    end loop;
  end loop;

  perform set_config('request.jwt.claim.sub', '', true);
end;
$$;

revoke all on function private.baseline_web_push_state(uuid, uuid) from public, anon, authenticated;

create or replace function private.baseline_web_push_on_subscription()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.baseline_web_push_state(new.user_id, null);
  return new;
end;
$$;

revoke all on function private.baseline_web_push_on_subscription() from public, anon, authenticated;

drop trigger if exists web_push_subscription_baseline on public.web_push_subscriptions;
create trigger web_push_subscription_baseline
after insert on public.web_push_subscriptions
for each row execute function private.baseline_web_push_on_subscription();

create or replace function private.baseline_web_push_on_reminders_reenabled()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.financial_reminders_enabled and not old.financial_reminders_enabled then
    perform private.baseline_web_push_state(new.user_id, new.space_id);
  end if;
  return new;
end;
$$;

revoke all on function private.baseline_web_push_on_reminders_reenabled() from public, anon, authenticated;

drop trigger if exists notification_preferences_reenable_baseline on public.notification_preferences;
create trigger notification_preferences_reenable_baseline
after update of financial_reminders_enabled on public.notification_preferences
for each row
when (new.financial_reminders_enabled = true and old.financial_reminders_enabled = false)
execute function private.baseline_web_push_on_reminders_reenabled();

create or replace function private.queue_folego_web_push_dispatch()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.invoke_folego_web_push_dispatch();
  return null;
end;
$$;

revoke all on function private.queue_folego_web_push_dispatch() from public, anon, authenticated;

drop trigger if exists financial_events_queue_web_push on public.financial_events;
create trigger financial_events_queue_web_push
after insert or update on public.financial_events
for each statement execute function private.queue_folego_web_push_dispatch();

do $$
declare
  r record;
begin
  for r in
    select distinct user_id
    from public.web_push_subscriptions
    where disabled_at is null
  loop
    perform private.baseline_web_push_state(r.user_id, null);
  end loop;
end $$;

do $$
declare
  existing_job bigint;
begin
  for existing_job in
    select jobid from cron.job where jobname = 'folego-web-push-dispatch'
  loop
    perform cron.unschedule(existing_job);
  end loop;

  perform cron.schedule(
    'folego-web-push-dispatch',
    '*/5 * * * *',
    'select private.invoke_folego_web_push_dispatch();'
  );
end $$;