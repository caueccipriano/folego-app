-- Applied to Supabase Dev as 20260916011831_build_financial_agenda_experience.
-- Agenda remains a projection over canonical recurring, invoice and debt sources.

drop function if exists public.get_upcoming_events(uuid, date, date);

create function public.get_upcoming_events(
  p_space_id uuid,
  p_start_date date default null,
  p_end_date date default null,
  p_limit integer default 120
)
returns table(
  event_key text,
  source text,
  source_id uuid,
  parent_id uuid,
  title text,
  subtitle text,
  due_date date,
  amount numeric,
  direction text,
  status text,
  category_id uuid,
  account_id uuid,
  card_id uuid,
  debt_id uuid,
  overdue boolean,
  realized boolean,
  recurring boolean,
  installment_number integer,
  installment_count integer,
  invoice_id uuid,
  navigation_target text,
  day_offset integer,
  cash_obligation boolean
)
language plpgsql
stable
security invoker
set search_path to ''
as $function$
declare
  v_timezone text;
  v_today date;
  v_start date;
  v_end date;
  v_limit integer;
begin
  if auth.uid() is null or not private.is_space_member(p_space_id) then
    raise exception 'read_access_denied' using errcode = '42501';
  end if;

  select fs.timezone into v_timezone
  from public.financial_spaces fs
  where fs.id = p_space_id;
  if v_timezone is null then raise exception 'financial_space_not_found'; end if;

  v_today := (now() at time zone v_timezone)::date;
  v_start := coalesce(p_start_date, v_today);
  v_end := coalesce(p_end_date, v_start + 29);
  v_limit := least(greatest(coalesce(p_limit, 120), 1), 200);
  if v_end < v_start or v_end > v_start + 366 then
    raise exception 'invalid_agenda_range';
  end if;

  return query
  with calendar as (
    select gs::date as d
    from generate_series(v_start::timestamp, v_end::timestamp, interval '1 day') gs
  ),
  recurring_rows as (
    select
      ('recurring:' || r.id::text || ':' || c.d::text)::text as event_key,
      'recurring'::text as source,
      r.id as source_id,
      null::uuid as parent_id,
      r.name::text as title,
      case
        when r.item_type = 'income' then 'entrada recorrente'
        when r.card_id is not null then 'recorrente · cartão ' || coalesce(cc.name, '')
        else 'recorrente · conta ' || coalesce(a.name, '')
      end::text as subtitle,
      c.d::date as due_date,
      coalesce(ro.expected_amount, r.amount)::numeric as amount,
      case
        when r.item_type = 'income' then 'income'
        when r.card_id is not null then 'informational'
        else 'outflow'
      end::text as direction,
      coalesce(ro.status, 'pending')::text as status,
      r.category_id,
      r.account_id,
      r.card_id,
      null::uuid as debt_id,
      (c.d < v_today)::boolean as overdue,
      false::boolean as realized,
      true::boolean as recurring,
      null::integer as installment_number,
      null::integer as installment_count,
      null::uuid as invoice_id,
      'recurring'::text as navigation_target,
      (c.d - v_today)::integer as day_offset,
      (r.item_type = 'expense' and r.account_id is not null)::boolean as cash_obligation
    from public.recurring_items r
    join calendar c
      on c.d >= greatest(r.starts_on, v_start)
     and (r.ends_on is null or c.d <= r.ends_on)
    left join public.recurring_occurrences ro
      on ro.recurring_item_id = r.id
     and ro.space_id = r.space_id
     and ro.due_date = c.d
    left join public.accounts a
      on a.id = r.account_id and a.space_id = r.space_id
    left join public.credit_cards cc
      on cc.id = r.card_id and cc.space_id = r.space_id
    where r.space_id = p_space_id
      and r.active
      and r.certainty in ('confirmed', 'expected')
      and coalesce(ro.status, 'pending') = 'pending'
      and (
        (r.frequency = 'monthly' and (
          extract(day from c.d)::int = any(coalesce(r.monthly_days, '{}'::integer[]))
          or (r.monthly_last_day and c.d = (date_trunc('month', c.d) + interval '1 month - 1 day')::date)
          or (
            cardinality(coalesce(r.monthly_days, '{}'::integer[])) = 0
            and not r.monthly_last_day
            and r.day_of_month is not null
            and extract(day from c.d)::int = least(
              r.day_of_month,
              extract(day from date_trunc('month', c.d) + interval '1 month - 1 day')::int
            )
          )
        ))
        or (r.frequency = 'weekly' and extract(dow from c.d)::int = r.weekday)
        or (r.frequency = 'biweekly' and c.d >= r.starts_on and ((c.d - r.starts_on) % 14) = 0)
        or (
          r.frequency = 'yearly'
          and extract(month from c.d)::int = r.month_of_year
          and extract(day from c.d)::int = least(
            r.day_of_month,
            extract(day from date_trunc('month', c.d) + interval '1 month - 1 day')::int
          )
        )
      )
  ),
  invoice_rows as (
    select
      ('invoice:' || i.id::text)::text as event_key,
      'invoice'::text as source,
      i.id as source_id,
      c.id as parent_id,
      ('Fatura ' || c.name)::text as title,
      case
        when count(ci.id) filter (where ci.status not in ('cancelled', 'refunded')) = 1
          then '1 parcela compõe esta fatura'
        else count(ci.id) filter (where ci.status not in ('cancelled', 'refunded'))::text || ' parcelas compõem esta fatura'
      end::text as subtitle,
      i.due_date,
      greatest(
        i.opening_balance
        + coalesce(sum(ci.amount) filter (where ci.status not in ('cancelled', 'refunded')), 0)
        - coalesce((
          select sum(cp.amount)
          from public.card_payments cp
          where cp.invoice_id = i.id
            and cp.space_id = i.space_id
            and cp.status = 'confirmed'
        ), 0),
        0
      )::numeric as amount,
      'outflow'::text as direction,
      case when i.due_date < v_today then 'overdue' else 'pending' end::text as status,
      null::uuid as category_id,
      c.payment_account_id as account_id,
      c.id as card_id,
      null::uuid as debt_id,
      (i.due_date < v_today)::boolean as overdue,
      false::boolean as realized,
      false::boolean as recurring,
      null::integer as installment_number,
      null::integer as installment_count,
      i.id as invoice_id,
      'card_invoice'::text as navigation_target,
      (i.due_date - v_today)::integer as day_offset,
      true::boolean as cash_obligation
    from public.card_invoices i
    join public.credit_cards c
      on c.id = i.card_id and c.space_id = i.space_id
    left join public.card_installments ci
      on ci.invoice_id = i.id and ci.space_id = i.space_id
    where i.space_id = p_space_id
      and i.status not in ('paid', 'cancelled')
      and i.due_date <= v_end
      and (i.due_date >= v_start or i.due_date < v_today)
    group by i.id, i.space_id, i.opening_balance, i.due_date, c.id, c.name, c.payment_account_id
  ),
  debt_rows as (
    select
      ('debt:' || di.id::text)::text as event_key,
      'debt'::text as source,
      di.id as source_id,
      d.id as parent_id,
      d.name::text as title,
      ('parcela ' || di.installment_number || coalesce(' de ' || d.total_installments::text, '') ||
       case when nullif(btrim(d.creditor), '') is null then '' else ' · ' || d.creditor end)::text as subtitle,
      di.due_date,
      greatest(di.planned_amount - di.paid_amount, 0)::numeric as amount,
      'outflow'::text as direction,
      case when di.due_date < v_today then 'overdue' else di.status end::text as status,
      null::uuid as category_id,
      d.payment_account_id as account_id,
      null::uuid as card_id,
      d.id as debt_id,
      (di.due_date < v_today and di.status not in ('paid', 'cancelled'))::boolean as overdue,
      false::boolean as realized,
      false::boolean as recurring,
      di.installment_number::integer,
      d.total_installments::integer,
      null::uuid as invoice_id,
      'debt'::text as navigation_target,
      (di.due_date - v_today)::integer as day_offset,
      true::boolean as cash_obligation
    from public.debt_installments di
    join public.debts d on d.id = di.debt_id and d.space_id = di.space_id
    where di.space_id = p_space_id
      and di.status in ('pending', 'partially_paid', 'overdue')
      and d.status = 'active'
      and di.due_date <= v_end
      and (di.due_date >= v_start or di.due_date < v_today)
      and coalesce((to_jsonb(d) ->> 'archived_at') is null, true)
  ),
  combined as (
    select * from recurring_rows
    union all select * from invoice_rows
    union all select * from debt_rows
  )
  select c.*
  from combined c
  where c.amount > 0
  order by c.due_date asc, c.title asc, c.event_key asc
  limit v_limit;
end;
$function$;

revoke all on function public.get_upcoming_events(uuid,date,date,integer) from public;
revoke all on function public.get_upcoming_events(uuid,date,date,integer) from anon;
grant execute on function public.get_upcoming_events(uuid,date,date,integer) to authenticated;
