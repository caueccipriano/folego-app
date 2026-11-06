-- Apply only to the existing notification candidate function.
-- No financial transactions, category assignments, budgets or debt balances
-- are changed. Safe to re-run; fails rather than silently modifying an
-- unexpected function version.
do $patch$
declare
  old_def text;
  next_def text;
  marker constant text := '    -- Scheduled financial reminders.';
begin
  select pg_get_functiondef(
    'public.get_web_push_candidates(timestamp with time zone,integer)'::regprocedure
  ) into old_def;

  if position('Actionable, deduplicated push for newly inserted economic transactions' in old_def) > 0 then
    return;
  end if;
  if position(marker in old_def) = 0 then
    raise exception 'Unexpected get_web_push_candidates layout, aborting patch';
  end if;

  next_def := replace(
    old_def,
    marker,
    $insert$    -- Actionable, deduplicated push for newly inserted economic transactions
    -- which still require a category. Non-economic card settlements and
    -- transfers never enter this queue.
    if pref.transaction_activity_enabled then
      for evt in
        select fe.id, fe.amount, fe.description
        from public.financial_events fe
        left join public.categories cc
          on cc.id = fe.category_id and cc.space_id = fe.space_id
        where fe.space_id = pref.space_id
          and fe.status = 'confirmed'
          and fe.event_type in (
            'income', 'benefit_credit', 'reimbursement',
            'expense', 'card_purchase', 'benefit_expense',
            'refund', 'debt_payment'
          )
          and fe.created_at between p_now - interval '72 hours'
                                and p_now + interval '5 minutes'
          and lower(coalesce(fe.metadata->>'hidden', 'false')) <> 'true'
          and (
            fe.category_id is null
            or cc.name = 'A classificar'
            or lower(coalesce(fe.metadata->>'needs_classification', 'false')) = 'true'
          )
        order by fe.created_at desc
        limit 10
      loop
        -- Share the activity-center stable key with the row trigger. This
        -- prevents a duplicate in-app alert and permits category updates to
        -- change the existing alert from review-needed to normal.
        candidate_key := 'newTx:' || evt.id::text;
        if not exists (
          select 1 from public.web_push_delivery_log dl
          where dl.user_id = pref.user_id
            and dl.stable_key = candidate_key
        ) then
          user_id := pref.user_id;
          space_id := pref.space_id;
          stable_key := candidate_key;
          kind := 'transactionNeedsReview';
          title := 'Classificar lançamento';
          body := private.format_brl(evt.amount) || ' · ' ||
                  left(coalesce(evt.description, 'Novo lançamento'), 100);
          route := '/transactions/' || evt.id::text;
          return next;
          emitted := emitted + 1;
          if emitted >= p_limit then return; end if;
        end if;
      end loop;
    end if;

$insert$ || marker
  );
  execute next_def;
end
$patch$;
