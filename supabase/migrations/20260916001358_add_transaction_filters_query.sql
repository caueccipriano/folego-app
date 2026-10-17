create or replace function public.list_transactions_filtered(
  p_space_id uuid,
  p_date_from date default null,
  p_date_to date default null,
  p_event_types text[] default null,
  p_category_id uuid default null,
  p_account_id uuid default null,
  p_card_id uuid default null,
  p_benefit_account_id uuid default null,
  p_search text default null,
  p_cursor_occurred_at timestamptz default null,
  p_cursor_id uuid default null,
  p_limit integer default 51
)
returns table(
  id uuid,
  event_type text,
  description text,
  amount numeric,
  occurred_at timestamptz,
  competence_date date,
  category_id uuid,
  status text,
  source text,
  category jsonb,
  financial_impacts jsonb
)
language plpgsql
stable
security invoker
set search_path = pg_catalog, public, private
as $$
declare
  v_search text := nullif(btrim(p_search), '');
  v_limit integer := least(greatest(coalesce(p_limit, 51), 1), 101);
begin
  if auth.uid() is null or not private.is_space_member(p_space_id) then
    raise exception using errcode = '42501', message = 'space_access_denied';
  end if;

  if (p_cursor_occurred_at is null) <> (p_cursor_id is null) then
    raise exception using errcode = '22023', message = 'invalid_transaction_cursor';
  end if;

  return query
  select
    e.id,
    e.event_type,
    e.description,
    e.amount,
    e.occurred_at,
    e.competence_date,
    e.category_id,
    e.status,
    e.source,
    case
      when c.id is null then null
      else jsonb_build_object(
        'id', c.id,
        'name', c.name,
        'color_hex', c.color_hex,
        'parent_id', c.parent_id
      )
    end as category,
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'dimension', fi.dimension,
            'account_id', fi.account_id,
            'account', case
              when a.id is null then null
              else jsonb_build_object('id', a.id, 'name', a.name)
            end
          )
          order by fi.created_at, fi.id
        )
        from public.financial_impacts fi
        left join public.accounts a
          on a.id = fi.account_id
         and a.space_id = fi.space_id
        where fi.space_id = e.space_id
          and fi.event_id = e.id
      ),
      '[]'::jsonb
    ) as financial_impacts
  from public.financial_events e
  join public.financial_spaces fs
    on fs.id = e.space_id
  left join public.categories c
    on c.id = e.category_id
   and c.space_id = e.space_id
  where e.space_id = p_space_id
    and e.status not in ('ignored', 'cancelled')
    and (
      p_date_from is null
      or e.occurred_at >= ((p_date_from::timestamp) at time zone fs.timezone)
    )
    and (
      p_date_to is null
      or e.occurred_at < (((p_date_to + 1)::timestamp) at time zone fs.timezone)
    )
    and (
      coalesce(cardinality(p_event_types), 0) = 0
      or e.event_type = any(p_event_types)
    )
    and (
      p_category_id is null
      or e.category_id = p_category_id
      or exists (
        select 1
        from public.categories selected_category
        where selected_category.id = e.category_id
          and selected_category.space_id = e.space_id
          and selected_category.parent_id = p_category_id
      )
    )
    and (
      p_account_id is null
      or exists (
        select 1
        from public.financial_impacts account_impact
        where account_impact.space_id = e.space_id
          and account_impact.event_id = e.id
          and account_impact.account_id = p_account_id
      )
    )
    and (
      p_card_id is null
      or exists (
        select 1
        from public.card_purchases cp
        where cp.space_id = e.space_id
          and cp.event_id = e.id
          and cp.card_id = p_card_id
      )
      or exists (
        select 1
        from public.card_payments payment
        join public.card_invoices invoice
          on invoice.id = payment.invoice_id
         and invoice.space_id = payment.space_id
        where payment.space_id = e.space_id
          and payment.event_id = e.id
          and invoice.card_id = p_card_id
      )
    )
    and (
      p_benefit_account_id is null
      or exists (
        select 1
        from public.financial_impacts benefit_impact
        join public.accounts benefit_account
          on benefit_account.id = benefit_impact.account_id
         and benefit_account.space_id = benefit_impact.space_id
        where benefit_impact.space_id = e.space_id
          and benefit_impact.event_id = e.id
          and benefit_impact.account_id = p_benefit_account_id
          and benefit_account.type = 'benefit'
      )
    )
    and (
      v_search is null
      or e.description ilike ('%' || v_search || '%')
      or exists (
        select 1
        from public.card_purchases search_purchase
        where search_purchase.space_id = e.space_id
          and search_purchase.event_id = e.id
          and search_purchase.merchant ilike ('%' || v_search || '%')
      )
    )
    and (
      p_cursor_occurred_at is null
      or e.occurred_at < p_cursor_occurred_at
      or (
        e.occurred_at = p_cursor_occurred_at
        and e.id < p_cursor_id
      )
    )
  order by e.occurred_at desc, e.id desc
  limit v_limit;
end;
$$;

revoke all on function public.list_transactions_filtered(
  uuid, date, date, text[], uuid, uuid, uuid, uuid, text, timestamptz, uuid, integer
) from public;

grant execute on function public.list_transactions_filtered(
  uuid, date, date, text[], uuid, uuid, uuid, uuid, text, timestamptz, uuid, integer
) to authenticated;
