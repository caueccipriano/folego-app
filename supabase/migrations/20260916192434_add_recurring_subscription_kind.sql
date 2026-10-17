alter table public.recurring_items
  add column if not exists recurrence_kind text;

alter table public.recurring_items
  drop constraint if exists recurring_items_recurrence_kind_check;

alter table public.recurring_items
  add constraint recurring_items_recurrence_kind_check
  check (
    recurrence_kind is null
    or recurrence_kind in ('subscription', 'income', 'expense', 'transfer', 'reserve', 'other')
  );

create index if not exists recurring_items_space_recurrence_kind_active_idx
  on public.recurring_items (space_id, recurrence_kind, active);

comment on column public.recurring_items.recurrence_kind is
  'Optional user classification for recurring items. Null preserves legacy/ordinary recurrence; subscription powers the specialized subscriptions view without duplicating data.';
