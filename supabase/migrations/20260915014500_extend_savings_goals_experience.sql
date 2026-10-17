alter table public.savings_goals
  add column target_date date,
  add column icon_key text not null default 'piggy-bank',
  add column status text not null default 'active',
  add column updated_at timestamptz not null default now(),
  add column completed_at timestamptz;

alter table public.savings_goals
  add constraint savings_goals_icon_key_check
    check (icon_key in ('plane','device-laptop','car','home','gift','piggy-bank')),
  add constraint savings_goals_status_check
    check (status in ('active','completed','archived')),
  add constraint savings_goals_id_space_key unique (id, space_id);

alter table public.goal_contributions
  add column contributed_at timestamptz not null default now(),
  add column updated_at timestamptz not null default now();

alter table public.goal_contributions
  add constraint goal_contributions_note_length_check
    check (note is null or char_length(note) <= 300);

alter table public.goal_contributions
  drop constraint goal_contributions_goal_id_fkey;

alter table public.goal_contributions
  add constraint goal_contributions_goal_space_fkey
    foreign key (goal_id, space_id)
    references public.savings_goals(id, space_id)
    on delete restrict;

create index savings_goals_space_status_idx
  on public.savings_goals(space_id, status, created_at desc);

create index goal_contributions_goal_date_idx
  on public.goal_contributions(goal_id, contributed_at desc, created_at desc);

create trigger savings_goals_set_updated_at
before update on public.savings_goals
for each row execute function private.set_updated_at();

create trigger goal_contributions_set_updated_at
before update on public.goal_contributions
for each row execute function private.set_updated_at();

create or replace function private.sync_savings_goal_status(
  p_goal_id uuid,
  p_space_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_target numeric;
  v_status text;
  v_completed_at timestamptz;
  v_total numeric;
begin
  select g.target, g.status, g.completed_at
    into v_target, v_status, v_completed_at
  from public.savings_goals g
  where g.id = p_goal_id
    and g.space_id = p_space_id;

  if not found or v_status = 'archived' then
    return;
  end if;

  select coalesce(sum(c.amount), 0)
    into v_total
  from public.goal_contributions c
  where c.goal_id = p_goal_id
    and c.space_id = p_space_id;

  update public.savings_goals
  set status = case when v_total >= v_target then 'completed' else 'active' end,
      completed_at = case
        when v_total >= v_target then coalesce(v_completed_at, now())
        else null
      end
  where id = p_goal_id
    and space_id = p_space_id;
end;
$$;

create or replace function private.sync_goal_after_contribution()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.sync_savings_goal_status(
    coalesce(new.goal_id, old.goal_id),
    coalesce(new.space_id, old.space_id)
  );
  return coalesce(new, old);
end;
$$;

create trigger goal_contributions_sync_goal
  after insert or update or delete on public.goal_contributions
  for each row execute function private.sync_goal_after_contribution();

create or replace function private.sync_goal_after_target_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.sync_savings_goal_status(new.id, new.space_id);
  return new;
end;
$$;

create trigger savings_goals_sync_after_target_change
  after update of target on public.savings_goals
  for each row execute function private.sync_goal_after_target_change();
