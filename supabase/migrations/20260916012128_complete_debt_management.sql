-- Applied to Supabase Dev as 20260916012128_complete_debt_management.
-- Debt registration remains obligation-only. Debt payment preserves the canonical cash-only contract.

alter table public.debts
  add column if not exists debt_type text not null default 'other',
  add column if not exists notes text,
  add column if not exists archived_at timestamptz,
  add column if not exists closed_at timestamptz;

alter table public.debts drop constraint if exists debts_debt_type_check;
alter table public.debts add constraint debts_debt_type_check
  check (debt_type in ('loan','financing','installment','personal','other'));

create unique index if not exists debt_installments_id_space_uidx
  on public.debt_installments(id, space_id);

create table if not exists public.debt_payments (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.financial_spaces(id) on delete cascade,
  debt_id uuid not null,
  installment_id uuid not null,
  event_id uuid not null,
  account_id uuid not null,
  amount numeric not null check (amount > 0),
  paid_at timestamptz not null,
  status text not null default 'confirmed' check (status in ('confirmed','reversed')),
  created_at timestamptz not null default now(),
  constraint debt_payments_debt_fk foreign key (debt_id, space_id)
    references public.debts(id, space_id) on delete restrict,
  constraint debt_payments_installment_fk foreign key (installment_id, space_id)
    references public.debt_installments(id, space_id) on delete restrict,
  constraint debt_payments_event_fk foreign key (event_id, space_id)
    references public.financial_events(id, space_id) on delete restrict,
  constraint debt_payments_account_fk foreign key (account_id, space_id)
    references public.accounts(id, space_id) on delete restrict,
  constraint debt_payments_event_key unique (event_id)
);

create index if not exists debt_payments_debt_paid_idx
  on public.debt_payments(space_id, debt_id, paid_at desc);
create index if not exists debt_payments_installment_idx
  on public.debt_payments(space_id, installment_id, paid_at desc);

alter table public.debt_payments enable row level security;

drop policy if exists debt_payments_select_member on public.debt_payments;
create policy debt_payments_select_member
on public.debt_payments for select to authenticated
using ((select private.is_space_member(space_id)));

drop policy if exists debt_payments_insert_writer on public.debt_payments;
create policy debt_payments_insert_writer
on public.debt_payments for insert to authenticated
with check ((select private.can_write_space(space_id)));

drop policy if exists debt_payments_update_writer on public.debt_payments;
create policy debt_payments_update_writer
on public.debt_payments for update to authenticated
using ((select private.can_write_space(space_id)))
with check ((select private.can_write_space(space_id)));

revoke all on public.debt_payments from anon;
grant select on public.debt_payments to authenticated;

