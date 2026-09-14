-- Applied to Supabase as migration 20260914203948_protect_simple_transaction_updates_from_benefit_accounts.
-- Scope: reject simple income/expense edits that target benefit accounts.
-- No historical data is rewritten.

create or replace function private.update_simple_transaction_impl(
  p_space_id uuid,
  p_event_id uuid,
  p_account_id uuid,
  p_amount numeric,
  p_description text,
  p_category_id uuid,
  p_occurred_at timestamptz,
  p_competence_date date
)
returns uuid
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_event_type text;
  v_status text;
  v_timezone text;
  v_effective_date date;
  v_category_id uuid;
  v_account_type text;
begin
  if auth.uid() is null then
    raise exception 'authentication_required';
  end if;

  if not private.can_write_space(p_space_id) then
    raise exception 'write_access_denied';
  end if;

  if p_amount is null or p_amount <= 0 then
    raise exception 'amount_must_be_positive';
  end if;

  if nullif(btrim(p_description), '') is null then
    raise exception 'description_required';
  end if;

  if p_occurred_at is null then
    raise exception 'occurred_at_required';
  end if;

  select e.event_type, e.status
    into v_event_type, v_status
  from public.financial_events e
  where e.id = p_event_id
    and e.space_id = p_space_id
  for update;

  if v_event_type is null then
    raise exception 'invalid_transaction';
  end if;

  if v_event_type not in ('income', 'expense') then
    raise exception 'transaction_type_not_editable';
  end if;

  if v_status <> 'confirmed' then
    raise exception 'transaction_not_confirmed';
  end if;

  select fs.timezone
    into v_timezone
  from public.financial_spaces fs
  where fs.id = p_space_id;

  select a.type
    into v_account_type
  from public.accounts a
  where a.id = p_account_id
    and a.space_id = p_space_id
    and a.active;

  if v_account_type is null then
    raise exception 'invalid_account';
  end if;

  if v_account_type = 'benefit' then
    raise exception 'benefit_account_requires_benefit_operation';
  end if;

  if v_event_type = 'expense' then
    if p_category_id is null then
      select c.id
        into v_category_id
      from public.categories c
      where c.space_id = p_space_id
        and c.active
        and c.kind = 'expense'
        and c.name = 'A classificar'
      limit 1;
    else
      select c.id
        into v_category_id
      from public.categories c
      where c.id = p_category_id
        and c.space_id = p_space_id
        and c.active
        and c.kind = 'expense';
    end if;

    if v_category_id is null then
      raise exception 'invalid_expense_category';
    end if;
  else
    if p_category_id is not null and not exists (
      select 1
      from public.categories c
      where c.id = p_category_id
        and c.space_id = p_space_id
        and c.active
        and c.kind = 'income'
    ) then
      raise exception 'invalid_income_category';
    end if;

    v_category_id := p_category_id;
  end if;

  v_effective_date := coalesce(
    p_competence_date,
    (p_occurred_at at time zone coalesce(v_timezone, 'America/Sao_Paulo'))::date
  );

  update public.financial_events
  set description = btrim(p_description),
      amount = round(p_amount, 2),
      occurred_at = p_occurred_at,
      competence_date = v_effective_date,
      category_id = v_category_id,
      updated_at = now()
  where id = p_event_id
    and space_id = p_space_id;

  delete from public.financial_impacts
  where event_id = p_event_id
    and space_id = p_space_id;

  if v_event_type = 'income' then
    insert into public.financial_impacts(
      event_id,
      space_id,
      dimension,
      amount,
      account_id,
      category_id,
      effective_date
    )
    values
      (p_event_id, p_space_id, 'cash', round(p_amount, 2), p_account_id, null, v_effective_date),
      (p_event_id, p_space_id, 'economic', round(p_amount, 2), null, v_category_id, v_effective_date);
  else
    insert into public.financial_impacts(
      event_id,
      space_id,
      dimension,
      amount,
      account_id,
      category_id,
      effective_date
    )
    values
      (p_event_id, p_space_id, 'cash', -round(p_amount, 2), p_account_id, null, v_effective_date),
      (p_event_id, p_space_id, 'economic', -round(p_amount, 2), null, v_category_id, v_effective_date),
      (p_event_id, p_space_id, 'budget', -round(p_amount, 2), null, v_category_id, v_effective_date);
  end if;

  return p_event_id;
end;
$function$;
