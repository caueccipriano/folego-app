do $$
declare
  target_table text;
begin
  foreach target_table in array array[
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
    if not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = target_table
    ) then
      execute format(
        'alter publication supabase_realtime add table public.%I',
        target_table
      );
    end if;
  end loop;
end
$$;
