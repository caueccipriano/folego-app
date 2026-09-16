create index if not exists import_batches_user_idx on public.import_batches(user_id);
create index if not exists import_batches_source_account_idx on public.import_batches(source_account_id) where source_account_id is not null;
create index if not exists import_batches_source_card_idx on public.import_batches(source_card_id) where source_card_id is not null;
create index if not exists import_rows_category_idx on public.import_rows(category_id) where category_id is not null;
create index if not exists import_rows_counterpart_account_idx on public.import_rows(counterpart_account_id) where counterpart_account_id is not null;
create index if not exists import_rows_invoice_idx on public.import_rows(invoice_id) where invoice_id is not null;
create index if not exists import_rows_imported_event_idx on public.import_rows(imported_event_id) where imported_event_id is not null;

drop policy if exists import_batches_insert_writer on public.import_batches;
create policy import_batches_insert_writer on public.import_batches
for insert to authenticated
with check (
  (select private.can_write_space(import_batches.space_id))
  and user_id = (select auth.uid())
);
