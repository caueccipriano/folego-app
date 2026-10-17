revoke all on table public.transaction_reflections from anon;
grant select, insert, update, delete on table public.transaction_reflections to authenticated;

alter table public.transaction_reflections enable row level security;

drop policy if exists transaction_reflections_select_member on public.transaction_reflections;
drop policy if exists transaction_reflections_insert_writer on public.transaction_reflections;
drop policy if exists transaction_reflections_update_writer on public.transaction_reflections;
drop policy if exists transaction_reflections_delete_writer on public.transaction_reflections;

create policy transaction_reflections_select_member
on public.transaction_reflections
for select
to authenticated
using ((select private.is_space_member(transaction_reflections.space_id)));

create policy transaction_reflections_insert_writer
on public.transaction_reflections
for insert
to authenticated
with check (
  (select private.can_write_space(transaction_reflections.space_id))
  and exists (
    select 1
    from public.financial_events e
    where e.id = transaction_reflections.event_id
      and e.space_id = transaction_reflections.space_id
      and e.status = 'confirmed'
      and e.event_type in ('expense','card_purchase','benefit_expense')
  )
);

create policy transaction_reflections_update_writer
on public.transaction_reflections
for update
to authenticated
using ((select private.can_write_space(transaction_reflections.space_id)))
with check (
  (select private.can_write_space(transaction_reflections.space_id))
  and exists (
    select 1
    from public.financial_events e
    where e.id = transaction_reflections.event_id
      and e.space_id = transaction_reflections.space_id
      and e.status = 'confirmed'
      and e.event_type in ('expense','card_purchase','benefit_expense')
  )
);

create policy transaction_reflections_delete_writer
on public.transaction_reflections
for delete
to authenticated
using ((select private.can_write_space(transaction_reflections.space_id)));
