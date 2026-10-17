create index if not exists budget_recurring_rules_category_space_fk_idx
  on public.budget_recurring_rules (category_id, space_id);

create index if not exists category_suggestion_rules_category_space_fk_idx
  on public.category_suggestion_rules (category_id, space_id);

create index if not exists financial_event_tags_event_space_fk_idx
  on public.financial_event_tags (event_id, space_id);

create index if not exists financial_event_tags_tag_space_fk_idx
  on public.financial_event_tags (tag_id, space_id);

create index if not exists recurring_item_tags_recurring_space_fk_idx
  on public.recurring_item_tags (recurring_item_id, space_id);

create index if not exists recurring_item_tags_tag_space_fk_idx
  on public.recurring_item_tags (tag_id, space_id);

create index if not exists transaction_reflections_event_space_fk_idx
  on public.transaction_reflections (event_id, space_id);
