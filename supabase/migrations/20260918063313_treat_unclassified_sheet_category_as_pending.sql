-- The canonical expense/card registrars use "A classificar" as a safe
-- placeholder when no category was supplied. For sheet-sync this is not a
-- confident classification: try the exact sheet map and otherwise require
-- manual review.

create or replace function public.apply_sheet_category_mapping()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_original text;
  v_key text;
  v_category_id uuid;
  v_expected_kind text;
  v_already_pending boolean;
  v_category_is_placeholder boolean := false;
begin
  if new.source <> 'sheet-sync'
     or coalesce(new.metadata->>'sheet_linked','false') <> 'true' then
    return new;
  end if;

  v_expected_kind := case
    when new.event_type in ('income','benefit_credit','reimbursement') then 'income'
    when new.event_type in ('expense','card_purchase','benefit_expense','refund','debt_payment') then 'expense'
    else null
  end;

  if v_expected_kind is null then
    return new;
  end if;

  if new.category_id is not null then
    select exists (
      select 1
      from public.categories c
      where c.id = new.category_id
        and c.space_id = new.space_id
        and c.name = 'A classificar'
    )
    into v_category_is_placeholder;

    if not v_category_is_placeholder then
      return new;
    end if;
  end if;

  v_original := lower(trim(coalesce(new.metadata->>'sheet_category_original','')));

  if v_original <> '' then
    v_key := case v_original
      when 'alimentação' then 'expense.food'
      when 'assinaturas' then 'expense.subscriptions'
      when 'beleza' then 'expense.beauty'
      when 'calçados' then 'expense.shopping.shoes'
      when 'casa/decoração' then 'expense.shopping.home'
      when 'compras online' then 'expense.shopping.online'
      when 'condomínio' then 'expense.housing.condo'
      when 'connectcar' then 'expense.transport.parking_toll'
      when 'crediário' then 'expense.debt.installments'
      when 'delivery' then 'expense.food.delivery'
      when 'educação' then 'expense.education'
      when 'eletro/móveis' then 'expense.shopping'
      when 'eletrônicos' then 'expense.shopping.electronics'
      when 'empréstimos' then 'expense.debt.loans'
      when 'energia' then 'expense.household.energy'
      when 'estacionamento/pedágio' then 'expense.transport.parking_toll'
      when 'estorno' then case when v_expected_kind='income' then 'income.reimbursement' else null end
      when 'farmácia' then 'expense.health.pharmacy'
      when 'gasolina' then 'expense.transport.fuel'
      when 'gás' then 'expense.household.gas'
      when 'ipva/licenciamento' then 'expense.transport.vehicle_tax'
      when 'impostos/taxas' then 'expense.finance.taxes'
      when 'internet/telefone' then 'expense.household'
      when 'juros' then 'expense.finance.interest'
      when 'lazer' then 'expense.leisure'
      when 'manutenção carro' then 'expense.transport.maintenance'
      when 'manutenção do carro' then 'expense.transport.maintenance'
      when 'mercado livre' then 'expense.shopping.marketplace'
      when 'moradia' then 'expense.housing'
      when 'outros' then case when v_expected_kind='income' then 'income.other' else 'expense.other.other' end
      when 'pets' then 'expense.pets'
      when 'presentes' then 'expense.gifts.presents'
      when 'reembolso' then case when v_expected_kind='income' then 'income.reimbursement' else null end
      when 'rendimentos' then 'income.investment_returns'
      when 'restaurantes' then 'expense.food.restaurant'
      when 'salário' then 'income.salary'
      when 'saúde' then 'expense.health'
      when 'seguros' then 'expense.insurance'
      when 'supermercado' then 'expense.food.groceries'
      when 'suplementos' then 'expense.health.supplements'
      when 'tarifas bancárias' then 'expense.finance.bank_fees'
      when 'transporte' then 'expense.transport'
      when 'vestuário' then 'expense.shopping.clothes'
      when 'viagens' then 'expense.travel'
      when 'água' then 'expense.household.water'
      else null
    end;
  end if;

  if v_key is not null then
    select c.id into v_category_id
    from public.categories c
    where c.space_id = new.space_id
      and c.system_key = v_key
      and c.kind = v_expected_kind
      and c.category_role = 'economic'
      and c.active = true
    limit 1;
  end if;

  if v_category_id is not null then
    update public.financial_events
    set category_id = v_category_id,
        metadata = coalesce(new.metadata,'{}'::jsonb) || jsonb_build_object(
          'classified_by','sheet_category_map',
          'classification_key',v_key,
          'needs_classification',false,
          'sheet_category_mapped_at',now()
        ),
        updated_at = now()
    where id = new.id;

    update public.financial_impacts
    set category_id = v_category_id
    where event_id = new.id
      and dimension in ('economic','budget');

    update public.card_purchases
    set category_id = v_category_id,
        updated_at = now()
    where event_id = new.id;

    return new;
  end if;

  v_already_pending :=
    coalesce((new.metadata->>'needs_classification')::boolean, false);

  if not v_already_pending then
    update public.financial_events
    set metadata = coalesce(new.metadata,'{}'::jsonb) || jsonb_build_object(
          'needs_classification', true,
          'classification_reason', 'sheet_category_unmapped',
          'classification_requested_at', now()
        ),
        updated_at = now()
    where id = new.id;
  end if;

  return new;
end;
$function$;

revoke all on function public.apply_sheet_category_mapping()
  from public, anon, authenticated;

update public.financial_events fe
set metadata = coalesce(fe.metadata,'{}'::jsonb) || jsonb_build_object(
      'needs_classification', true,
      'classification_reason', 'sheet_category_unmapped',
      'classification_requested_at', now()
    ),
    updated_at = now()
from public.categories c
where fe.category_id = c.id
  and fe.space_id = c.space_id
  and c.name = 'A classificar'
  and fe.source = 'sheet-sync'
  and fe.status = 'confirmed'
  and coalesce((fe.metadata->>'sheet_linked')::boolean, false)
  and fe.event_type in (
    'income','benefit_credit','reimbursement',
    'expense','card_purchase','benefit_expense','refund','debt_payment'
  )
  and not coalesce((fe.metadata->>'needs_classification')::boolean, false);
