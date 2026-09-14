-- Applied to Supabase as migration 20260914200359_fix_benefit_ledger_semantics.
-- Scope: benefit ledger semantics only. No historical data is rewritten.

create or replace function private.register_benefit(
  p_space_id uuid,
  p_account_id uuid,
  p_amount numeric,
  p_description text,
  p_is_credit boolean,
  p_category_id uuid default null::uuid
)
returns uuid
language plpgsql
security definer
set search_path to ''
as $function$
declare
  eid uuid;
  today date;
  currency char(3);
  v_amount numeric;
begin
  if auth.uid() is null or not private.can_write_space(p_space_id) then
    raise exception 'write_access_denied';
  end if;

  if p_amount <= 0 or nullif(btrim(p_description), '') is null then
    raise exception 'invalid_amount_or_description';
  end if;

  if not exists (
    select 1
    from public.accounts
    where id = p_account_id
      and space_id = p_space_id
      and active
      and type = 'benefit'
  ) then
    raise exception 'invalid_benefit_account';
  end if;

  if p_category_id is not null and not exists (
    select 1
    from public.categories
    where id = p_category_id
      and space_id = p_space_id
      and kind = case when p_is_credit then 'income' else 'expense' end
  ) then
    raise exception 'invalid_category';
  end if;

  select f.currency, (now() at time zone f.timezone)::date
  into currency, today
  from public.financial_spaces f
  where id = p_space_id;

  v_amount := round(p_amount, 2);

  insert into public.financial_events(
    space_id,
    event_type,
    description,
    amount,
    currency,
    occurred_at,
    competence_date,
    category_id,
    status,
    source
  )
  values(
    p_space_id,
    case when p_is_credit then 'benefit_credit' else 'benefit_expense' end,
    btrim(p_description),
    v_amount,
    currency,
    now(),
    today,
    p_category_id,
    'confirmed',
    'app'
  )
  returning id into eid;

  if p_is_credit then
    insert into public.financial_impacts(
      space_id,
      event_id,
      dimension,
      amount,
      account_id,
      effective_date
    )
    values(
      p_space_id,
      eid,
      'benefit',
      v_amount,
      p_account_id,
      today
    );
  else
    insert into public.financial_impacts(
      space_id,
      event_id,
      dimension,
      amount,
      account_id,
      category_id,
      effective_date
    )
    values
      (p_space_id, eid, 'benefit', -v_amount, p_account_id, null, today),
      (p_space_id, eid, 'economic', -v_amount, null, p_category_id, today),
      (p_space_id, eid, 'budget', -v_amount, null, p_category_id, today);
  end if;

  return eid;
end;
$function$;

create or replace function private.onboarding_create_account_impl(
  p_space_id uuid,
  p_name text,
  p_opening_balance numeric default 0,
  p_balance_date date default current_date,
  p_institution text default null::text,
  p_type text default 'checking'::text,
  p_available_for_spending boolean default null::boolean
)
returns uuid
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_account_id uuid;
  v_event_id uuid;
  v_available boolean;
  v_external_id text;
  v_impact_dimension text;
begin
  if not private.can_write_space(p_space_id) then
    raise exception 'Not allowed to write this financial space' using errcode = '42501';
  end if;

  if nullif(btrim(p_name), '') is null then
    raise exception 'Account name is required';
  end if;

  if p_type not in ('checking', 'savings', 'cash', 'reserve', 'benefit', 'investment', 'other') then
    raise exception 'Invalid account type';
  end if;

  v_available := coalesce(
    p_available_for_spending,
    case when p_type in ('reserve', 'benefit', 'investment') then false else true end
  );

  insert into public.accounts(
    space_id,
    name,
    institution,
    type,
    available_for_spending,
    active
  )
  values(
    p_space_id,
    btrim(p_name),
    nullif(btrim(p_institution), ''),
    p_type,
    v_available,
    true
  )
  on conflict(space_id, name) do update
    set institution = excluded.institution,
        type = excluded.type,
        available_for_spending = excluded.available_for_spending,
        active = true,
        updated_at = now()
  returning id into v_account_id;

  v_external_id := 'onboarding:opening_balance:' || v_account_id::text;

  if coalesce(p_opening_balance, 0) = 0 then
    delete from public.financial_events
    where space_id = p_space_id
      and external_id = v_external_id
      and event_type = 'opening_balance';
  else
    insert into public.financial_events(
      space_id,
      event_type,
      description,
      amount,
      currency,
      occurred_at,
      competence_date,
      status,
      source,
      external_id,
      metadata
    )
    values(
      p_space_id,
      'opening_balance',
      'Saldo inicial - ' || btrim(p_name),
      abs(p_opening_balance),
      'BRL',
      p_balance_date::timestamp,
      p_balance_date,
      'confirmed',
      'onboarding',
      v_external_id,
      jsonb_build_object('account_id', v_account_id)
    )
    on conflict(space_id, external_id) where external_id is not null do update
      set description = excluded.description,
          amount = excluded.amount,
          occurred_at = excluded.occurred_at,
          competence_date = excluded.competence_date,
          metadata = excluded.metadata,
          updated_at = now()
    returning id into v_event_id;

    delete from public.financial_impacts
    where event_id = v_event_id;

    v_impact_dimension := case when p_type = 'benefit' then 'benefit' else 'cash' end;

    insert into public.financial_impacts(
      event_id,
      space_id,
      dimension,
      amount,
      account_id,
      effective_date,
      metadata
    )
    values(
      v_event_id,
      p_space_id,
      v_impact_dimension,
      p_opening_balance,
      v_account_id,
      p_balance_date,
      '{"origin":"opening_balance"}'::jsonb
    );
  end if;

  return v_account_id;
end;
$function$;
