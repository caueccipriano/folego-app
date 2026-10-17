-- Open the classification inbox directly when a review push is tapped.

create or replace function public.get_web_push_candidates(
  p_now timestamptz default now(),
  p_limit integer default 100
)
returns table(
  user_id uuid,
  space_id uuid,
  stable_key text,
  kind text,
  title text,
  body text,
  route text
)
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
  month_start date;
  today_local date;
  planned_at timestamptz;
  lead_days integer;
  entity_type text;
  candidate_kind text;
  candidate_key text;
  candidate_title text;
  candidate_body text;
  candidate_route text;
  ratio numeric;
  threshold_pct integer;
  limit_amount numeric;
  invoice_balance numeric;
  classification_count integer;
  classification_latest timestamptz;
  emitted integer := 0;
begin
  p_limit := least(greatest(coalesce(p_limit,100),1),500);

  for pref in
    select np.*, fs.timezone
    from public.notification_preferences np
    join public.financial_spaces fs on fs.id = np.space_id
    where np.financial_reminders_enabled
      and exists (
        select 1
        from public.space_members sm
        where sm.space_id = np.space_id
          and sm.user_id = np.user_id
      )
      and exists (
        select 1
        from public.web_push_subscriptions ws
        where ws.user_id = np.user_id
          and ws.disabled_at is null
      )
  loop
    perform set_config('request.jwt.claim.sub', pref.user_id::text, true);
    today_local := (p_now at time zone pref.timezone)::date;
    month_start := date_trunc('month', today_local)::date;

    -- Notify once for each newly-created batch of sheet transactions that
    -- needs manual classification.
    select
      count(*) filter (
        where coalesce((fe.metadata->>'needs_classification')::boolean, false)
          and not coalesce((fe.metadata->>'hidden')::boolean, false)
      )::integer,
      max(
        case
          when fe.metadata ? 'classification_requested_at'
            then (fe.metadata->>'classification_requested_at')::timestamptz
          else null
        end
      )
    into classification_count, classification_latest
    from public.financial_events fe
    where fe.space_id = pref.space_id
      and fe.status = 'confirmed'
      and fe.source = 'sheet-sync'
      and coalesce((fe.metadata->>'sheet_linked')::boolean, false)
      and fe.event_type in (
        'income','benefit_credit','reimbursement',
        'expense','card_purchase','benefit_expense','refund','debt_payment'
      );

    if classification_count > 0 and classification_latest is not null then
      candidate_key := 'classification:' || classification_latest::text;

      if not exists (
        select 1
        from public.web_push_delivery_log dl
        where dl.user_id = pref.user_id
          and dl.stable_key = candidate_key
      ) then
        user_id := pref.user_id;
        space_id := pref.space_id;
        stable_key := candidate_key;
        kind := 'transactionsNeedReview';
        title := 'tem coisa pra classificar';
        body := case
          when classification_count = 1
            then '1 lançamento esperando sua categoria'
          else classification_count::text || ' lançamentos esperando sua categoria'
        end;
        route := '/transactions/classification';
        return next;
        emitted := emitted + 1;
        if emitted >= p_limit then return; end if;
      end if;
    end if;

    -- Scheduled financial reminders.
    for evt in
      select *
      from public.get_upcoming_events(
        pref.space_id,
        today_local - 30,
        today_local + 30,
        200
      )
    loop
      candidate_kind := null;

      if evt.overdue then
        if pref.overdue_enabled then candidate_kind := 'overdue'; end if;
      elsif evt.source = 'invoice' then
        if pref.invoices_enabled then candidate_kind := 'invoice'; end if;
      elsif evt.source = 'debt' then
        if pref.debts_enabled then candidate_kind := 'debtInstallment'; end if;
      elsif evt.source = 'recurring' then
        if evt.direction = 'income' then
          if pref.expected_income_enabled then candidate_kind := 'recurringIncome'; end if;
        elsif evt.navigation_target = 'subscription' then
          if pref.subscriptions_enabled then candidate_kind := 'subscription'; end if;
        elsif pref.recurrences_enabled then
          candidate_kind := 'recurrence';
        end if;
      else
        candidate_kind := 'commitment';
      end if;

      if candidate_kind is null then continue; end if;

      planned_at := ((evt.due_date - pref.reminder_offset_days)::timestamp + pref.preferred_time)
                    at time zone pref.timezone;

      if not evt.overdue and planned_at > p_now then
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

      if exists (
        select 1 from public.web_push_delivery_log dl
        where dl.user_id = pref.user_id and dl.stable_key = candidate_key
      ) then
        continue;
      end if;

      lead_days := greatest(evt.due_date - today_local, 0);
      candidate_title := evt.title;
      candidate_body := case
        when evt.overdue then evt.title || ' está atrasado'
        when evt.direction = 'income' and lead_days = 0 then evt.title || ' está previsto para hoje'
        when evt.direction = 'income' and lead_days = 1 then evt.title || ' está previsto para amanhã'
        when evt.direction = 'income' then evt.title || ' está previsto em ' || lead_days || ' dias'
        when lead_days = 0 then evt.title || ' vence hoje'
        when lead_days = 1 then evt.title || ' vence amanhã'
        else evt.title || ' vence em ' || lead_days || ' dias'
      end;
      candidate_route := case
        when evt.source = 'invoice' and evt.card_id is not null and evt.invoice_id is not null
          then '/wallet/card/' || evt.card_id::text || '/invoice/' || evt.invoice_id::text
        when evt.source = 'debt' and evt.debt_id is not null
          then '/wallet/debt/' || evt.debt_id::text
        when evt.navigation_target = 'subscription'
          then '/transactions/subscriptions/' || evt.source_id::text
        when evt.source = 'recurring'
          then '/transactions/recurring/' || evt.source_id::text
        else '/agenda'
      end;

      user_id := pref.user_id;
      space_id := pref.space_id;
      stable_key := candidate_key;
      kind := candidate_kind;
      title := candidate_title;
      body := candidate_body;
      route := candidate_route;
      return next;
      emitted := emitted + 1;
      if emitted >= p_limit then return; end if;
    end loop;

    -- Budget/category thresholds using the same canonical overview as Plano.
    if pref.plan_thresholds_enabled then
      for budget_row in
        select *
        from public.get_budget_overview(pref.space_id, month_start)
        where planned_amount > 0
          and budget_source <> 'aggregate'
      loop
        ratio := budget_row.usage_ratio;
        threshold_pct := case
          when ratio >= 1 then 100
          when ratio >= budget_row.critical_threshold then round(budget_row.critical_threshold * 100)::int
          when ratio >= budget_row.warning_threshold then round(budget_row.warning_threshold * 100)::int
          else null
        end;
        if threshold_pct is null then continue; end if;

        candidate_key := 'plan:' || budget_row.category_id::text || ':' ||
                         month_start::text || ':' || threshold_pct::text;
        if exists (
          select 1 from public.web_push_delivery_log dl
          where dl.user_id = pref.user_id and dl.stable_key = candidate_key
        ) then continue; end if;

        candidate_kind := 'planThreshold';
        candidate_title := case
          when threshold_pct >= 100 then 'limite de ' || budget_row.category_name || ' atingido'
          else budget_row.category_name || ' chegou a ' || threshold_pct || '%'
        end;
        candidate_body := case
          when threshold_pct >= 100 then 'Você atingiu o limite planejado desta categoria.'
          else 'Você está se aproximando do limite que definiu no Plano.'
        end;
        candidate_route := '/plan';

        user_id := pref.user_id;
        space_id := pref.space_id;
        stable_key := candidate_key;
        kind := candidate_kind;
        title := candidate_title;
        body := candidate_body;
        route := candidate_route;
        return next;
        emitted := emitted + 1;
        if emitted >= p_limit then return; end if;
      end loop;
    end if;

    -- Card thresholds based on the same current invoice balance shown in Carteira.
    if pref.card_limit_thresholds_enabled then
      wallet := public.get_wallet_overview(pref.space_id);
      for card_row in select value from jsonb_array_elements(coalesce(wallet->'cards','[]'::jsonb))
      loop
        limit_amount := coalesce(
          nullif(card_row->>'personal_limit','')::numeric,
          nullif(card_row->>'issuer_limit','')::numeric
        );
        invoice_balance := coalesce(nullif(card_row->>'invoice_balance','')::numeric,0);
        if limit_amount is null or limit_amount <= 0 then continue; end if;

        ratio := invoice_balance / limit_amount;
        threshold_pct := case
          when ratio >= 1 then 100
          when ratio >= .90 then 90
          when ratio >= .70 then 70
          else null
        end;
        if threshold_pct is null then continue; end if;

        candidate_key := 'card:' || (card_row->>'id') || ':' ||
                         month_start::text || ':' || threshold_pct::text;
        if exists (
          select 1 from public.web_push_delivery_log dl
          where dl.user_id = pref.user_id and dl.stable_key = candidate_key
        ) then continue; end if;

        candidate_kind := 'cardLimitThreshold';
        candidate_title := case
          when threshold_pct >= 100 then 'limite do cartão atingido'
          else 'seu cartão chegou a ' || threshold_pct || '% do limite'
        end;
        candidate_body := coalesce(card_row->>'name','Cartão') ||
          case when threshold_pct >= 100
            then ' atingiu o limite definido.'
            else ' está se aproximando do limite definido.'
          end;
        candidate_route := '/wallet';

        user_id := pref.user_id;
        space_id := pref.space_id;
        stable_key := candidate_key;
        kind := candidate_kind;
        title := candidate_title;
        body := candidate_body;
        route := candidate_route;
        return next;
        emitted := emitted + 1;
        if emitted >= p_limit then return; end if;
      end loop;
    end if;

    -- Optional relevant-spend alert. Only recent events are considered to avoid
    -- flooding a user when they enable push for the first time.
    if pref.large_expenses_enabled and pref.large_expense_threshold > 0 then
      for evt in
        select fe.*
        from public.financial_events fe
        where fe.space_id = pref.space_id
          and fe.status = 'confirmed'
          and fe.event_type in ('expense','card_purchase')
          and fe.amount >= pref.large_expense_threshold
          and fe.created_at >= p_now - interval '15 minutes'
        order by fe.created_at
      loop
        candidate_key := 'large_expense:' || evt.id::text;
        if exists (
          select 1 from public.web_push_delivery_log dl
          where dl.user_id = pref.user_id and dl.stable_key = candidate_key
        ) then continue; end if;

        user_id := pref.user_id;
        space_id := pref.space_id;
        stable_key := candidate_key;
        kind := 'largeExpense';
        title := 'gasto relevante registrado';
        body := 'Um gasto acima do valor que você definiu foi registrado no Fôlego.';
        route := '/transactions';
        return next;
        emitted := emitted + 1;
        if emitted >= p_limit then return; end if;
      end loop;
    end if;
  end loop;

  perform set_config('request.jwt.claim.sub', '', true);
end;
$$;

revoke all on function public.get_web_push_candidates(timestamptz,integer)
  from public, anon, authenticated;
grant execute on function public.get_web_push_candidates(timestamptz,integer)
  to service_role;
