create or replace function private.format_brl(p_amount numeric)
returns text
language sql
immutable
set search_path = ''
as $$
  select 'R$ ' || replace(to_char(coalesce(p_amount, 0), 'FM999999990.00'), '.', ',');
$$;

revoke all on function private.format_brl(numeric) from public, anon, authenticated;

create or replace function public.get_daily_summary_push_candidates(
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
begin
  p_limit := least(greatest(coalesce(p_limit, 100), 1), 500);

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
    order by np.updated_at, np.space_id
  loop
    perform set_config('request.jwt.claim.sub', pref.user_id::text, true);
    today_local := (p_now at time zone pref.timezone)::date;
    scheduled_at := (today_local::timestamp + pref.preferred_time) at time zone pref.timezone;

    if scheduled_at > p_now then
      continue;
    end if;

    candidate_key := 'daily_summary:' || pref.space_id::text || ':' || today_local::text;
    if exists (
      select 1
      from public.web_push_delivery_log dl
      where dl.user_id = pref.user_id
        and dl.stable_key = candidate_key
    ) then
      continue;
    end if;

    select * into snap
    from public.get_folego_snapshot(pref.space_id, today_local)
    limit 1;

    select count(*)::integer into category_attention_count
    from public.get_budget_overview(
      pref.space_id,
      date_trunc('month', today_local)::date
    ) b
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
    from public.get_upcoming_events(
      pref.space_id,
      today_local + 1,
      today_local + 1,
      200
    ) u
    where u.due_date = today_local + 1;

    select count(*)::integer into overdue_count
    from public.get_upcoming_events(
      pref.space_id,
      today_local - 30,
      today_local,
      200
    ) u
    where u.overdue;

    candidate_body := private.format_brl(coalesce(snap.spendable_pool, 0))
      || ' livres • '
      || private.format_brl(coalesce(snap.daily_folego, 0))
      || '/dia';

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
    title := '☀️ Seu Fôlego de hoje';
    body := candidate_body;
    route := '/';
    return next;

    p_limit := p_limit - 1;
    if p_limit <= 0 then
      perform set_config('request.jwt.claim.sub', '', true);
      return;
    end if;
  end loop;

  perform set_config('request.jwt.claim.sub', '', true);
end;
$$;

revoke all on function public.get_daily_summary_push_candidates(timestamptz, integer) from public, anon, authenticated;
grant execute on function public.get_daily_summary_push_candidates(timestamptz, integer) to service_role;

create or replace function private.baseline_daily_summary_state(
  p_user_id uuid,
  p_space_id uuid default null,
  p_now timestamptz default now()
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  pref record;
  today_local date;
  scheduled_at timestamptz;
  candidate_key text;
begin
  for pref in
    select np.*, fs.timezone
    from public.notification_preferences np
    join public.financial_spaces fs on fs.id = np.space_id
    where np.user_id = p_user_id
      and np.financial_reminders_enabled
      and (p_space_id is null or np.space_id = p_space_id)
  loop
    today_local := (p_now at time zone pref.timezone)::date;
    scheduled_at := (today_local::timestamp + pref.preferred_time) at time zone pref.timezone;
    if scheduled_at <= p_now then
      candidate_key := 'daily_summary:' || pref.space_id::text || ':' || today_local::text;
      insert into public.web_push_delivery_log(user_id, space_id, stable_key, kind)
      values (pref.user_id, pref.space_id, candidate_key, 'dailySummary')
      on conflict (user_id, stable_key) do nothing;
    end if;
  end loop;
end;
$$;

revoke all on function private.baseline_daily_summary_state(uuid, uuid, timestamptz) from public, anon, authenticated;

create or replace function private.baseline_daily_summary_on_subscription()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.baseline_daily_summary_state(new.user_id, null, now());
  return new;
end;
$$;

revoke all on function private.baseline_daily_summary_on_subscription() from public, anon, authenticated;

drop trigger if exists web_push_daily_summary_baseline on public.web_push_subscriptions;
create trigger web_push_daily_summary_baseline
after insert on public.web_push_subscriptions
for each row execute function private.baseline_daily_summary_on_subscription();

create or replace function private.baseline_daily_summary_on_reminders_reenabled()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.baseline_daily_summary_state(new.user_id, new.space_id, now());
  return new;
end;
$$;

revoke all on function private.baseline_daily_summary_on_reminders_reenabled() from public, anon, authenticated;

drop trigger if exists notification_preferences_daily_summary_reenable_baseline on public.notification_preferences;
create trigger notification_preferences_daily_summary_reenable_baseline
after update of financial_reminders_enabled on public.notification_preferences
for each row
when (new.financial_reminders_enabled = true and old.financial_reminders_enabled = false)
execute function private.baseline_daily_summary_on_reminders_reenabled();

create or replace function private.invoke_folego_daily_summary_dispatch()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_token text;
begin
  select s.decrypted_secret into v_token
  from vault.decrypted_secrets s
  where s.name = 'folego_web_push_cron_secret'
  limit 1;

  if v_token is null or v_token = '' then
    return;
  end if;

  perform net.http_post(
    url := 'https://ycumrvkwqizlnehelhek.supabase.co/functions/v1/folego-daily-summary',
    headers := jsonb_build_object('Content-Type', 'application/json'),
    body := jsonb_build_object('cron_token', v_token),
    timeout_milliseconds := 10000
  );
end;
$$;

revoke all on function private.invoke_folego_daily_summary_dispatch() from public, anon, authenticated;

do $$
declare
  r record;
begin
  for r in
    select distinct ws.user_id
    from public.web_push_subscriptions ws
    where ws.disabled_at is null
  loop
    perform private.baseline_daily_summary_state(r.user_id, null, now());
  end loop;
end $$;

do $$
declare
  existing_job bigint;
begin
  for existing_job in
    select jobid from cron.job where jobname = 'folego-daily-summary-dispatch'
  loop
    perform cron.unschedule(existing_job);
  end loop;

  perform cron.schedule(
    'folego-daily-summary-dispatch',
    '*/5 * * * *',
    'select private.invoke_folego_daily_summary_dispatch();'
  );
end $$;
