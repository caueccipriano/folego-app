-- Datas de recebimento e valores informados, sem criar movimentação financeira.
-- Somente valores inseridos explicitamente pelo usuário aparecem como confirmados.
-- Esta tabela NÃO alimenta saldos, projeções nem a liquidação de recorrências.
create table if not exists public.income_receipt_confirmations (
  space_id uuid not null references public.financial_spaces(id) on delete cascade,
  recurring_item_id uuid not null references public.recurring_items(id) on delete cascade,
  due_date date not null,
  amount numeric(14,2) not null check (amount > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (space_id, recurring_item_id, due_date)
);

alter table public.income_receipt_confirmations enable row level security;
revoke all on table public.income_receipt_confirmations from public, anon;
grant select, insert, update, delete on table public.income_receipt_confirmations to authenticated;

create policy income_receipts_select_member on public.income_receipt_confirmations
  for select to authenticated
  using ((select private.is_space_member(space_id)));

create policy income_receipts_insert_writer on public.income_receipt_confirmations
  for insert to authenticated
  with check (
    (select private.can_write_space(space_id)) and
    exists (
      select 1 from public.recurring_items r
      where r.id = recurring_item_id
        and r.space_id = income_receipt_confirmations.space_id
        and r.item_type = 'income'
    )
  );

create policy income_receipts_update_writer on public.income_receipt_confirmations
  for update to authenticated
  using ((select private.can_write_space(space_id)))
  with check (
    (select private.can_write_space(space_id)) and
    exists (
      select 1 from public.recurring_items r
      where r.id = recurring_item_id
        and r.space_id = income_receipt_confirmations.space_id
        and r.item_type = 'income'
    )
  );

create policy income_receipts_delete_writer on public.income_receipt_confirmations
  for delete to authenticated
  using ((select private.can_write_space(space_id)));

comment on table public.income_receipt_confirmations is
  'Metadados para conhecimento do valor de um recebimento futuro; nunca atualiza o saldo ou cria lançamentos.';
