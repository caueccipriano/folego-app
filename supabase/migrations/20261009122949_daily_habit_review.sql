CREATE OR REPLACE FUNCTION public.get_daily_summary_push_candidates(p_now timestamp with time zone DEFAULT now(), p_limit integer DEFAULT 100)
 RETURNS TABLE(user_id uuid, space_id uuid, stable_key text, kind text, title text, body text, route text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  pref record;
  snap record;
  wallet jsonb;
  today_local date;
  scheduled_at timestamptz;
  candidate_key text;
  candidate_body text;
  details text;
  category_attention_count integer;
  card_attention_count integer;
  tomorrow_count integer;
  overdue_count integer;
  pending_count integer;
  emitted integer := 0;
begin
  p_limit := least(greatest(coalesce(p_limit, 100), 1), 500);

  for pref in
    select np.*, fs.timezone
    from public.notification_preferences np
    join public.financial_spaces fs on fs.id = np.space_id
    where np.financial_reminders_enabled
      and np.daily_summary_enabled
      and exists (
        select 1 from public.space_members sm
        where sm.space_id = np.space_id and sm.user_id = np.user_id
      )
      and exists (
        select 1 from public.web_push_subscriptions ws
        where ws.user_id = np.user_id and ws.disabled_at is null
      )
    order by np.updated_at, np.space_id
  loop
    perform set_config('request.jwt.claim.sub', pref.user_id::text, true);
    today_local := (p_now at time zone pref.timezone)::date;
    scheduled_at := (today_local::timestamp + pref.daily_summary_time) at time zone pref.timezone;

    if scheduled_at > p_now then continue; end if;
    if private.is_web_push_quiet(
      p_now, pref.timezone, pref.quiet_hours_enabled,
      pref.quiet_hours_start, pref.quiet_hours_end
    ) then continue; end if;

    candidate_key := 'daily_summary:' || pref.space_id::text || ':' || today_local::text;
    if exists (
      select 1 from public.web_push_delivery_log dl
      where dl.user_id = pref.user_id and dl.stable_key = candidate_key
    ) then continue; end if;

    -- Match the app classification inbox across all sources.
    select count(*)::integer into pending_count
    from public.financial_events fe
    where fe.space_id = pref.space_id
      and fe.status = 'confirmed'
      and fe.event_type in (
        'income','benefit_credit','reimbursement','expense','card_purchase',
        'benefit_expense','refund','debt_payment'
      )
      and lower(coalesce(fe.metadata->>'needs_classification', 'false')) = 'true'
      and lower(coalesce(fe.metadata->>'hidden', 'false')) <> 'true';

    select * into snap
    from public.get_folego_snapshot(pref.space_id, today_local)
    limit 1;

    select count(*)::integer into category_attention_count
    from public.get_budget_overview(pref.space_id, date_trunc('month', today_local)::date) b
    where b.planned_amount > 0
      and b.budget_source <> 'aggregate'
      and b.usage_ratio >= b.warning_threshold;

    wallet := public.get_wallet_overview(pref.space_id);
    select count(*)::integer into card_attention_count
    from jsonb_array_elements(coalesce(wallet->'cards', '[]'::jsonb)) as c(value)
    where coalesce(nullif(c.value->>'invoice_balance', '')::numeric, 0) > 0
      and coalesce(
        nullif(c.value->>'personal_limit', '')::numeric,
        nullif(c.value->>'issuer_limit', '')::numeric,
        0
      ) > 0
      and (
        coalesce(nullif(c.value->>'invoice_balance', '')::numeric, 0)
        /
        coalesce(
          nullif(c.value->>'personal_limit', '')::numeric,
          nullif(c.value->>'issuer_limit', '')::numeric,
          1
        )
      ) >= 0.70;

    select count(*)::integer into tomorrow_count
    from public.get_upcoming_events(pref.space_id, today_local + 1, today_local + 1, 200) u
    where u.due_date = today_local + 1;

    select count(*)::integer into overdue_count
    from public.get_upcoming_events(pref.space_id, today_local - 30, today_local, 200) u
    where u.overdue;

    if coalesce(snap.budget_configured, false)
       and coalesce(snap.monthly_budget_used, 0) > coalesce(snap.monthly_budget_planned, 0) then
      candidate_body := 'Você tem '
        || private.format_brl(coalesce(snap.liquid_balance, 0))
        || ' disponíveis • orçamento flexível excedido em '
        || private.format_brl(coalesce(snap.monthly_budget_used, 0) - coalesce(snap.monthly_budget_planned, 0));
    else
      candidate_body := private.format_brl(coalesce(snap.spendable_pool, 0))
        || ' livres • '
        || private.format_brl(coalesce(snap.daily_folego, 0))
        || '/dia';
    end if;

    details := concat_ws(
      ' • ',
      case when category_attention_count > 0 then
        category_attention_count::text || ' ' ||
        case when category_attention_count = 1 then 'categoria em atenção' else 'categorias em atenção' end
      end,
      case when card_attention_count > 0 then
        card_attention_count::text || ' ' ||
        case when card_attention_count = 1 then 'cartão em atenção' else 'cartões em atenção' end
      end,
      case when tomorrow_count > 0 then
        tomorrow_count::text || ' ' ||
        case when tomorrow_count = 1 then 'movimento amanhã' else 'movimentos amanhã' end
      end,
      case when overdue_count > 0 then
        overdue_count::text || ' ' ||
        case when overdue_count = 1 then 'item atrasado' else 'itens atrasados' end
      end
    );

    if coalesce(details, '') <> '' then
      candidate_body := candidate_body || E'\n' || details;
    end if;

    user_id := pref.user_id;
    space_id := pref.space_id;
    stable_key := candidate_key;
    kind := 'dailySummary';
    title := case when pending_count > 0
      then 'Sua revisão do Fôlego está pendente'
      else 'Hora de cuidar do seu Fôlego' end;
    body := case when pending_count > 0
      then pending_count::text || case when pending_count = 1
        then ' lançamento para classificar. Abra e resolva sua revisão de hoje.'
        else ' lançamentos para classificar. Abra e resolva sua revisão de hoje.' end
      else 'Abra, registre os gastos de hoje e confira suas próximas contas.'
        || E'\n' || candidate_body end;
    route := case
      when pending_count > 0 then '/transactions/classification'
      when coalesce(snap.budget_configured, false)
       and coalesce(snap.monthly_budget_used, 0) > coalesce(snap.monthly_budget_planned, 0)
      then '/plan'
      else '/'
    end;
    return next;
    emitted := emitted + 1;
    if emitted >= p_limit then exit; end if;
  end loop;

  perform set_config('request.jwt.claim.sub', '', true);
end;
$function$;

REVOKE ALL ON FUNCTION public.get_daily_summary_push_candidates(timestamptz,integer) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_daily_summary_push_candidates(timestamptz,integer) TO service_role;
