-- Applied to Supabase Dev as 20260916233716_financial_notification_foundation.
-- Establishes user+space notification preferences and the deterministic
-- transaction automation foundation without billing, bank sync or ledger writes.

create table public.notification_preferences (
  user_id uuid not null references auth.users(id) on delete cascade,
  space_id uuid not null references public.financial_spaces(id) on delete cascade,
  financial_reminders_enabled boolean not null default false,
  invoices_enabled boolean not null default true,
  debts_enabled boolean not null default true,
  recurrences_enabled boolean not null default true,
  subscriptions_enabled boolean not null default true,
  expected_income_enabled boolean not null default true,
  overdue_enabled boolean not null default true,
  reminder_offset_days smallint not null default 1 check (reminder_offset_days in (0,1,3)),
  preferred_time time not null default time '09:00',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, space_id)
);

alter table public.notification_preferences enable row level security;
revoke all on table public.notification_preferences from public, anon;
grant select, insert, update, delete on table public.notification_preferences to authenticated;

create policy notification_preferences_select_own_space on public.notification_preferences
for select to authenticated
using (
  user_id = (select auth.uid())
  and (select private.is_space_member(notification_preferences.space_id))
);
create policy notification_preferences_insert_own_space on public.notification_preferences
for insert to authenticated
with check (
  user_id = (select auth.uid())
  and (select private.is_space_member(notification_preferences.space_id))
);
create policy notification_preferences_update_own_space on public.notification_preferences
for update to authenticated
using (
  user_id = (select auth.uid())
  and (select private.is_space_member(notification_preferences.space_id))
)
with check (
  user_id = (select auth.uid())
  and (select private.is_space_member(notification_preferences.space_id))
);
create policy notification_preferences_delete_own_space on public.notification_preferences
for delete to authenticated
using (
  user_id = (select auth.uid())
  and (select private.is_space_member(notification_preferences.space_id))
);

create table public.automation_rules (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.financial_spaces(id) on delete cascade,
  name text not null check (length(btrim(name)) between 1 and 120),
  active boolean not null default true,
  trigger_type text not null default 'statement_candidate' check (trigger_type = 'statement_candidate'),
  match_field text not null check (match_field in ('description','merchant')),
  match_type text not null check (match_type in ('equals','contains')),
  match_value text not null check (length(btrim(match_value)) between 1 and 160),
  source_scope_type text not null default 'any' check (source_scope_type in ('any','account','card','benefit')),
  source_account_id uuid,
  source_card_id uuid,
  source_benefit_id uuid,
  direction text check (direction is null or direction in ('debit','credit')),
  category_id uuid,
  classification_value text check (
    classification_value is null
    or classification_value in ('expense','income','card_purchase','benefit_expense','benefit_credit')
  ),
  action_type text not null check (
    action_type in ('suggest_category','review_category','suggest_classification','mark_recognized')
  ),
  execution_mode text not null default 'suggest' check (execution_mode in ('suggest','review','automatic')),
  priority integer not null default 0 check (priority between -1000 and 1000),
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, space_id),
  constraint automation_rules_source_scope_chk check (
    (source_scope_type = 'any' and source_account_id is null and source_card_id is null and source_benefit_id is null)
    or (source_scope_type = 'account' and source_account_id is not null and source_card_id is null and source_benefit_id is null)
    or (source_scope_type = 'card' and source_account_id is null and source_card_id is not null and source_benefit_id is null)
    or (source_scope_type = 'benefit' and source_account_id is null and source_card_id is null and source_benefit_id is not null)
  ),
  constraint automation_rules_action_value_chk check (
    (action_type in ('suggest_category','review_category') and category_id is not null and classification_value is null)
    or (action_type = 'suggest_classification' and category_id is null and classification_value is not null)
    or (action_type = 'mark_recognized' and category_id is null and classification_value is null)
  ),
  constraint automation_rules_source_account_fk foreign key (source_account_id, space_id)
    references public.accounts(id, space_id) on delete restrict,
  constraint automation_rules_source_card_fk foreign key (source_card_id, space_id)
    references public.credit_cards(id, space_id) on delete restrict,
  constraint automation_rules_source_benefit_fk foreign key (source_benefit_id, space_id)
    references public.accounts(id, space_id) on delete restrict,
  constraint automation_rules_category_fk foreign key (category_id, space_id)
    references public.categories(id, space_id) on delete restrict
);

