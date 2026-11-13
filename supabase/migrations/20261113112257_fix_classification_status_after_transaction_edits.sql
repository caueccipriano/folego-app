-- Deploy migration 20261113112257_fix_classification_status_after_transaction_edits
-- No financial amount, date, account, invoice or installment changes.
-- Saving a valid economic category marks a transaction reviewed, including
-- confirmation of a category already assigned through another screen.
-- Retains existing authorization, RLS checks and financial history locks.

CREATE OR REPLACE FUNCTION private.update_simple_transaction_impl(p_space_id uuid, p_event_id uuid, p_account_id uuid, p_amount numeric, p_description text, p_category_id uuid, p_occurred_at timestamp with time zone, p_competence_date date)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
      metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object(
        'needs_classification',not exists(
          select 1 from public.categories c where c.id=v_category_id
          and c.space_id=p_space_id and c.active and c.category_role='economic'
          and c.is_selectable and c.kind=v_event_type),
        'classified_via',case when exists(
          select 1 from public.categories c where c.id=v_category_id
          and c.space_id=p_space_id and c.active and c.category_role='economic'
          and c.is_selectable and c.kind=v_event_type) then 'app'::text else null end,
        'classified_at',case when exists(
          select 1 from public.categories c where c.id=v_category_id
          and c.space_id=p_space_id and c.active and c.category_role='economic'
          and c.is_selectable and c.kind=v_event_type) then now() else null end),
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

CREATE OR REPLACE FUNCTION public.update_benefit_expense(p_space_id uuid, p_event_id uuid, p_account_id uuid, p_amount numeric, p_description text, p_category_id uuid, p_occurred_at timestamp with time zone)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_timezone text;
  v_effective_date date;
  v_amount numeric;
  v_event public.financial_events%rowtype;
begin
  if auth.uid() is null or not private.can_write_space(p_space_id) then raise exception 'write_access_denied'; end if;
  select * into v_event from public.financial_events
  where id=p_event_id and space_id=p_space_id for update;
  if v_event.id is null or v_event.event_type <> 'benefit_expense' or v_event.status <> 'confirmed' then
    raise exception 'benefit_expense_not_editable';
  end if;
  if coalesce((v_event.metadata->>'legacy_exception')::boolean,false) then raise exception 'legacy_event_read_only'; end if;
  if p_amount <= 0 or nullif(btrim(p_description),'') is null then raise exception 'invalid_amount_or_description'; end if;
  if not exists(select 1 from public.accounts where id=p_account_id and space_id=p_space_id and active and type='benefit') then
    raise exception 'invalid_benefit_account';
  end if;
  if p_category_id is not null and not exists(select 1 from public.categories where id=p_category_id and space_id=p_space_id and kind='expense') then
    raise exception 'invalid_category';
  end if;
  select timezone into v_timezone from public.financial_spaces where id=p_space_id;
  v_effective_date := (coalesce(p_occurred_at,v_event.occurred_at) at time zone v_timezone)::date;
  v_amount := round(p_amount,2);

  update public.financial_events set
    description=btrim(p_description), amount=v_amount,
    occurred_at=coalesce(p_occurred_at,v_event.occurred_at),
    competence_date=v_effective_date,category_id=p_category_id,
    metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object(
      'needs_classification',not (exists (select 1 from public.categories c
          where c.id=p_category_id and c.space_id=p_space_id
            and c.active and c.kind='expense'
            and c.category_role='economic' and c.is_selectable)),
      'classified_via',case when exists (select 1 from public.categories c
          where c.id=p_category_id and c.space_id=p_space_id
            and c.active and c.kind='expense'
            and c.category_role='economic' and c.is_selectable) then 'app'::text else null end,
      'classified_at',case when exists (select 1 from public.categories c
          where c.id=p_category_id and c.space_id=p_space_id
            and c.active and c.kind='expense'
            and c.category_role='economic' and c.is_selectable) then now() else null end),updated_at=now()
  where id=p_event_id and space_id=p_space_id;

  delete from public.financial_impacts where event_id=p_event_id and space_id=p_space_id;
  insert into public.financial_impacts(
    space_id,event_id,dimension,amount,account_id,category_id,effective_date
  ) values
    (p_space_id,p_event_id,'benefit',-v_amount,p_account_id,null,v_effective_date),
    (p_space_id,p_event_id,'economic',-v_amount,null,p_category_id,v_effective_date),
    (p_space_id,p_event_id,'budget',-v_amount,null,p_category_id,v_effective_date);
  return p_event_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.update_card_purchase(p_space_id uuid, p_event_id uuid, p_total_amount numeric, p_description text, p_category_id uuid, p_merchant text, p_card_id uuid, p_purchase_at timestamp with time zone)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_event public.financial_events%rowtype;
  v_purchase public.card_purchases%rowtype;
  v_financial_change boolean;
  v_installment public.card_installments%rowtype;
  v_piece numeric;
  v_remaining numeric;
  v_amount numeric;
  v_first_competence date;
