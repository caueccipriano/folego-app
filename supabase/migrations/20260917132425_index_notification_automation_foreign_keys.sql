-- Applied to Supabase Dev as 20260917132425_index_notification_automation_foreign_keys.
-- Covers only FK/index findings introduced by Notifications + Automation 1.0.

create index if not exists automation_rule_runs_rule_space_idx
  on public.automation_rule_runs(rule_id, space_id);

create index if not exists automation_rules_category_space_idx
  on public.automation_rules(category_id, space_id)
  where category_id is not null;

create index if not exists automation_rules_created_by_idx
  on public.automation_rules(created_by);

create index if not exists automation_rules_source_account_space_idx
  on public.automation_rules(source_account_id, space_id)
  where source_account_id is not null;

create index if not exists automation_rules_source_card_space_idx
  on public.automation_rules(source_card_id, space_id)
  where source_card_id is not null;

create index if not exists automation_rules_source_benefit_space_idx
  on public.automation_rules(source_benefit_id, space_id)
  where source_benefit_id is not null;

create index if not exists import_rows_automation_category_space_idx
  on public.import_rows(automation_suggested_category_id, space_id)
  where automation_suggested_category_id is not null;

create index if not exists import_rows_automation_rule_space_idx
  on public.import_rows(automation_rule_id, space_id)
  where automation_rule_id is not null;
