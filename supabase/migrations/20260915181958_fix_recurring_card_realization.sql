alter table public.recurring_items
  drop constraint if exists recurring_items_destination_chk;

alter table public.recurring_items
  add constraint recurring_items_destination_chk
  check (
    (item_type = 'income' and account_id is not null and card_id is null)
    or
    (
      item_type = 'expense'
      and (
        (account_id is not null and card_id is null)
        or (account_id is null and card_id is not null)
      )
    )
  );

create or replace function private.realize_recurring(
  p_space_id uuid,
  p_item_id uuid,
  p_due_date date,
  p_amount numeric default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  r public.recurring_items;
  eid uuid;
  v_purchase_id uuid;
  amount numeric;
  v_timezone text;
  v_purchase_at timestamptz;
begin
  if auth.uid() is null or not private.can_write_space(p_space_id) then
    raise exception 'write_access_denied';
  end if;

  select * into r
  from public.recurring_items
  where id = p_item_id
    and space_id = p_space_id
    and active
  for update;

  if r.id is null then
    raise exception 'invalid_recurring_item';
  end if;

  if not exists (
    select 1
    from public.get_upcoming_events(p_space_id, p_due_date, p_due_date) u
    where u.id = r.id
      and u.source = 'recurring'
      and u.due_date = p_due_date
  ) then
    select event_id into eid
    from public.recurring_occurrences
    where recurring_item_id = r.id
      and due_date = p_due_date
      and status = 'realized';

    if eid is not null then
      return eid;
    end if;

    raise exception 'invalid_occurrence';
  end if;

  amount := round(coalesce(p_amount, r.amount), 2);
  if amount <= 0 then
    raise exception 'amount_must_be_positive';
  end if;

  if r.item_type = 'income' then
    if r.account_id is null or r.card_id is not null then
      raise exception 'invalid_recurring_destination';
    end if;

    eid := public.register_income(
      p_space_id,
      r.account_id,
      amount,
      r.name,
      r.category_id,
      now(),
      null,
      'app'
    );
  elsif r.item_type = 'expense' and r.card_id is not null then
    if r.account_id is not null then
      raise exception 'invalid_recurring_destination';
    end if;

    select fs.timezone into v_timezone
    from public.financial_spaces fs
    where fs.id = p_space_id;

    v_purchase_at := p_due_date::timestamp
      at time zone coalesce(v_timezone, 'America/Sao_Paulo');

    v_purchase_id := public.register_card_purchase(
      p_space_id,
      r.card_id,
      amount,
      r.name,
      1,
      r.category_id,
      v_purchase_at,
      null,
      'app',
      null
    );

    select cp.event_id into eid
    from public.card_purchases cp
    where cp.id = v_purchase_id
      and cp.space_id = p_space_id;

    if eid is null then
      raise exception 'recurring_card_event_missing';
    end if;
  elsif r.item_type = 'expense' and r.account_id is not null then
    eid := public.register_expense(
      p_space_id,
      r.account_id,
      amount,
      r.name,
      r.category_id,
      now(),
      null,
      'app'
    );
  else
    raise exception 'invalid_recurring_destination';
  end if;

  update public.financial_events
  set necessity_class = r.necessity_class,
      behavior_class = r.behavior_class,
      frequency_class = 'recurring',
      updated_at = now()
  where id = eid
    and space_id = p_space_id;

  insert into public.financial_event_tags(space_id, event_id, tag_id)
  select p_space_id, eid, rit.tag_id
  from public.recurring_item_tags rit
  where rit.space_id = p_space_id
    and rit.recurring_item_id = r.id
  on conflict do nothing;

  insert into public.recurring_occurrences(
    space_id,
    recurring_item_id,
    due_date,
    expected_amount,
    actual_amount,
    event_id,
    status,
    realized_at
  )
  values(
    p_space_id,
    r.id,
    p_due_date,
    r.amount,
    amount,
    eid,
    'realized',
    now()
  )
  on conflict(recurring_item_id, due_date) do update
  set actual_amount = excluded.actual_amount,
      event_id = excluded.event_id,
      status = 'realized',
      realized_at = now();

  return eid;
end;
$function$;