create index automation_rules_space_active_idx
  on public.automation_rules(space_id, active, priority desc);
create index automation_rules_category_id_idx
  on public.automation_rules(category_id) where category_id is not null;
create index automation_rules_source_account_id_idx
  on public.automation_rules(source_account_id) where source_account_id is not null;
create index automation_rules_source_card_id_idx
  on public.automation_rules(source_card_id) where source_card_id is not null;
create index automation_rules_source_benefit_id_idx
  on public.automation_rules(source_benefit_id) where source_benefit_id is not null;

alter table public.automation_rules enable row level security;
revoke all on table public.automation_rules from public, anon;
grant select, insert, update, delete on table public.automation_rules to authenticated;

create policy automation_rules_select_member on public.automation_rules
for select to authenticated
using ((select private.is_space_member(automation_rules.space_id)));
create policy automation_rules_insert_writer on public.automation_rules
for insert to authenticated
with check (
  (select private.can_write_space(automation_rules.space_id))
  and created_by = (select auth.uid())
);
create policy automation_rules_update_writer on public.automation_rules
for update to authenticated
using ((select private.can_write_space(automation_rules.space_id)))
with check ((select private.can_write_space(automation_rules.space_id)));
create policy automation_rules_delete_writer on public.automation_rules
for delete to authenticated
using ((select private.can_write_space(automation_rules.space_id)));

create table public.automation_rule_runs (
  id uuid primary key default gen_random_uuid(),
  rule_id uuid not null,
  space_id uuid not null references public.financial_spaces(id) on delete cascade,
  target_type text not null check (target_type in ('import_row','synced_candidate')),
  target_id uuid not null,
  action text not null,
  result text not null check (result in ('suggested','prepared_review','recognized','skipped')),
  created_at timestamptz not null default now(),
  constraint automation_rule_runs_rule_fk foreign key (rule_id, space_id)
    references public.automation_rules(id, space_id) on delete cascade
);

create index automation_rule_runs_rule_created_idx
  on public.automation_rule_runs(rule_id, created_at desc);
create index automation_rule_runs_space_created_idx
  on public.automation_rule_runs(space_id, created_at desc);
create index automation_rule_runs_target_idx
  on public.automation_rule_runs(target_type, target_id);

alter table public.automation_rule_runs enable row level security;
revoke all on table public.automation_rule_runs from public, anon;
grant select on table public.automation_rule_runs to authenticated;
create policy automation_rule_runs_select_member on public.automation_rule_runs
for select to authenticated
using ((select private.is_space_member(automation_rule_runs.space_id)));

alter table public.import_rows
  add column automation_rule_id uuid,
  add column automation_suggested_category_id uuid,
  add column automation_suggested_final_type text,
  add column automation_recognized boolean not null default false,
  add constraint import_rows_automation_final_type_chk check (
    automation_suggested_final_type is null
    or automation_suggested_final_type in ('expense','income','card_purchase','benefit_expense','benefit_credit')
  ),
  add constraint import_rows_automation_rule_fk foreign key (automation_rule_id, space_id)
    references public.automation_rules(id, space_id) on delete set null,
  add constraint import_rows_automation_category_fk foreign key (automation_suggested_category_id, space_id)
    references public.categories(id, space_id) on delete set null;

create or replace function private.normalize_automation_text(value text)
returns text
language sql
immutable
set search_path = ''
as $function$
  select regexp_replace(
    translate(
      lower(btrim(coalesce(value, ''))),
      'áàâãäéèêëíìîïóòôõöúùûüçñ',
      'aaaaaeeeeiiiiooooouuuucn'
    ),
    '\s+',
    ' ',
    'g'
  );
$function$;

create or replace function public.apply_automation_rules_to_import_batch(
  p_space_id uuid,
  p_batch_id uuid
)
returns integer
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_batch public.import_batches%rowtype;
  v_row record;
  v_rule public.automation_rules%rowtype;
  v_applied integer := 0;
  v_result text;
