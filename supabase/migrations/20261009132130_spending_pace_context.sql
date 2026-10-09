create or replace function public.get_spending_pace(p_space_id uuid, p_as_of_date date default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare today date; snap record; total numeric; active_days integer; uncertain integer; average numeric; risk numeric; state text;
begin
 if auth.uid() is null or not exists(select 1 from public.space_members where space_id=p_space_id and user_id=auth.uid()) then raise exception 'not_authorized'; end if;
 select coalesce(p_as_of_date,(now() at time zone timezone)::date) into today from public.financial_spaces where id=p_space_id;
 select * into snap from public.get_folego_snapshot(p_space_id,today);
 select count(*) into uncertain from public.financial_events fe where fe.space_id=p_space_id and fe.status='confirmed'
 and fe.event_type in ('expense','card_purchase','refund') and (fe.occurred_at at time zone (select timezone from public.financial_spaces where id=p_space_id))::date between today-7 and today
 and lower(coalesce(fe.metadata->>'needs_classification','false'))='true' and lower(coalesce(fe.metadata->>'hidden','false'))<>'true';
 select greatest(-coalesce(sum(fi.amount),0),0), count(distinct fi.effective_date) filter(where fi.amount<0) into total,active_days
 from public.financial_impacts fi join public.financial_events fe on fe.id=fi.event_id and fe.space_id=fi.space_id
 join public.categories c on c.id=fi.category_id and c.space_id=fi.space_id
 where fi.space_id=p_space_id and fi.dimension='budget' and fi.effective_date>=today-7 and fi.effective_date<today
 and fe.status='confirmed' and fe.event_type in ('expense','card_purchase','refund') and not coalesce(c.essential,false)
 and coalesce(fe.necessity_class,'')<>'essential' and coalesce(fe.frequency_class,'')<>'fixed'
 and lower(coalesce(fe.metadata->>'hidden','false'))<>'true'
 and not exists(select 1 from public.recurring_occurrences ro where ro.space_id=p_space_id and ro.event_id=fe.id);
 average:=round(total/7,2);
 risk:=round(greatest(average*coalesce(snap.days_until_income,0)-greatest(snap.spendable_pool,0),0),2);
 state:=case when uncertain>0 then 'review_needed' when snap.next_income_date is null then 'income_needed'
 when active_days<3 then 'insufficient_history' when risk>=50 and average>coalesce(snap.daily_folego,0)*1.20 then 'at_risk' else 'on_track' end;
 return jsonb_build_object('status',state,'window_start',today-7,'window_end',today-1,'active_days',active_days,'recent_total',total,'average_per_day',average,'daily_limit',snap.daily_folego,'spendable',snap.spendable_pool,'days_until_income',snap.days_until_income,'next_income_date',snap.next_income_date,'projected_excess',risk,'unclassified_recent',uncertain);
end; $$;
revoke all on function public.get_spending_pace(uuid,date) from public,anon;
grant execute on function public.get_spending_pace(uuid,date) to authenticated,service_role;

create or replace function public.get_daily_financial_review(p_space_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); tz text; today date; pending integer; current_review jsonb; days jsonb;
begin
 if uid is null or not exists(select 1 from public.space_members sm where sm.user_id=uid and sm.space_id=p_space_id) then raise exception 'not_authorized'; end if;
 select timezone into tz from public.financial_spaces where id=p_space_id;
 today:=(now() at time zone tz)::date;
 select count(*) into pending from public.financial_events fe where fe.space_id=p_space_id and fe.status='confirmed'
 and fe.event_type in ('income','benefit_credit','reimbursement','expense','card_purchase','benefit_expense','refund','debt_payment')
 and lower(coalesce(fe.metadata->>'needs_classification','false'))='true' and lower(coalesce(fe.metadata->>'hidden','false'))<>'true';
 select to_jsonb(r) into current_review from public.daily_financial_reviews r where user_id=uid and space_id=p_space_id and review_date=today;
 select coalesce(jsonb_agg(review_date order by review_date),'[]'::jsonb) into days from public.daily_financial_reviews where user_id=uid and space_id=p_space_id and completed_at is not null and review_date>=today-6;
 return jsonb_build_object('pending_count',pending,'today',today,'review',current_review,'completed_days',days,'spending_pace',public.get_spending_pace(p_space_id,today));
end; $$;

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
  is_followup boolean;
  is_weekly boolean;
  pace jsonb;
  review_complete boolean;
  reason text;
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

    pace:=public.get_spending_pace(pref.space_id,today_local);
    select exists(select 1 from public.daily_financial_reviews r where r.user_id=pref.user_id and r.space_id=pref.space_id and r.review_date=today_local and r.completed_at is not null) into review_complete;
    if exists(select 1 from public.daily_financial_reviews r where r.user_id=pref.user_id and r.space_id=pref.space_id and r.review_date=today_local and r.snoozed_until>p_now) then continue; end if;
    if review_complete and pace->>'status'<>'at_risk' then continue; end if;
    is_weekly:=pref.weekly_review_enabled and extract(isodow from today_local)=7;
    is_followup:=false;
    candidate_key := 'daily_summary:' || pref.space_id::text || ':' || today_local::text;
    if exists(select 1 from public.web_push_delivery_log dl where dl.user_id=pref.user_id and dl.stable_key=candidate_key) then
      if review_complete or not pref.commitment_enabled or p_now<scheduled_at+interval '90 minutes' then continue; end if;
      is_followup:=true;
      candidate_key:='daily_followup:'||pref.space_id::text||':'||today_local::text;
    end if;
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
    title := case pref.reminder_style
      when 'welcoming' then 'Vamos cuidar do seu Fôlego?'
      when 'firm' then 'Sua revisão precisa de você'
      when 'aggressive' then 'Porra, bora organizar essa grana!'
      else 'Sua revisão do Fôlego' end;
    reason := case
      when pace->>'status'='at_risk' then 'Nos últimos 7 dias: '||private.format_brl((pace->>'average_per_day')::numeric)||'/dia; limite atual: '||private.format_brl(coalesce((pace->>'daily_limit')::numeric,0))||'/dia. Mantendo essa média, o disponível pode faltar em '||private.format_brl((pace->>'projected_excess')::numeric)||' até receber. Confira o Plano.'
      when pending_count>0 then pending_count::text||' lançamento(s) esperando classificação. Resolva até 5 agora para atualizar seu planejamento.'
      when overdue_count>0 then overdue_count::text||' item(ns) atrasado(s). Confira antes de assumir outro gasto.'
      when is_weekly then 'Confira as contas da próxima semana e o limite até receber.'
      else 'Confira os movimentos e as próximas contas; conclua mesmo se não teve movimentações.' end;
    if review_complete then title:='Seu ritmo de gastos merece atenção'; end if;
    body := case pref.reminder_style
      when 'welcoming' then 'Vamos cuidar da sua grana? '
      when 'firm' then 'Confira isso antes da próxima compra. '
      when 'aggressive' then case when pace->>'status'='at_risk' then 'Porra, esse ritmo pode apertar sua grana. ' when pending_count>0 then 'Caralho, organiza essas pendências antes de gastar de novo. ' else 'Bora conferir essa porra antes de gastar. ' end
      else '' end || reason || E'\n' || candidate_body;
    if is_followup then body:='A revisão continua aberta. '||body; end if;
    route := '/';
    return next;
    emitted := emitted + 1;
    if emitted >= p_limit then exit; end if;
  end loop;

  perform set_config('request.jwt.claim.sub', '', true);
end;
$function$;

REVOKE ALL ON FUNCTION public.get_daily_summary_push_candidates(timestamptz,integer) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_daily_summary_push_candidates(timestamptz,integer) TO service_role;
