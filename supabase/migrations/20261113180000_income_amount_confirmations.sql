-- Confirmações de valores para recebimentos futuros, sem previsão automática.
-- A tabela não modifica o livro-caixa, saldos ou projeções existentes.
create table if not exists public.income_amount_confirmations (
  space_id uuid not null references public.financial_spaces(id) on delete cascade,
  recurring_item_id uuid not null,
  due_date date not null,
  confirmed_amount numeric(14,2) not null check (confirmed_amount > 0),
  confirmed_at timestamptz not null default now(),
  confirmed_by uuid not null default auth.uid() references auth.users(id),
  primary key (space_id, recurring_item_id, due_date),
  constraint income_amount_confirmations_recurring_space_fk
    foreign key (recurring_item_id, space_id)
    references public.recurring_items(id, space_id)
    on delete cascade
);

create index if not exists income_amount_confirmations_space_due_idx
  on public.income_amount_confirmations(space_id, due_date);

alter table public.income_amount_confirmations enable row level security;

revoke all on public.income_amount_confirmations from anon, authenticated;
grant select, insert, update, delete on public.income_amount_confirmations to authenticated;
grant all on public.income_amount_confirmations to service_role;

drop policy if exists income_amount_confirmations_read_member
  on public.income_amount_confirmations;
create policy income_amount_confirmations_read_member
  on public.income_amount_confirmations for select to authenticated
  using ((select private.is_space_member(space_id)));

drop policy if exists income_amount_confirmations_insert_writer
  on public.income_amount_confirmations;
create policy income_amount_confirmations_insert_writer
  on public.income_amount_confirmations for insert to authenticated
  with check (
    (select private.can_write_space(space_id))
    and confirmed_by = (select auth.uid())
    and exists (
      select 1 from public.recurring_items r
      where r.id = income_amount_confirmations.recurring_item_id
        and r.space_id = income_amount_confirmations.space_id
        and r.item_type = 'income'
        and r.active
    )
  );

drop policy if exists income_amount_confirmations_update_writer
  on public.income_amount_confirmations;
create policy income_amount_confirmations_update_writer
  on public.income_amount_confirmations for update to authenticated
  using ((select private.can_write_space(space_id)))
  with check (
    (select private.can_write_space(space_id))
    and confirmed_by = (select auth.uid())
    and exists (
      select 1 from public.recurring_items r
      where r.id = income_amount_confirmations.recurring_item_id
        and r.space_id = income_amount_confirmations.space_id
        and r.item_type = 'income'
        and r.active
    )
  );

drop policy if exists income_amount_confirmations_delete_writer
  on public.income_amount_confirmations;
create policy income_amount_confirmations_delete_writer
  on public.income_amount_confirmations for delete to authenticated
  using ((select private.can_write_space(space_id)));

comment on table public.income_amount_confirmations is
  'Valor informado explicitamente para uma ocorrência futura de receita; não significa dinheiro recebido e nunca integra saldo disponível.';
