alter table public.recurring_occurrences
  drop constraint recurring_occurrences_item_fk;

alter table public.recurring_item_tags
  drop constraint recurring_item_tags_recurring_item_id_space_id_fkey;

drop index public.recurring_items_id_space_uidx;

alter table public.recurring_occurrences
  add constraint recurring_occurrences_item_fk
  foreign key (recurring_item_id, space_id)
  references public.recurring_items(id, space_id)
  on delete cascade;

alter table public.recurring_item_tags
  add constraint recurring_item_tags_recurring_item_id_space_id_fkey
  foreign key (recurring_item_id, space_id)
  references public.recurring_items(id, space_id)
  on delete cascade;