create or replace function private.create_debt_v2(
  p_space_id uuid,
  p_name text,
  p_creditor text,
  p_original_amount numeric,
  p_total_installments integer,
  p_first_due date,
  p_payment_account_id uuid default null,
  p_started_on date default null,
  p_interest_rate_monthly numeric default null,
  p_debt_type text default 'other',
  p_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_debt_id uuid;
  v_i integer;
  v_due date;
  v_total numeric;
  v_base numeric;
  v_amount numeric;
  v_today date;
begin
  if auth.uid() is null or not private.can_write_space(p_space_id) then
    raise exception 'write_access_denied' using errcode = '42501';
  end if;
  if nullif(btrim(p_name), '') is null
     or nullif(btrim(p_creditor), '') is null
     or p_original_amount is null or p_original_amount <= 0
     or p_total_installments not between 1 and 360
     or p_first_due is null
     or coalesce(p_debt_type, '') not in ('loan','financing','installment','personal','other')
     or (p_interest_rate_monthly is not null and p_interest_rate_monthly < 0) then
    raise exception 'invalid_debt';
  end if;
  if p_payment_account_id is not null and not exists (
    select 1 from public.accounts
    where id = p_payment_account_id and space_id = p_space_id and active and type <> 'benefit'
  ) then
    raise exception 'invalid_account';
  end if;

  select (now() at time zone timezone)::date into v_today
  from public.financial_spaces where id = p_space_id;

  v_total := round(p_original_amount, 2);
  v_base := floor((v_total * 100) / p_total_installments) / 100;

  insert into public.debts(
    space_id, name, creditor, original_amount, opening_balance,
    interest_rate_monthly, total_installments, payment_account_id,
    status, started_on, debt_type, notes
  ) values (
    p_space_id, btrim(p_name), btrim(p_creditor), v_total, v_total,
    p_interest_rate_monthly, p_total_installments, p_payment_account_id,
    'active', coalesce(p_started_on, v_today), p_debt_type, nullif(btrim(p_notes), '')
  ) returning id into v_debt_id;

  for v_i in 1..p_total_installments loop
    v_due := private.card_date_in_month(
      (date_trunc('month', p_first_due) + make_interval(months => v_i - 1))::date,
      extract(day from p_first_due)::int
    );
    v_amount := case
      when v_i = p_total_installments then round(v_total - (v_base * (p_total_installments - 1)), 2)
      else v_base
    end;
    insert into public.debt_installments(
      space_id, debt_id, installment_number, due_date, planned_amount
    ) values (p_space_id, v_debt_id, v_i, v_due, v_amount);
  end loop;
  return v_debt_id;
end;
$function$;

create or replace function public.create_debt_v2(
  p_space_id uuid,
  p_name text,
  p_creditor text,
  p_original_amount numeric,
  p_total_installments integer,
  p_first_due date,
  p_payment_account_id uuid default null,
  p_started_on date default null,
  p_interest_rate_monthly numeric default null,
  p_debt_type text default 'other',
  p_notes text default null
)
returns uuid
language sql
security invoker
set search_path to ''
as $function$
  select private.create_debt_v2(
    p_space_id,p_name,p_creditor,p_original_amount,p_total_installments,p_first_due,
    p_payment_account_id,p_started_on,p_interest_rate_monthly,p_debt_type,p_notes
  );
$function$;

create or replace function private.update_debt_v2(
  p_space_id uuid,
  p_debt_id uuid,
  p_name text,
  p_creditor text,
  p_original_amount numeric,
  p_total_installments integer,
  p_first_due date,
  p_payment_account_id uuid default null,
  p_started_on date default null,
  p_interest_rate_monthly numeric default null,
  p_debt_type text default 'other',
  p_notes text default null
)
returns void
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_debt public.debts;
  v_current_first_due date;
  v_current_total numeric;
  v_structural_change boolean;
  v_i integer;
  v_due date;
  v_total numeric;
  v_base numeric;
  v_amount numeric;
begin
  if auth.uid() is null or not private.can_write_space(p_space_id) then
    raise exception 'write_access_denied' using errcode = '42501';
  end if;
  select * into v_debt
  from public.debts
  where id = p_debt_id and space_id = p_space_id
  for update;
  if v_debt.id is null or v_debt.status <> 'active' then
    raise exception 'invalid_debt';
  end if;
  if nullif(btrim(p_name), '') is null
     or nullif(btrim(p_creditor), '') is null
     or p_original_amount is null or p_original_amount <= 0
     or p_total_installments not between 1 and 360
     or p_first_due is null
     or coalesce(p_debt_type, '') not in ('loan','financing','installment','personal','other')
     or (p_interest_rate_monthly is not null and p_interest_rate_monthly < 0) then
    raise exception 'invalid_debt';
  end if;
  if p_payment_account_id is not null and not exists (
    select 1 from public.accounts
    where id = p_payment_account_id and space_id = p_space_id and active and type <> 'benefit'
  ) then
    raise exception 'invalid_account';
  end if;

  select min(due_date) into v_current_first_due
  from public.debt_installments
  where debt_id = p_debt_id and space_id = p_space_id and status <> 'cancelled';
  v_current_total := coalesce(v_debt.original_amount, v_debt.opening_balance);
  v_total := round(p_original_amount, 2);
  v_structural_change :=
    v_total is distinct from round(v_current_total, 2)
    or p_total_installments is distinct from v_debt.total_installments::integer
    or p_first_due is distinct from v_current_first_due;

  if v_structural_change and exists (
    select 1 from public.debt_installments
    where debt_id = p_debt_id and space_id = p_space_id
      and (paid_amount > 0 or payment_event_id is not null)
  ) then
    raise exception 'debt_restructure_after_payment';
  end if;
  if v_structural_change and exists (
    select 1 from public.debt_payments
    where debt_id = p_debt_id and space_id = p_space_id and status = 'confirmed'
  ) then
    raise exception 'debt_restructure_after_payment';
  end if;

  update public.debts set
    name = btrim(p_name),
    creditor = btrim(p_creditor),
    original_amount = v_total,
    opening_balance = v_total,
    interest_rate_monthly = p_interest_rate_monthly,
    total_installments = p_total_installments,
    payment_account_id = p_payment_account_id,
    started_on = p_started_on,
    debt_type = p_debt_type,
    notes = nullif(btrim(p_notes), ''),
    updated_at = now()
  where id = p_debt_id and space_id = p_space_id;

  if v_structural_change then
    delete from public.debt_installments
    where debt_id = p_debt_id and space_id = p_space_id;
    v_base := floor((v_total * 100) / p_total_installments) / 100;
    for v_i in 1..p_total_installments loop
      v_due := private.card_date_in_month(
        (date_trunc('month', p_first_due) + make_interval(months => v_i - 1))::date,
        extract(day from p_first_due)::int
      );
      v_amount := case
        when v_i = p_total_installments then round(v_total - (v_base * (p_total_installments - 1)), 2)
        else v_base
      end;
      insert into public.debt_installments(
        space_id, debt_id, installment_number, due_date, planned_amount
      ) values (p_space_id, p_debt_id, v_i, v_due, v_amount);
    end loop;
  end if;
end;
$function$;

create or replace function public.update_debt_v2(
  p_space_id uuid,
  p_debt_id uuid,
  p_name text,
  p_creditor text,
  p_original_amount numeric,
  p_total_installments integer,
  p_first_due date,
  p_payment_account_id uuid default null,
  p_started_on date default null,
  p_interest_rate_monthly numeric default null,
  p_debt_type text default 'other',
  p_notes text default null
)
returns void
language sql
security invoker
set search_path to ''
as $function$
  select private.update_debt_v2(
    p_space_id,p_debt_id,p_name,p_creditor,p_original_amount,p_total_installments,p_first_due,
    p_payment_account_id,p_started_on,p_interest_rate_monthly,p_debt_type,p_notes
  );
$function$;

create or replace function private.archive_debt(p_space_id uuid, p_debt_id uuid)
returns void
language plpgsql
security definer
set search_path to ''
as $function$
begin
  if auth.uid() is null or not private.can_write_space(p_space_id) then
    raise exception 'write_access_denied' using errcode = '42501';
  end if;
  update public.debts
  set archived_at = now(), updated_at = now()
  where id = p_debt_id and space_id = p_space_id and status = 'active';
  if not found then raise exception 'invalid_debt'; end if;
end;
$function$;

create or replace function public.archive_debt(p_space_id uuid, p_debt_id uuid)
returns void language sql security invoker set search_path to ''
as $function$ select private.archive_debt(p_space_id,p_debt_id); $function$;

create or replace function private.reopen_debt(p_space_id uuid, p_debt_id uuid)
returns void
language plpgsql
security definer
set search_path to ''
as $function$
begin
  if auth.uid() is null or not private.can_write_space(p_space_id) then
    raise exception 'write_access_denied' using errcode = '42501';
  end if;
  update public.debts
  set archived_at = null, updated_at = now()
  where id = p_debt_id and space_id = p_space_id and status = 'active' and archived_at is not null;
  if not found then raise exception 'invalid_debt'; end if;
end;
$function$;

create or replace function public.reopen_debt(p_space_id uuid, p_debt_id uuid)
returns void language sql security invoker set search_path to ''
as $function$ select private.reopen_debt(p_space_id,p_debt_id); $function$;

create or replace function private.close_debt(p_space_id uuid, p_debt_id uuid)
returns void
language plpgsql
security definer
set search_path to ''
as $function$
begin
  if auth.uid() is null or not private.can_write_space(p_space_id) then
    raise exception 'write_access_denied' using errcode = '42501';
  end if;
  if exists (
    select 1 from public.debt_installments
    where debt_id = p_debt_id and space_id = p_space_id
      and status not in ('paid','cancelled') and planned_amount - paid_amount > 0
  ) then
    raise exception 'debt_has_open_balance';
  end if;
  update public.debts
  set status = 'paid', closed_at = now(), updated_at = now()
  where id = p_debt_id and space_id = p_space_id and status = 'active';
  if not found then raise exception 'invalid_debt'; end if;
end;
$function$;

create or replace function public.close_debt(p_space_id uuid, p_debt_id uuid)
returns void language sql security invoker set search_path to ''
as $function$ select private.close_debt(p_space_id,p_debt_id); $function$;

create or replace function private.pay_debt_installment_v2(
  p_space_id uuid,
  p_installment_id uuid,
  p_account_id uuid,
  p_amount numeric,
  p_paid_at timestamptz default now()
)
returns uuid
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_installment public.debt_installments;
  v_debt public.debts;
  v_event_id uuid;
  v_currency char(3);
  v_effective_date date;
  v_amount numeric;
begin
  if auth.uid() is null or not private.can_write_space(p_space_id) then
    raise exception 'write_access_denied' using errcode = '42501';
  end if;
  select * into v_installment from public.debt_installments
  where id = p_installment_id and space_id = p_space_id for update;
  if v_installment.id is null
     or v_installment.status in ('paid','cancelled')
     or p_amount is null or p_amount <= 0
     or round(p_amount,2) > v_installment.planned_amount - v_installment.paid_amount then
    raise exception 'invalid_payment';
  end if;
  if not exists (
    select 1 from public.accounts
    where id = p_account_id and space_id = p_space_id and active and type <> 'benefit'
  ) then
    raise exception 'invalid_account';
  end if;
  select * into v_debt from public.debts
  where id = v_installment.debt_id and space_id = p_space_id and status = 'active' and archived_at is null;
  if v_debt.id is null then raise exception 'invalid_debt'; end if;

  select currency, (p_paid_at at time zone timezone)::date
  into v_currency, v_effective_date
  from public.financial_spaces where id = p_space_id;
  v_amount := round(p_amount,2);

  insert into public.financial_events(
    space_id,event_type,description,amount,currency,occurred_at,competence_date,status,source
  ) values (
    p_space_id,'debt_payment',v_debt.name || ' · parcela ' || v_installment.installment_number,
    v_amount,v_currency,p_paid_at,v_effective_date,'confirmed','app'
  ) returning id into v_event_id;

  insert into public.financial_impacts(
    space_id,event_id,dimension,amount,account_id,effective_date
  ) values (p_space_id,v_event_id,'cash',-v_amount,p_account_id,v_effective_date);

  insert into public.debt_payments(
    space_id,debt_id,installment_id,event_id,account_id,amount,paid_at,status
  ) values (
    p_space_id,v_debt.id,v_installment.id,v_event_id,p_account_id,v_amount,p_paid_at,'confirmed'
  );

  update public.debt_installments
  set paid_amount = paid_amount + v_amount,
      payment_event_id = v_event_id,
      status = case when paid_amount + v_amount >= planned_amount then 'paid' else 'partially_paid' end,
      updated_at = now()
  where id = v_installment.id;

  if not exists (
    select 1 from public.debt_installments
    where debt_id = v_debt.id and space_id = p_space_id
      and status not in ('paid','cancelled') and planned_amount - paid_amount > 0
  ) then
    update public.debts
    set status = 'paid', closed_at = now(), updated_at = now()
    where id = v_debt.id;
  end if;
  return v_event_id;
end;
$function$;

create or replace function public.pay_debt_installment_v2(
  p_space_id uuid,
  p_installment_id uuid,
  p_account_id uuid,
  p_amount numeric,
  p_paid_at timestamptz default now()
)
returns uuid
language sql
security invoker
set search_path to ''
as $function$
  select private.pay_debt_installment_v2(p_space_id,p_installment_id,p_account_id,p_amount,p_paid_at);
$function$;

create or replace function public.pay_debt_installment(
  p_space_id uuid,
  p_installment_id uuid,
  p_account_id uuid,
  p_amount numeric
)
returns uuid
language sql
security invoker
set search_path to ''
as $function$
  select private.pay_debt_installment_v2(p_space_id,p_installment_id,p_account_id,p_amount,now());
$function$;

create or replace function public.get_debt_detail(p_space_id uuid, p_debt_id uuid)
returns jsonb
language plpgsql
stable
security invoker
set search_path to ''
as $function$
declare
  v_timezone text;
  v_today date;
  v_result jsonb;
begin
  if auth.uid() is null or not private.is_space_member(p_space_id) then
    raise exception 'read_access_denied' using errcode = '42501';
  end if;
  select timezone into v_timezone from public.financial_spaces where id = p_space_id;
  v_today := (now() at time zone v_timezone)::date;

  select jsonb_build_object(
    'debt', jsonb_build_object(
      'id', d.id,
      'name', d.name,
      'creditor', d.creditor,
      'debt_type', d.debt_type,
      'notes', d.notes,
      'original_amount', d.original_amount,
      'opening_balance', d.opening_balance,
      'remaining_balance', coalesce((select sum(greatest(i.planned_amount-i.paid_amount,0)) from public.debt_installments i where i.debt_id=d.id and i.space_id=d.space_id and i.status not in ('cancelled')),0),
      'interest_rate_monthly', d.interest_rate_monthly,
      'total_installments', d.total_installments,
      'payment_account_id', d.payment_account_id,
      'status', d.status,
      'started_on', d.started_on,
      'archived_at', d.archived_at,
      'closed_at', d.closed_at,
      'first_due_date', (select min(i.due_date) from public.debt_installments i where i.debt_id=d.id and i.space_id=d.space_id and i.status <> 'cancelled')
    ),
    'installments', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', i.id,
        'installment_number', i.installment_number,
        'due_date', i.due_date,
        'planned_amount', i.planned_amount,
        'paid_amount', i.paid_amount,
        'remaining_amount', greatest(i.planned_amount-i.paid_amount,0),
        'status', i.status,
        'is_overdue', (i.due_date < v_today and i.status not in ('paid','cancelled'))
      ) order by i.installment_number)
      from public.debt_installments i
      where i.debt_id=d.id and i.space_id=d.space_id and i.status <> 'cancelled'
    ), '[]'::jsonb),
    'payments', coalesce((
      with payment_rows as (
        select dp.id, dp.event_id, dp.installment_id, i.installment_number,
               dp.amount, dp.paid_at, dp.account_id, a.name as account_name, dp.status
        from public.debt_payments dp
        join public.debt_installments i on i.id=dp.installment_id and i.space_id=dp.space_id
        join public.accounts a on a.id=dp.account_id and a.space_id=dp.space_id
        where dp.debt_id=d.id and dp.space_id=d.space_id
        union all
        select fe.id, fe.id, i.id, i.installment_number,
               fe.amount, fe.occurred_at,
               fi.account_id, a.name, 'confirmed'::text
        from public.debt_installments i
        join public.financial_events fe on fe.id=i.payment_event_id and fe.space_id=i.space_id
        join public.financial_impacts fi on fi.event_id=fe.id and fi.space_id=fe.space_id and fi.dimension='cash'
        join public.accounts a on a.id=fi.account_id and a.space_id=fi.space_id
        where i.debt_id=d.id and i.space_id=d.space_id
          and i.payment_event_id is not null
          and not exists (select 1 from public.debt_payments dp where dp.event_id=i.payment_event_id)
      )
      select jsonb_agg(jsonb_build_object(
        'id', p.id,
        'event_id', p.event_id,
        'installment_id', p.installment_id,
        'installment_number', p.installment_number,
        'amount', p.amount,
        'paid_at', p.paid_at,
        'account_id', p.account_id,
        'account_name', p.account_name,
        'status', p.status
      ) order by p.paid_at desc)
      from payment_rows p
    ), '[]'::jsonb),
    'today', v_today
  ) into v_result
  from public.debts d
  where d.id=p_debt_id and d.space_id=p_space_id;

  if v_result is null then raise exception 'debt_not_found'; end if;
  return v_result;