begin
  if v_user_id is null or not private.can_write_space(p_space_id) then
    raise exception 'write_access_denied' using errcode = '42501';
  end if;

  select * into v_batch
  from public.import_batches b
  where b.id = p_batch_id
    and b.space_id = p_space_id;
  if not found then raise exception 'import_batch_not_found'; end if;

  for v_row in
    select r.id, r.description, r.merchant, r.direction, r.final_type
    from public.import_rows r
    where r.space_id = p_space_id
      and r.batch_id = p_batch_id
      and r.status = 'staged'
      and r.duplicate_state not in ('exact_duplicate','already_imported')
      and r.automation_rule_id is null
    order by r.row_number, r.id
  loop
    select ar.* into v_rule
    from public.automation_rules ar
    where ar.space_id = p_space_id
      and ar.active
      and ar.trigger_type = 'statement_candidate'
      and ar.execution_mode in ('suggest','review')
      and (ar.direction is null or ar.direction = v_row.direction)
      and (
        ar.category_id is null
        or exists (
          select 1 from public.categories c
          where c.id = ar.category_id and c.space_id = ar.space_id
            and c.active and c.is_selectable and c.category_role = 'economic'
        )
      )
      and (
        ar.source_scope_type = 'any'
        or (
          ar.source_scope_type = 'account'
          and v_batch.source_kind = 'account'
          and ar.source_account_id = v_batch.source_account_id
          and exists (
            select 1 from public.accounts a
            where a.id = ar.source_account_id and a.space_id = ar.space_id
              and a.active and a.type <> 'benefit'
          )
        )
        or (
          ar.source_scope_type = 'card'
          and v_batch.source_kind = 'card'
          and ar.source_card_id = v_batch.source_card_id
          and exists (
            select 1 from public.credit_cards c
            where c.id = ar.source_card_id and c.space_id = ar.space_id and c.active
          )
        )
        or (
          ar.source_scope_type = 'benefit'
          and v_batch.source_kind = 'benefit'
          and ar.source_benefit_id = v_batch.source_account_id
          and exists (
            select 1 from public.accounts a
            where a.id = ar.source_benefit_id and a.space_id = ar.space_id
              and a.active and a.type = 'benefit'
          )
        )
      )
      and (
        case ar.match_field
          when 'description' then case ar.match_type
            when 'equals' then private.normalize_automation_text(v_row.description) = private.normalize_automation_text(ar.match_value)
            else position(private.normalize_automation_text(ar.match_value) in private.normalize_automation_text(v_row.description)) > 0
          end
          when 'merchant' then case ar.match_type
            when 'equals' then private.normalize_automation_text(v_row.merchant) = private.normalize_automation_text(ar.match_value)
            else position(private.normalize_automation_text(ar.match_value) in private.normalize_automation_text(v_row.merchant)) > 0
          end
          else false
        end
      )
    order by
      (ar.source_scope_type <> 'any') desc,
      (ar.match_type = 'equals') desc,
      ar.priority desc,
      ar.created_at asc,
      ar.id asc
    limit 1;

    if not found then continue; end if;

    v_result := case
      when v_rule.action_type = 'mark_recognized' then 'recognized'
      when v_rule.execution_mode = 'review' then 'prepared_review'
      else 'suggested'
    end;

    update public.import_rows r
    set
      automation_rule_id = v_rule.id,
      automation_suggested_category_id = case
        when v_rule.action_type in ('suggest_category','review_category') then v_rule.category_id
        else null
      end,
      automation_suggested_final_type = case
        when v_rule.action_type = 'suggest_classification' then v_rule.classification_value
        else null
      end,
      automation_recognized = (v_rule.action_type = 'mark_recognized'),
      category_id = case
        when v_rule.execution_mode = 'review' and v_rule.action_type = 'review_category'
          then v_rule.category_id
        else r.category_id
      end,
      final_type = case
        when v_rule.execution_mode = 'review' and v_rule.action_type = 'suggest_classification'
          then v_rule.classification_value
        else r.final_type
      end,
      updated_at = now()
    where r.id = v_row.id and r.space_id = p_space_id;

    insert into public.automation_rule_runs(
      rule_id, space_id, target_type, target_id, action, result
    ) values (
      v_rule.id, p_space_id, 'import_row', v_row.id, v_rule.action_type, v_result
    );

    v_applied := v_applied + 1;
  end loop;

  return v_applied;
end;
$function$;

revoke all on function public.apply_automation_rules_to_import_batch(uuid,uuid) from public, anon;
grant execute on function public.apply_automation_rules_to_import_batch(uuid,uuid) to authenticated;

do $realtime$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'automation_rules'
  ) then
    alter publication supabase_realtime add table public.automation_rules;
  end if;
end
$realtime$;
