create or replace function private.baseline_web_push_on_alert_reenabled()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if
    (new.invoices_enabled and not old.invoices_enabled) or
    (new.debts_enabled and not old.debts_enabled) or
    (new.recurrences_enabled and not old.recurrences_enabled) or
    (new.subscriptions_enabled and not old.subscriptions_enabled) or
    (new.expected_income_enabled and not old.expected_income_enabled) or
    (new.overdue_enabled and not old.overdue_enabled) or
    (new.plan_thresholds_enabled and not old.plan_thresholds_enabled) or
    (new.card_limit_thresholds_enabled and not old.card_limit_thresholds_enabled) or
    (new.large_expenses_enabled and not old.large_expenses_enabled)
  then
    perform private.baseline_web_push_state(new.user_id, new.space_id);
  end if;
  return new;
end;
$$;

revoke all on function private.baseline_web_push_on_alert_reenabled() from public, anon, authenticated;

drop trigger if exists notification_preferences_alert_reenable_baseline on public.notification_preferences;
create trigger notification_preferences_alert_reenable_baseline
after update of
  invoices_enabled,
  debts_enabled,
  recurrences_enabled,
  subscriptions_enabled,
  expected_income_enabled,
  overdue_enabled,
  plan_thresholds_enabled,
  card_limit_thresholds_enabled,
  large_expenses_enabled
on public.notification_preferences
for each row execute function private.baseline_web_push_on_alert_reenabled();