begin
  if auth.uid() is null or not private.can_write_space(p_space_id) then raise exception 'write_access_denied'; end if;
  select * into v_event from public.financial_events where id=p_event_id and space_id=p_space_id for update;
  select * into v_purchase from public.card_purchases where event_id=p_event_id and space_id=p_space_id for update;
  if v_event.id is null or v_event.event_type <> 'card_purchase' or v_event.status <> 'confirmed' or v_purchase.id is null or v_purchase.status <> 'confirmed' then
    raise exception 'card_purchase_not_editable';
  end if;
  if coalesce((v_event.metadata->>'legacy_exception')::boolean,false) then raise exception 'legacy_event_read_only'; end if;
  if p_total_amount <= 0 or nullif(btrim(p_description),'') is null then raise exception 'invalid_amount_or_description'; end if;
  if p_category_id is not null and not exists(select 1 from public.categories where id=p_category_id and space_id=p_space_id and kind='expense') then raise exception 'invalid_category'; end if;
  if p_card_id is distinct from v_purchase.card_id or p_purchase_at is distinct from v_purchase.purchase_at then
    raise exception 'card_purchase_structure_locked';
  end if;
  if exists(select 1 from public.financial_impacts where event_id=p_event_id and space_id=p_space_id and dimension='cash') then
    raise exception 'card_purchase_has_invalid_cash_impact';
  end if;

  v_amount := round(p_total_amount,2);
  v_financial_change := v_amount is distinct from v_purchase.total_amount or p_category_id is distinct from v_purchase.category_id;
  if v_financial_change then
    if exists(
      select 1 from public.card_installments ci join public.card_invoices inv on inv.id=ci.invoice_id and inv.space_id=ci.space_id
      where ci.purchase_id=v_purchase.id and ci.space_id=p_space_id
        and (inv.status <> 'open' or ci.status in ('paid','cancelled','refunded'))
    ) then raise exception 'card_purchase_financial_history_locked'; end if;
    if exists(
      select 1 from public.card_installments ci join public.card_payments cp on cp.invoice_id=ci.invoice_id and cp.space_id=ci.space_id
      where ci.purchase_id=v_purchase.id and ci.space_id=p_space_id and cp.status <> 'cancelled'
    ) then raise exception 'card_purchase_invoice_has_payment'; end if;
  end if;

  update public.card_purchases set
    description=btrim(p_description),merchant=nullif(btrim(p_merchant),''),
    total_amount=v_amount,category_id=p_category_id,updated_at=now()
  where id=v_purchase.id;
  update public.financial_events set
    description=btrim(p_description),amount=v_amount,category_id=p_category_id,
    metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object(
      'needs_classification',not (exists (select 1 from public.categories c
          where c.id=p_category_id and c.space_id=p_space_id
            and c.active and c.kind='expense'
            and c.category_role='economic' and c.is_selectable)),
      'classified_via',case when exists (select 1 from public.categories c
          where c.id=p_category_id and c.space_id=p_space_id
            and c.active and c.kind='expense'
            and c.category_role='economic' and c.is_selectable) then 'app'::text else null end,
      'classified_at',case when exists (select 1 from public.categories c
          where c.id=p_category_id and c.space_id=p_space_id
            and c.active and c.kind='expense'
            and c.category_role='economic' and c.is_selectable) then now() else null end),updated_at=now()
  where id=p_event_id;

  if v_financial_change then
    v_piece := round(v_amount / v_purchase.installments_count,2);
    v_remaining := v_amount;
    for v_installment in
      select * from public.card_installments where purchase_id=v_purchase.id and space_id=p_space_id order by installment_number for update
    loop
      if v_installment.installment_number = v_purchase.installments_count then
        v_piece := v_remaining;
      end if;
      update public.card_installments set amount=v_piece,updated_at=now() where id=v_installment.id;
      v_remaining := v_remaining - v_piece;
    end loop;

    delete from public.financial_impacts
    where event_id=p_event_id and space_id=p_space_id and dimension in ('economic','budget');
    insert into public.financial_impacts(space_id,event_id,dimension,amount,category_id,effective_date)
    select p_space_id,p_event_id,'economic',-ci.amount,p_category_id,ci.competence_date
    from public.card_installments ci where ci.purchase_id=v_purchase.id and ci.space_id=p_space_id
    union all
    select p_space_id,p_event_id,'budget',-ci.amount,p_category_id,ci.competence_date
    from public.card_installments ci where ci.purchase_id=v_purchase.id and ci.space_id=p_space_id;
    select min(competence_date) into v_first_competence from public.card_installments where purchase_id=v_purchase.id and space_id=p_space_id;
    update public.financial_events set competence_date=v_first_competence where id=p_event_id;
  end if;
  return p_event_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.update_card_purchase_labels(p_space_id uuid, p_event_id uuid, p_description text, p_category_id uuid, p_merchant text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_event public.financial_events%rowtype;
  v_purchase public.card_purchases%rowtype;
  v_description text := btrim(p_description);
  v_merchant text := nullif(btrim(p_merchant), '');
BEGIN
  IF (SELECT auth.uid()) IS NULL
     OR NOT private.can_write_space(p_space_id) THEN
    RAISE EXCEPTION 'write_access_denied';
  END IF;

  SELECT * INTO v_event FROM public.financial_events
    WHERE id = p_event_id AND space_id = p_space_id FOR UPDATE;
  SELECT * INTO v_purchase FROM public.card_purchases
    WHERE event_id = p_event_id AND space_id = p_space_id FOR UPDATE;

  IF v_event.id IS NULL OR v_event.event_type <> 'card_purchase'
     OR v_event.status <> 'confirmed' OR v_purchase.id IS NULL
     OR v_purchase.status <> 'confirmed' THEN
    RAISE EXCEPTION 'card_purchase_not_editable';
  END IF;
  IF coalesce((v_event.metadata->>'legacy_exception')::boolean, false) THEN
    RAISE EXCEPTION 'legacy_event_read_only';
  END IF;
  IF v_description IS NULL OR length(v_description) NOT BETWEEN 1 AND 240
     OR length(coalesce(v_merchant, '')) > 160 THEN
    RAISE EXCEPTION 'invalid_purchase_labels';
  END IF;
  IF p_category_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.categories c
    WHERE c.id = p_category_id AND c.space_id = p_space_id
      AND c.kind = 'expense' AND c.category_role = 'economic'
      AND c.active AND c.is_selectable
  ) THEN
    RAISE EXCEPTION 'invalid_category';
  END IF;

  UPDATE public.card_purchases SET
    description = v_description,
    merchant = v_merchant,
    category_id = p_category_id,
    updated_at = now()
  WHERE id = v_purchase.id AND space_id = p_space_id;

  UPDATE public.financial_events SET
    description = v_description,
    category_id = p_category_id,
    metadata = coalesce(metadata,'{}'::jsonb) ||
      jsonb_build_object(
        'needs_classification',p_category_id IS NULL,
        'classified_via',case when p_category_id IS NOT NULL then 'app'::text else null end,
        'classified_at',case when p_category_id IS NOT NULL then now() else null end
      ),
    updated_at = now()
  WHERE id = p_event_id AND space_id = p_space_id;

  -- Only re-label existing economic/budget impacts. Never update their
  -- amounts, dates, accounts, installment structure or payment records.
  IF p_category_id IS DISTINCT FROM v_event.category_id THEN
    UPDATE public.financial_impacts SET category_id = p_category_id
    WHERE event_id = p_event_id AND space_id = p_space_id
      AND dimension IN ('economic', 'budget');
  END IF;

  RETURN p_event_id;
END;
$function$;