end;
$function$;

create or replace function public.get_wallet_overview(p_space_id uuid)
returns jsonb
language sql
stable
security invoker
set search_path to ''
as $function$
with account_rows as (
  select a.id,a.name,a.institution,a.type,a.available_for_spending,
    coalesce(sum(i.amount) filter (where i.dimension=case when a.type='benefit' then 'benefit' else 'cash' end),0::numeric) as balance
  from public.accounts a
  left join public.financial_impacts i on i.account_id=a.id and i.space_id=a.space_id
  where a.space_id=p_space_id and a.active
  group by a.id,a.name,a.institution,a.type,a.available_for_spending
),
card_rows as (
  select c.id,c.name,c.issuer,c.brand,c.last_four,c.closing_day,c.due_day,c.personal_limit,c.issuer_limit,c.payment_account_id,
    inv.invoice_id,inv.due_date,coalesce(inv.invoice_balance,0::numeric) as invoice_balance,
    case when coalesce(c.personal_limit,c.issuer_limit) is null then null else greatest(coalesce(c.personal_limit,c.issuer_limit)-coalesce(inv.invoice_balance,0::numeric),0::numeric) end as available_limit
  from public.credit_cards c
  left join lateral (
    select ci.id as invoice_id,ci.due_date,greatest(ci.opening_balance
      +coalesce((select sum(x.amount) from public.card_installments x where x.invoice_id=ci.id and x.space_id=ci.space_id and x.status not in ('cancelled','refunded')),0::numeric)
      -coalesce((select sum(p.amount) from public.card_payments p where p.invoice_id=ci.id and p.space_id=ci.space_id and p.status='confirmed'),0::numeric),0::numeric) as invoice_balance
    from public.card_invoices ci
    where ci.card_id=c.id and ci.space_id=c.space_id and ci.status not in ('paid','cancelled')
    order by ci.due_date asc limit 1
  ) inv on true
  where c.space_id=p_space_id and c.active
),
debt_rows as (
  select d.id,d.name,d.creditor,d.debt_type,d.notes,d.original_amount,d.opening_balance,d.interest_rate_monthly,d.total_installments,d.payment_account_id,d.status,d.started_on,d.archived_at,d.closed_at,
    coalesce(sum(greatest(di.planned_amount-di.paid_amount,0::numeric)) filter (where di.status in ('pending','partially_paid','overdue')),0::numeric) as remaining_balance,
    min(di.due_date) filter (where di.status in ('pending','partially_paid','overdue')) as next_due_date,
    coalesce((array_agg(greatest(di.planned_amount-di.paid_amount,0::numeric) order by di.due_date) filter (where di.status in ('pending','partially_paid','overdue')))[1],0::numeric) as next_amount,
    count(*) filter (where di.status='paid')::int as paid_installments
  from public.debts d
  left join public.debt_installments di on di.debt_id=d.id and di.space_id=d.space_id
  where d.space_id=p_space_id and d.status='active' and d.archived_at is null
  group by d.id,d.name,d.creditor,d.debt_type,d.notes,d.original_amount,d.opening_balance,d.interest_rate_monthly,d.total_installments,d.payment_account_id,d.status,d.started_on,d.archived_at,d.closed_at
),
installment_rows as (
  select p.id,p.description,p.merchant,p.total_amount,p.installments_count,p.card_id,c.name as card_name,
    count(ci.id) filter (where ci.status not in ('cancelled','refunded') and inv.status not in ('paid','cancelled'))::int as remaining_installments,
    coalesce(sum(ci.amount) filter (where ci.status not in ('cancelled','refunded') and inv.status not in ('paid','cancelled')),0::numeric) as remaining_amount,
    min(inv.due_date) filter (where ci.status not in ('cancelled','refunded') and inv.status not in ('paid','cancelled')) as next_due_date
  from public.card_purchases p
  join public.credit_cards c on c.id=p.card_id and c.space_id=p.space_id
  left join public.card_installments ci on ci.purchase_id=p.id and ci.space_id=p.space_id
  left join public.card_invoices inv on inv.id=ci.invoice_id and inv.space_id=p.space_id
  where p.space_id=p_space_id and p.status not in ('cancelled','refunded') and p.installments_count>1
  group by p.id,p.description,p.merchant,p.total_amount,p.installments_count,p.card_id,c.name
),
summary as (
  select
    coalesce((select sum(balance) from account_rows where type<>'benefit'),0::numeric) as total_cash,
    coalesce((select sum(balance) from account_rows where type<>'benefit' and available_for_spending),0::numeric) as available_cash,
    coalesce((select sum(balance) from account_rows where type='benefit'),0::numeric) as total_benefit,
    coalesce((select sum(invoice_balance) from card_rows),0::numeric) as total_card_invoice,
    coalesce((select sum(remaining_balance) from debt_rows),0::numeric) as total_debt_remaining
)
select jsonb_build_object(
  'summary',(select to_jsonb(summary) from summary),
  'accounts',coalesce((select jsonb_agg(to_jsonb(account_rows) order by name) from account_rows),'[]'::jsonb),
  'cards',coalesce((select jsonb_agg(to_jsonb(card_rows) order by name) from card_rows),'[]'::jsonb),
  'debts',coalesce((select jsonb_agg(to_jsonb(debt_rows) order by name) from debt_rows),'[]'::jsonb),
  'installments',coalesce((select jsonb_agg(to_jsonb(installment_rows) order by next_due_date nulls last,description) from installment_rows where remaining_installments>0),'[]'::jsonb)
);
$function$;

