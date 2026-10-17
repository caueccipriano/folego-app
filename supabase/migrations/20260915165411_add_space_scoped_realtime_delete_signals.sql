create policy "folego_space_delete_broadcast_read"
on realtime.messages
for select
to authenticated
using (
  realtime.messages.extension = 'broadcast'
  and exists (
    select 1
    from public.financial_spaces fs
    where (select realtime.topic()) = 'space:' || fs.id::text || ':changes'
      and private.is_space_member(fs.id)
  )
);

create or replace function private.broadcast_folego_delete_invalidation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform realtime.send(
    jsonb_build_object('table', tg_table_name),
    'row_deleted',
    'space:' || old.space_id::text || ':changes',
    true
  );
  return old;
end;
$$;

revoke all on function private.broadcast_folego_delete_invalidation() from public;

DO $do$
declare
  table_name text;
begin
  foreach table_name in array array[
    'accounts',
    'budget_items',
    'budget_recurring_rules',
    'budgets',
    'card_installments',
    'card_invoices',
    'card_payments',
    'card_purchases',
    'credit_cards',
    'debt_installments',
    'debts',
    'financial_events',
    'financial_impacts',
    'goal_contributions',
    'recurring_items',
    'recurring_occurrences',
    'savings_goals',
    'transaction_reflections'
  ]
  loop
    execute format(
      'create trigger %I after delete on public.%I for each row execute function private.broadcast_folego_delete_invalidation()',
      'folego_realtime_delete_' || table_name,
      table_name
    );
  end loop;
end
$do$;
