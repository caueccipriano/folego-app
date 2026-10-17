create or replace function private.create_wallet_account_impl(
  p_space_id uuid,
  p_name text,
  p_opening_balance numeric default 0,
  p_balance_date date default current_date,
  p_institution text default null,
  p_type text default 'checking',
  p_available_for_spending boolean default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_account_id uuid;
  v_event_id uuid;
  v_available boolean;
  v_dimension text;
  v_balance numeric := round(coalesce(p_opening_balance, 0), 2);
begin
  if auth.uid() is null then
    raise exception 'authentication_required';
  end if;
  if not private.can_write_space(p_space_id) then
    raise exception 'write_access_denied';
  end if;
  if nullif(btrim(p_name), '') is null then
    raise exception 'account_name_required';
  end if;
  if p_type not in ('checking','savings','cash','reserve','benefit','investment','other') then
    raise exception 'invalid_account_type';
  end if;

  v_available := case
    when p_type in ('reserve','benefit','investment') then false
    else coalesce(p_available_for_spending, true)
  end;

  insert into public.accounts(space_id,name,institution,type,available_for_spending,active)
  values(
    p_space_id,
    btrim(p_name),
    nullif(btrim(p_institution), ''),
    p_type,
    v_available,
    true
  )
  returning id into v_account_id;

  if v_balance <> 0 then
    insert into public.financial_events(
      space_id,event_type,description,amount,currency,occurred_at,competence_date,
      category_id,status,source,external_id,metadata
    )
    select
      p_space_id,
      'opening_balance',
      'Saldo inicial - ' || btrim(p_name),
      abs(v_balance),
      fs.currency,
      p_balance_date::timestamp,
      p_balance_date,
      null,
      'confirmed',
      'app',
      'wallet:opening_balance:' || v_account_id::text,
      jsonb_build_object('account_id', v_account_id, 'origin', 'wallet_management')
    from public.financial_spaces fs
    where fs.id = p_space_id
    returning id into v_event_id;

    v_dimension := case when p_type = 'benefit' then 'benefit' else 'cash' end;
    insert into public.financial_impacts(
      event_id,space_id,dimension,amount,account_id,category_id,effective_date,metadata
    ) values (
      v_event_id,p_space_id,v_dimension,v_balance,v_account_id,null,p_balance_date,
      jsonb_build_object('origin','opening_balance')
    );
  end if;

  return v_account_id;
exception
  when unique_violation then
    raise exception 'account_name_already_exists';
end;
$$;

create or replace function public.create_wallet_account(
  p_space_id uuid,
  p_name text,
  p_opening_balance numeric default 0,
  p_balance_date date default current_date,
  p_institution text default null,
  p_type text default 'checking',
  p_available_for_spending boolean default null
)
returns uuid
language sql
set search_path = ''
as $$
  select private.create_wallet_account_impl($1,$2,$3,$4,$5,$6,$7);
$$;

create or replace function private.update_wallet_account_impl(
  p_space_id uuid,
  p_account_id uuid,
  p_name text,
  p_institution text,
  p_type text,
  p_available_for_spending boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_current_type text;
  v_active boolean;
  v_available boolean;
  v_crosses_benefit_boundary boolean;
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if not private.can_write_space(p_space_id) then raise exception 'write_access_denied'; end if;
  if nullif(btrim(p_name), '') is null then raise exception 'account_name_required'; end if;
  if p_type not in ('checking','savings','cash','reserve','benefit','investment','other') then
    raise exception 'invalid_account_type';
  end if;

  select a.type,a.active into v_current_type,v_active
  from public.accounts a
  where a.id=p_account_id and a.space_id=p_space_id
  for update;

  if v_current_type is null then raise exception 'invalid_account'; end if;
  if not v_active then raise exception 'account_archived'; end if;

  v_crosses_benefit_boundary := (v_current_type='benefit') <> (p_type='benefit');
  if v_crosses_benefit_boundary and (
    exists(select 1 from public.financial_impacts i where i.space_id=p_space_id and i.account_id=p_account_id)
    or exists(select 1 from public.recurring_items r where r.space_id=p_space_id and r.account_id=p_account_id and r.active)
    or exists(select 1 from public.credit_cards c where c.space_id=p_space_id and c.payment_account_id=p_account_id and c.active)
    or exists(select 1 from public.debts d where d.space_id=p_space_id and d.payment_account_id=p_account_id and d.status='active' and d.archived_at is null)
  ) then
    raise exception 'account_type_history_conflict';
  end if;

  v_available := case
    when p_type in ('reserve','benefit','investment') then false
    else coalesce(p_available_for_spending, true)
  end;

  update public.accounts
  set name=btrim(p_name),
      institution=nullif(btrim(p_institution),''),
      type=p_type,
      available_for_spending=v_available,
      updated_at=now()
  where id=p_account_id and space_id=p_space_id;
exception
  when unique_violation then
    raise exception 'account_name_already_exists';
end;
$$;

create or replace function public.update_wallet_account(
  p_space_id uuid,
  p_account_id uuid,
  p_name text,
  p_institution text,
  p_type text,
  p_available_for_spending boolean
)
returns void
language sql
set search_path = ''
as $$
  select private.update_wallet_account_impl($1,$2,$3,$4,$5,$6);
$$;

create or replace function private.archive_wallet_account_impl(
  p_space_id uuid,
  p_account_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_type text;
  v_active boolean;
  v_dimension text;
  v_balance numeric;
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if not private.can_write_space(p_space_id) then raise exception 'write_access_denied'; end if;

  select a.type,a.active into v_type,v_active
  from public.accounts a
  where a.id=p_account_id and a.space_id=p_space_id
  for update;
  if v_type is null then raise exception 'invalid_account'; end if;
  if not v_active then return; end if;

  v_dimension := case when v_type='benefit' then 'benefit' else 'cash' end;
  select coalesce(sum(i.amount),0) into v_balance
  from public.financial_impacts i
  where i.space_id=p_space_id and i.account_id=p_account_id and i.dimension=v_dimension;

  if abs(round(v_balance,2)) > 0.01 then raise exception 'account_has_balance'; end if;
  if exists(select 1 from public.recurring_items r where r.space_id=p_space_id and r.account_id=p_account_id and r.active) then
    raise exception 'account_has_active_recurring';
  end if;
  if exists(select 1 from public.credit_cards c where c.space_id=p_space_id and c.payment_account_id=p_account_id and c.active) then
    raise exception 'account_is_card_payment_account';
  end if;
  if exists(select 1 from public.debts d where d.space_id=p_space_id and d.payment_account_id=p_account_id and d.status='active' and d.archived_at is null) then
    raise exception 'account_is_debt_payment_account';
  end if;

  update public.accounts set active=false,updated_at=now()
  where id=p_account_id and space_id=p_space_id;
end;
$$;

create or replace function public.archive_wallet_account(p_space_id uuid,p_account_id uuid)
returns void
language sql
set search_path = ''
as $$
  select private.archive_wallet_account_impl($1,$2);
$$;

create or replace function private.create_wallet_card_impl(
  p_space_id uuid,
  p_name text,
  p_closing_day integer,
  p_due_day integer,
  p_payment_account_id uuid,
  p_issuer text default null,
  p_brand text default null,
  p_last_four text default null,
  p_personal_limit numeric default null,
  p_issuer_limit numeric default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_card_id uuid;
  v_last_four text := nullif(btrim(p_last_four),'');
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if not private.can_write_space(p_space_id) then raise exception 'write_access_denied'; end if;
  if nullif(btrim(p_name),'') is null then raise exception 'card_name_required'; end if;
  if p_closing_day not between 1 and 31 or p_due_day not between 1 and 31 then raise exception 'invalid_card_cycle'; end if;
  if p_personal_limit is not null and p_personal_limit < 0 then raise exception 'invalid_card_limit'; end if;
  if p_issuer_limit is not null and p_issuer_limit < 0 then raise exception 'invalid_card_limit'; end if;
  if v_last_four is not null and v_last_four !~ '^[0-9]{4}$' then raise exception 'invalid_last_four'; end if;
  if not exists(
    select 1 from public.accounts a
    where a.id=p_payment_account_id and a.space_id=p_space_id and a.active and a.type<>'benefit'
  ) then raise exception 'invalid_payment_account'; end if;

  insert into public.credit_cards(
    space_id,name,issuer,brand,last_four,closing_day,due_day,issuer_limit,personal_limit,payment_account_id,active
  ) values (
    p_space_id,btrim(p_name),nullif(btrim(p_issuer),''),nullif(btrim(p_brand),''),v_last_four,
    p_closing_day,p_due_day,p_issuer_limit,p_personal_limit,p_payment_account_id,true
  ) returning id into v_card_id;

  return v_card_id;
exception
  when unique_violation then
    raise exception 'card_name_already_exists';
end;
$$;

create or replace function public.create_wallet_card(
  p_space_id uuid,
  p_name text,
  p_closing_day integer,
  p_due_day integer,
  p_payment_account_id uuid,
  p_issuer text default null,
  p_brand text default null,
  p_last_four text default null,
  p_personal_limit numeric default null,
  p_issuer_limit numeric default null
)
returns uuid
language sql
set search_path = ''
as $$
  select private.create_wallet_card_impl($1,$2,$3,$4,$5,$6,$7,$8,$9,$10);
$$;

create or replace function private.update_wallet_card_impl(
  p_space_id uuid,
  p_card_id uuid,
  p_name text,
  p_closing_day integer,
  p_due_day integer,
  p_payment_account_id uuid,
  p_issuer text,
  p_brand text,
  p_last_four text,
  p_personal_limit numeric
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_active boolean;
  v_last_four text := nullif(btrim(p_last_four),'');
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if not private.can_write_space(p_space_id) then raise exception 'write_access_denied'; end if;
  if nullif(btrim(p_name),'') is null then raise exception 'card_name_required'; end if;
  if p_closing_day not between 1 and 31 or p_due_day not between 1 and 31 then raise exception 'invalid_card_cycle'; end if;
  if p_personal_limit is not null and p_personal_limit < 0 then raise exception 'invalid_card_limit'; end if;
  if v_last_four is not null and v_last_four !~ '^[0-9]{4}$' then raise exception 'invalid_last_four'; end if;
  if not exists(
    select 1 from public.accounts a
    where a.id=p_payment_account_id and a.space_id=p_space_id and a.active and a.type<>'benefit'
  ) then raise exception 'invalid_payment_account'; end if;

  select c.active into v_active
  from public.credit_cards c
  where c.id=p_card_id and c.space_id=p_space_id
  for update;
  if v_active is null then raise exception 'invalid_card'; end if;
  if not v_active then raise exception 'card_archived'; end if;

  update public.credit_cards
  set name=btrim(p_name),issuer=nullif(btrim(p_issuer),''),brand=nullif(btrim(p_brand),''),last_four=v_last_four,
      closing_day=p_closing_day,due_day=p_due_day,personal_limit=p_personal_limit,
      payment_account_id=p_payment_account_id,updated_at=now()
  where id=p_card_id and space_id=p_space_id;
exception
  when unique_violation then
    raise exception 'card_name_already_exists';
end;
$$;

create or replace function public.update_wallet_card(
  p_space_id uuid,
  p_card_id uuid,
  p_name text,
  p_closing_day integer,
  p_due_day integer,
  p_payment_account_id uuid,
  p_issuer text,
  p_brand text,
  p_last_four text,
  p_personal_limit numeric
)
returns void
language sql
set search_path = ''
as $$
  select private.update_wallet_card_impl($1,$2,$3,$4,$5,$6,$7,$8,$9,$10);
$$;

create or replace function private.archive_wallet_card_impl(p_space_id uuid,p_card_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_active boolean;
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if not private.can_write_space(p_space_id) then raise exception 'write_access_denied'; end if;

  select c.active into v_active
  from public.credit_cards c
  where c.id=p_card_id and c.space_id=p_space_id
  for update;
  if v_active is null then raise exception 'invalid_card'; end if;
  if not v_active then return; end if;

  if exists(select 1 from public.recurring_items r where r.space_id=p_space_id and r.card_id=p_card_id and r.active) then
    raise exception 'card_has_active_recurring';
  end if;

  if exists(
    select 1
    from public.card_invoices ci
    where ci.space_id=p_space_id and ci.card_id=p_card_id and ci.status not in ('paid','cancelled')
      and greatest(
        ci.opening_balance
        + coalesce((select sum(x.amount) from public.card_installments x where x.space_id=ci.space_id and x.invoice_id=ci.id and x.status not in ('cancelled','refunded')),0)
        - coalesce((select sum(cp.amount) from public.card_payments cp where cp.space_id=ci.space_id and cp.invoice_id=ci.id and cp.status='confirmed'),0),
        0
      ) > 0.01
  ) then raise exception 'card_has_open_invoice'; end if;

  if exists(
    select 1
    from public.card_installments ci
    join public.card_purchases p on p.id=ci.purchase_id and p.space_id=ci.space_id
    join public.card_invoices inv on inv.id=ci.invoice_id and inv.space_id=ci.space_id
    where ci.space_id=p_space_id and p.card_id=p_card_id
      and p.status not in ('cancelled','refunded')
      and ci.status not in ('paid','cancelled','refunded')
      and inv.status not in ('paid','cancelled')
  ) then raise exception 'card_has_future_installments'; end if;

  update public.credit_cards set active=false,updated_at=now()
  where id=p_card_id and space_id=p_space_id;
end;
$$;

create or replace function public.archive_wallet_card(p_space_id uuid,p_card_id uuid)
returns void
language sql
set search_path = ''
as $$
  select private.archive_wallet_card_impl($1,$2);
$$;

revoke all on function public.create_wallet_account(uuid,text,numeric,date,text,text,boolean) from public, anon;
revoke all on function public.update_wallet_account(uuid,uuid,text,text,text,boolean) from public, anon;
revoke all on function public.archive_wallet_account(uuid,uuid) from public, anon;
revoke all on function public.create_wallet_card(uuid,text,integer,integer,uuid,text,text,text,numeric,numeric) from public, anon;
revoke all on function public.update_wallet_card(uuid,uuid,text,integer,integer,uuid,text,text,text,numeric) from public, anon;
revoke all on function public.archive_wallet_card(uuid,uuid) from public, anon;

grant execute on function public.create_wallet_account(uuid,text,numeric,date,text,text,boolean) to authenticated, service_role;
grant execute on function public.update_wallet_account(uuid,uuid,text,text,text,boolean) to authenticated, service_role;
grant execute on function public.archive_wallet_account(uuid,uuid) to authenticated, service_role;
grant execute on function public.create_wallet_card(uuid,text,integer,integer,uuid,text,text,text,numeric,numeric) to authenticated, service_role;
grant execute on function public.update_wallet_card(uuid,uuid,text,integer,integer,uuid,text,text,text,numeric) to authenticated, service_role;
grant execute on function public.archive_wallet_card(uuid,uuid) to authenticated, service_role;

grant execute on function private.create_wallet_account_impl(uuid,text,numeric,date,text,text,boolean) to authenticated;
grant execute on function private.update_wallet_account_impl(uuid,uuid,text,text,text,boolean) to authenticated;
grant execute on function private.archive_wallet_account_impl(uuid,uuid) to authenticated;
grant execute on function private.create_wallet_card_impl(uuid,text,integer,integer,uuid,text,text,text,numeric,numeric) to authenticated;
grant execute on function private.update_wallet_card_impl(uuid,uuid,text,integer,integer,uuid,text,text,text,numeric) to authenticated;
grant execute on function private.archive_wallet_card_impl(uuid,uuid) to authenticated;
