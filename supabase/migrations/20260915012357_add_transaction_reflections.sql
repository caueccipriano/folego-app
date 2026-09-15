create table public.transaction_reflections (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null,
  event_id uuid not null,
  reflection_type text not null,
  note text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint transaction_reflections_space_fkey
    foreign key (space_id) references public.financial_spaces(id) on delete cascade,
  constraint transaction_reflections_event_space_fkey
    foreign key (event_id, space_id) references public.financial_events(id, space_id) on delete cascade,
  constraint transaction_reflections_event_unique unique (space_id, event_id),
  constraint transaction_reflections_type_check
    check (reflection_type in ('necessary','want','self_investment')),
  constraint transaction_reflections_note_length_check
    check (note is null or char_length(note) <= 300)
);

create index transaction_reflections_space_updated_idx
  on public.transaction_reflections(space_id, updated_at desc);

create trigger transaction_reflections_set_updated_at
before update on public.transaction_reflections
for each row execute function private.set_updated_at();

alter table public.transaction_reflections enable row level security;

create policy transaction_reflections_select_member
on public.transaction_reflections
for select
to authenticated
using ((select private.is_space_member(space_id)));

create policy transaction_reflections_insert_writer
on public.transaction_reflections
for insert
to authenticated
with check (
  (select private.can_write_space(space_id))
  and exists (
    select 1
    from public.financial_events e
    where e.id = event_id
      and e.space_id = space_id
      and e.status = 'confirmed'
      and e.event_type in ('expense','card_purchase','benefit_expense')
  )
);

create policy transaction_reflections_update_writer
on public.transaction_reflections
for update
to authenticated
using ((select private.can_write_space(space_id)))
with check (
  (select private.can_write_space(space_id))
  and exists (
    select 1
    from public.financial_events e
    where e.id = event_id
      and e.space_id = space_id
      and e.status = 'confirmed'
      and e.event_type in ('expense','card_purchase','benefit_expense')
  )
);

create policy transaction_reflections_delete_writer
on public.transaction_reflections
for delete
to authenticated
using ((select private.can_write_space(space_id)));

grant select, insert, update, delete on public.transaction_reflections to authenticated;