revoke all on function public.create_debt_v2(uuid,text,text,numeric,integer,date,uuid,date,numeric,text,text) from public, anon;
revoke all on function public.update_debt_v2(uuid,uuid,text,text,numeric,integer,date,uuid,date,numeric,text,text) from public, anon;
revoke all on function public.archive_debt(uuid,uuid) from public, anon;
revoke all on function public.reopen_debt(uuid,uuid) from public, anon;
revoke all on function public.close_debt(uuid,uuid) from public, anon;
revoke all on function public.pay_debt_installment_v2(uuid,uuid,uuid,numeric,timestamptz) from public, anon;
revoke all on function public.pay_debt_installment(uuid,uuid,uuid,numeric) from public, anon;
revoke all on function public.get_debt_detail(uuid,uuid) from public, anon;
grant execute on function public.create_debt_v2(uuid,text,text,numeric,integer,date,uuid,date,numeric,text,text) to authenticated;
grant execute on function public.update_debt_v2(uuid,uuid,text,text,numeric,integer,date,uuid,date,numeric,text,text) to authenticated;
grant execute on function public.archive_debt(uuid,uuid) to authenticated;
grant execute on function public.reopen_debt(uuid,uuid) to authenticated;
grant execute on function public.close_debt(uuid,uuid) to authenticated;
grant execute on function public.pay_debt_installment_v2(uuid,uuid,uuid,numeric,timestamptz) to authenticated;
grant execute on function public.pay_debt_installment(uuid,uuid,uuid,numeric) to authenticated;
grant execute on function public.get_debt_detail(uuid,uuid) to authenticated;
