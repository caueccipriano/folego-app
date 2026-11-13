-- Calendário de entradas: datas recorrentes sem valores presumidos.
-- Não cria eventos financeiros e não altera saldos nem cálculos existentes.
create table if not exists public.income_date_schedules (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.financial_spaces(id) on delete cascade,
  label text not null check (length(btrim(label)) between 1 and 120),
  day_of_month integer,
  last_day_of_month boolean not null default false,
  starts_on date not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint income_date_schedules_one_rule_check check (
    (day_of_month between 1 and 31 and last_day_of_month = false)
    or (day_of_month is null and last_day_of_month = true)
  ),
  constraint income_date_schedules_id_space_unique unique (id, space_id)
);

create index if not exists income_date_schedules_space_idx
on public.income_date_schedules (space_id, active);

create table if not exists public.income_date_amounts (
  space_id uuid not null references public.financial_spaces(id) on delete cascade,
  schedule_id uuid not null,
  due_date date not null,
  confirmed_amount numeric(14,2) not null check (confirmed_amount > 0),
  confirmed_at timestamptz not null default now(),
  confirmed_by uuid not null default auth.uid() references auth.users(id),
  primary key (space_id, schedule_id, due_date),
  constraint income_date_amounts_schedule_space_fk
    foreign key (schedule_id, space_id)
    references public.income_date_schedules(id, space_id)
    on delete cascade
);

create index if not exists income_date_amounts_space_date_idx
on public.income_date_amounts (space_id, due_date);

alter table public.income_date_schedules enable row level security;
alter table public.income_date_amounts enable row level security;

revoke all on public.income_date_schedules from anon, authenticated;
revoke all on public.income_date_amounts from anon, authenticated;
grant select, insert, update, delete on public.income_date_schedules to authenticated;
grant select, insert, update, delete on public.income_date_amounts to authenticated;
grant all on public.income_date_schedules to service_role;
grant all on public.income_date_amounts to service_role;

drop policy if exists income_date_schedules_read on public.income_date_schedules;
create policy income_date_schedules_read
  on public.income_date_schedules for select to authenticated
  using ((select private.is_space_member(space_id)));
drop policy if exists income_date_schedules_write on public.income_date_schedules;
create policy income_date_schedules_write
  on public.income_date_schedules for insert to authenticated
  with check ((select private.can_write_space(space_id)));
drop policy if exists income_date_schedules_edit on public.income_date_schedules;
create policy income_date_schedules_edit
  on public.income_date_schedules for update to authenticated
  using ((select private.can_write_space(space_id)))
  with check ((select private.can_write_space(space_id)));
drop policy if exists income_date_schedules_remove on public.income_date_schedules;
create policy income_date_schedules_remove
  on public.income_date_schedules for delete to authenticated
  using ((select private.can_write_space(space_id)));

drop policy if exists income_date_amounts_read on public.income_date_amounts;
create policy income_date_amounts_read
  on public.income_date_amounts for select to authenticated
  using ((select private.is_space_member(space_id)));
drop policy if exists income_date_amounts_write on public.income_date_amounts;
create policy income_date_amounts_write
  on public.income_date_amounts for insert to authenticated
  with check (
    (select private.can_write_space(space_id))
    and confirmed_by = (select auth.uid())
  );
drop policy if exists income_date_amounts_edit on public.income_date_amounts;
create policy income_date_amounts_edit
  on public.income_date_amounts for update to authenticated
  using ((select private.can_write_space(space_id)))
  with check (
    (select private.can_write_space(space_id))
    and confirmed_by = (select auth.uid())
  );
drop policy if exists income_date_amounts_remove on public.income_date_amounts;
create policy income_date_amounts_remove
  on public.income_date_amounts for delete to authenticated
  using ((select private.can_write_space(space_id)));

comment on table public.income_date_schedules is
  'Datas de receitas cadastradas pelo usuário sem estimar valor ou registrar dinheiro em conta.';
comment on table public.income_date_amounts is
  'Valores futuros anotados pelo usuário; não são recebimentos efetivos e não afetam o livro-caixa.';
