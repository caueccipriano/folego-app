create table public.import_batches (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.financial_spaces(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  filename text not null check (char_length(filename) between 1 and 240),
  file_type text not null check (file_type in ('csv','ofx')),
  source_kind text not null check (source_kind in ('account','card','benefit')),
  source_account_id uuid references public.accounts(id) on delete restrict,
  source_card_id uuid references public.credit_cards(id) on delete restrict,
  source_institution text,
  file_fingerprint text,
  parser_version text not null default '1.0',
  configuration jsonb not null default '{}'::jsonb,
  status text not null default 'draft' check (status in ('draft','reviewing','importing','completed','partially_completed','failed','cancelled')),
  total_rows integer not null default 0 check (total_rows >= 0 and total_rows <= 2000),
  selected_rows integer not null default 0 check (selected_rows >= 0),
  imported_rows integer not null default 0 check (imported_rows >= 0),
  ignored_rows integer not null default 0 check (ignored_rows >= 0),
  duplicate_rows integer not null default 0 check (duplicate_rows >= 0),
  error_rows integer not null default 0 check (error_rows >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz,
  constraint import_batch_source_shape check (
    (source_kind in ('account','benefit') and source_account_id is not null and source_card_id is null)
    or (source_kind = 'card' and source_card_id is not null and source_account_id is null)
  )
);

create table public.import_rows (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references public.import_batches(id) on delete cascade,
  space_id uuid not null references public.financial_spaces(id) on delete cascade,
  row_number integer not null check (row_number > 0 and row_number <= 2000),
  external_id text,
  canonical_external_id text,
  occurred_at timestamptz,
  description text not null,
  merchant text,
  amount numeric(18,2) not null check (amount > 0),
  direction text not null check (direction in ('debit','credit')),
  original_fields jsonb not null default '{}'::jsonb,
  candidate_type text not null check (candidate_type in ('expense','income','card_purchase','benefit_expense','benefit_credit','transfer_candidate','card_payment_candidate','refund_candidate','unknown')),
  final_type text check (final_type is null or final_type in ('expense','income','card_purchase','benefit_expense','benefit_credit','transfer','card_payment')),
  category_id uuid references public.categories(id) on delete set null,
  counterpart_account_id uuid references public.accounts(id) on delete restrict,
  invoice_id uuid references public.card_invoices(id) on delete restrict,
  confidence numeric(4,3) check (confidence is null or (confidence >= 0 and confidence <= 1)),
  reason text,
  fingerprint text not null,
  duplicate_state text not null default 'unique' check (duplicate_state in ('unique','exact_duplicate','possible_duplicate','already_imported')),
  user_decision text not null default 'review' check (user_decision in ('include','ignore','review')),
  status text not null default 'staged' check (status in ('staged','imported','ignored','error')),
  imported_event_id uuid references public.financial_events(id) on delete set null,
  error_text text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (batch_id, row_number)
);

create index import_batches_space_created_idx on public.import_batches(space_id, created_at desc);
create index import_batches_fingerprint_idx on public.import_batches(space_id, file_fingerprint) where file_fingerprint is not null;
create index import_rows_batch_status_idx on public.import_rows(batch_id, status, user_decision);
create index import_rows_fingerprint_idx on public.import_rows(space_id, fingerprint, status);
create index import_rows_external_idx on public.import_rows(space_id, canonical_external_id) where canonical_external_id is not null;

alter table public.import_batches enable row level security;
alter table public.import_rows enable row level security;

create policy import_batches_select_member on public.import_batches
for select to authenticated
using ((select private.is_space_member(import_batches.space_id)));

create policy import_batches_insert_writer on public.import_batches
for insert to authenticated
with check ((select private.can_write_space(import_batches.space_id)) and user_id = auth.uid());

create policy import_batches_update_writer on public.import_batches
for update to authenticated
using ((select private.can_write_space(import_batches.space_id)))
with check ((select private.can_write_space(import_batches.space_id)));

create policy import_batches_delete_writer on public.import_batches
for delete to authenticated
using ((select private.can_write_space(import_batches.space_id)));

create policy import_rows_select_member on public.import_rows
for select to authenticated
using ((select private.is_space_member(import_rows.space_id)));

create policy import_rows_insert_writer on public.import_rows
for insert to authenticated
with check (
  (select private.can_write_space(import_rows.space_id))
  and exists (
    select 1 from public.import_batches b
    where b.id = import_rows.batch_id and b.space_id = import_rows.space_id
  )
);

create policy import_rows_update_writer on public.import_rows
for update to authenticated
using ((select private.can_write_space(import_rows.space_id)))
with check ((select private.can_write_space(import_rows.space_id)));

create policy import_rows_delete_writer on public.import_rows
for delete to authenticated
using ((select private.can_write_space(import_rows.space_id)));

create or replace function private.normalize_import_text(p_text text)
returns text
language sql
immutable
set search_path = ''
as $$
  select regexp_replace(lower(btrim(coalesce(p_text,''))), '\s+', ' ', 'g');
$$;

create or replace function private.import_external_key(
  p_space_id uuid,
  p_source_kind text,
  p_source_id uuid,
  p_institution text,
  p_external_id text
)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when nullif(btrim(p_external_id),'') is null then null
    else 'statement-import:' || md5(
      p_space_id::text || '|' || coalesce(p_source_kind,'') || '|' || coalesce(p_source_id::text,'') || '|' ||
      lower(btrim(coalesce(p_institution,''))) || '|' || btrim(p_external_id)
    )
  end;
$$;

create or replace function private.import_row_fingerprint(
  p_space_id uuid,
  p_source_kind text,
  p_source_id uuid,
  p_occurred_at timestamptz,
  p_amount numeric,
  p_description text
)
returns text
language sql
immutable
set search_path = ''
as $$
  select md5(
    p_space_id::text || '|' || coalesce(p_source_kind,'') || '|' || coalesce(p_source_id::text,'') || '|' ||
    to_char(p_occurred_at at time zone 'UTC','YYYY-MM-DD') || '|' || round(p_amount,2)::text || '|' ||
    private.normalize_import_text(p_description)
  );
$$;

create or replace function public.stage_transaction_import(
  p_space_id uuid,
  p_filename text,
  p_file_type text,
  p_source_kind text,
  p_source_account_id uuid,
  p_source_card_id uuid,
  p_source_institution text,
  p_file_fingerprint text,
  p_configuration jsonb,
  p_parser_version text,
  p_rows jsonb
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_batch_id uuid;
  v_user_id uuid := auth.uid();
  v_count integer;
  v_timezone text;
  v_source_id uuid;
  v_row jsonb;
  v_ord bigint;
  v_amount numeric;
  v_description text;
  v_merchant text;
  v_external_id text;
  v_occurred timestamptz;
  v_candidate text;
  v_final_type text;
  v_direction text;
  v_category_id uuid;
  v_external_key text;
  v_fingerprint text;
  v_duplicate text;
  v_decision text;
  v_possible boolean;
begin
  if v_user_id is null then raise exception 'authentication_required'; end if;
  if not private.can_write_space(p_space_id) then raise exception 'write_access_denied'; end if;
  if p_file_type not in ('csv','ofx') then raise exception 'unsupported_import_file_type'; end if;
  if p_source_kind not in ('account','card','benefit') then raise exception 'invalid_import_source'; end if;
  if nullif(btrim(p_filename),'') is null or char_length(p_filename) > 240 then raise exception 'invalid_import_filename'; end if;
  if jsonb_typeof(p_rows) <> 'array' then raise exception 'invalid_import_rows'; end if;
  v_count := jsonb_array_length(p_rows);
  if v_count = 0 then raise exception 'empty_import'; end if;
  if v_count > 2000 then raise exception 'import_row_limit_exceeded'; end if;
  if octet_length(p_rows::text) > 4194304 then raise exception 'import_payload_too_large'; end if;

  select coalesce(fs.timezone,'America/Sao_Paulo') into v_timezone
  from public.financial_spaces fs where fs.id=p_space_id;
  if v_timezone is null then raise exception 'invalid_space'; end if;

  if p_source_kind in ('account','benefit') then
    if p_source_account_id is null or p_source_card_id is not null then raise exception 'invalid_import_source'; end if;
    if not exists (
      select 1 from public.accounts a
      where a.id=p_source_account_id and a.space_id=p_space_id and a.active
        and ((p_source_kind='benefit' and a.type='benefit') or (p_source_kind='account' and a.type<>'benefit'))
    ) then raise exception 'invalid_import_source'; end if;
    v_source_id := p_source_account_id;
  else
    if p_source_card_id is null or p_source_account_id is not null then raise exception 'invalid_import_source'; end if;
    if not exists (select 1 from public.credit_cards c where c.id=p_source_card_id and c.space_id=p_space_id and c.active) then
      raise exception 'invalid_import_source';
    end if;
    v_source_id := p_source_card_id;
  end if;

  insert into public.import_batches(
    space_id,user_id,filename,file_type,source_kind,source_account_id,source_card_id,source_institution,
    file_fingerprint,parser_version,configuration,status,total_rows
  ) values (
    p_space_id,v_user_id,btrim(p_filename),p_file_type,p_source_kind,p_source_account_id,p_source_card_id,
    nullif(btrim(p_source_institution),''),nullif(btrim(p_file_fingerprint),''),coalesce(nullif(btrim(p_parser_version),''),'1.0'),
    coalesce(p_configuration,'{}'::jsonb),'reviewing',v_count
  ) returning id into v_batch_id;

  for v_row, v_ord in
    select value, ordinality from jsonb_array_elements(p_rows) with ordinality
  loop
    begin
      v_amount := round(abs((v_row->>'amount')::numeric),2);
      if v_amount <= 0 then raise exception 'invalid_amount'; end if;
      v_description := nullif(btrim(v_row->>'description'),'');
      if v_description is null then raise exception 'invalid_description'; end if;
      if char_length(v_description) > 500 then v_description := left(v_description,500); end if;
      v_merchant := nullif(btrim(v_row->>'merchant'),'');
      if v_merchant is not null and char_length(v_merchant)>240 then v_merchant:=left(v_merchant,240); end if;
      v_external_id := nullif(btrim(v_row->>'external_id'),'');
      if v_external_id is not null and char_length(v_external_id)>240 then v_external_id:=left(v_external_id,240); end if;
      v_direction := lower(coalesce(v_row->>'direction',''));
      if v_direction not in ('debit','credit') then raise exception 'invalid_direction'; end if;
      v_candidate := lower(coalesce(v_row->>'candidate_type','unknown'));
      if v_candidate not in ('expense','income','card_purchase','benefit_expense','benefit_credit','transfer_candidate','card_payment_candidate','refund_candidate','unknown') then
        v_candidate := 'unknown';
      end if;
      v_final_type := nullif(lower(btrim(v_row->>'final_type')),'');
      if v_final_type is not null and v_final_type not in ('expense','income','card_purchase','benefit_expense','benefit_credit','transfer','card_payment') then
        v_final_type := null;
      end if;
      v_category_id := nullif(v_row->>'category_id','')::uuid;

      if coalesce((v_row->>'date_only')::boolean,false) then
        v_occurred := (((v_row->>'local_date')::date + time '12:00') at time zone v_timezone);
      else
        v_occurred := (v_row->>'occurred_at')::timestamptz;
      end if;
      if v_occurred is null then raise exception 'invalid_date'; end if;

      v_external_key := private.import_external_key(p_space_id,p_source_kind,v_source_id,p_source_institution,v_external_id);
      v_fingerprint := private.import_row_fingerprint(p_space_id,p_source_kind,v_source_id,v_occurred,v_amount,v_description);
      v_duplicate := 'unique';

      if v_external_key is not null and exists (
        select 1 from public.financial_events e where e.space_id=p_space_id and e.external_id=v_external_key
      ) then
        v_duplicate := 'already_imported';
      elsif exists (
        select 1
        from public.import_rows ir
        join public.import_batches ib on ib.id=ir.batch_id
        where ir.space_id=p_space_id and ir.status='imported'
          and ib.source_kind=p_source_kind
          and coalesce(ib.source_account_id,ib.source_card_id)=v_source_id
          and (
            (v_external_key is not null and ir.canonical_external_id=v_external_key)
            or (v_external_key is null and ir.fingerprint=v_fingerprint)
          )
      ) then
        v_duplicate := case when v_external_key is not null then 'already_imported' else 'exact_duplicate' end;
      elsif exists (
        select 1 from public.import_rows ir
        where ir.batch_id=v_batch_id and ir.fingerprint=v_fingerprint
      ) then
        v_duplicate := 'exact_duplicate';
      else
        v_possible := false;
        if p_source_kind='card' then
          select exists (
            select 1 from public.card_purchases cp
            join public.financial_events e on e.id=cp.event_id and e.space_id=cp.space_id
            where cp.space_id=p_space_id and cp.card_id=p_source_card_id
              and cp.status not in ('cancelled','refunded')
              and round(cp.total_amount,2)=v_amount
              and (cp.purchase_at at time zone v_timezone)::date=(v_occurred at time zone v_timezone)::date
              and private.normalize_import_text(cp.description)=private.normalize_import_text(v_description)
          ) into v_possible;
        else
          select exists (
            select 1 from public.financial_events e
            join public.financial_impacts i on i.event_id=e.id and i.space_id=e.space_id
            where e.space_id=p_space_id and i.account_id=p_source_account_id
              and e.status not in ('cancelled','ignored','error')
              and round(abs(i.amount),2)=v_amount
              and (e.occurred_at at time zone v_timezone)::date=(v_occurred at time zone v_timezone)::date
              and private.normalize_import_text(e.description)=private.normalize_import_text(v_description)
              and i.dimension=case when p_source_kind='benefit' then 'benefit' else 'cash' end
          ) into v_possible;
        end if;
        if v_possible then v_duplicate := 'possible_duplicate'; end if;
      end if;

      if v_duplicate in ('already_imported','exact_duplicate') then
        v_decision := 'ignore';
      elsif v_duplicate='possible_duplicate' or v_final_type is null then
        v_decision := 'review';
      else
        v_decision := 'include';
      end if;

      insert into public.import_rows(
        batch_id,space_id,row_number,external_id,canonical_external_id,occurred_at,description,merchant,amount,direction,
        original_fields,candidate_type,final_type,category_id,confidence,reason,fingerprint,duplicate_state,user_decision,status
      ) values (
        v_batch_id,p_space_id,coalesce(nullif((v_row->>'row_number')::integer,0),v_ord::integer),v_external_id,v_external_key,v_occurred,
        v_description,v_merchant,v_amount,v_direction,
        case when octet_length(coalesce(v_row->'original_fields','{}'::jsonb)::text) <= 16384 then coalesce(v_row->'original_fields','{}'::jsonb) else '{}'::jsonb end,
        v_candidate,v_final_type,v_category_id,
        case when nullif(v_row->>'confidence','') is null then null else greatest(0,least(1,(v_row->>'confidence')::numeric)) end,
        left(coalesce(v_row->>'reason',''),300),v_fingerprint,v_duplicate,v_decision,'staged'
      );
    exception when others then
      insert into public.import_rows(
        batch_id,space_id,row_number,occurred_at,description,amount,direction,candidate_type,fingerprint,duplicate_state,user_decision,status,error_text
      ) values (
        v_batch_id,p_space_id,v_ord::integer,now(),coalesce(nullif(btrim(v_row->>'description'),''),'linha inválida'),0.01,
        case when lower(coalesce(v_row->>'direction',''))='credit' then 'credit' else 'debit' end,'unknown',
        md5(v_batch_id::text||'|'||v_ord::text),'unique','review','error',left(SQLERRM,240)
      );
    end;
  end loop;

  update public.import_batches b set
    selected_rows=(select count(*) from public.import_rows r where r.batch_id=b.id and r.user_decision='include'),
    duplicate_rows=(select count(*) from public.import_rows r where r.batch_id=b.id and r.duplicate_state<>'unique'),
    error_rows=(select count(*) from public.import_rows r where r.batch_id=b.id and r.status='error'),
    updated_at=now()
  where b.id=v_batch_id;

  return v_batch_id;
end;
$$;

create or replace function public.update_import_rows_review(
  p_space_id uuid,
  p_batch_id uuid,
  p_updates jsonb
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_update jsonb;
  v_row_id uuid;
  v_decision text;
  v_type text;
  v_category uuid;
  v_counterpart uuid;
  v_invoice uuid;
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if not private.can_write_space(p_space_id) then raise exception 'write_access_denied'; end if;
  if not exists(select 1 from public.import_batches b where b.id=p_batch_id and b.space_id=p_space_id and b.status in ('draft','reviewing','partially_completed')) then
    raise exception 'import_batch_not_reviewable';
  end if;
  if jsonb_typeof(p_updates)<>'array' or jsonb_array_length(p_updates)>2000 then raise exception 'invalid_import_updates'; end if;

  for v_update in select value from jsonb_array_elements(p_updates)
  loop
    v_row_id := (v_update->>'id')::uuid;
    v_decision := lower(coalesce(v_update->>'user_decision','review'));
    if v_decision not in ('include','ignore','review') then raise exception 'invalid_import_decision'; end if;
    v_type := nullif(lower(btrim(v_update->>'final_type')),'');
    if v_type is not null and v_type not in ('expense','income','card_purchase','benefit_expense','benefit_credit','transfer','card_payment') then
      raise exception 'invalid_import_type';
    end if;
    v_category := nullif(v_update->>'category_id','')::uuid;
    v_counterpart := nullif(v_update->>'counterpart_account_id','')::uuid;
    v_invoice := nullif(v_update->>'invoice_id','')::uuid;

    if v_category is not null and not exists(select 1 from public.categories c where c.id=v_category and c.space_id=p_space_id and c.active and c.is_selectable) then
      raise exception 'invalid_category';
    end if;
    if v_counterpart is not null and not exists(select 1 from public.accounts a where a.id=v_counterpart and a.space_id=p_space_id and a.active and a.type<>'benefit') then
      raise exception 'invalid_counterpart_account';
    end if;
    if v_invoice is not null and not exists(select 1 from public.card_invoices ci where ci.id=v_invoice and ci.space_id=p_space_id) then
      raise exception 'invalid_invoice';
    end if;

    update public.import_rows r set
      user_decision=v_decision,
      final_type=v_type,
      category_id=v_category,
      counterpart_account_id=v_counterpart,
      invoice_id=v_invoice,
      status=case when r.status='error' then 'staged' else r.status end,
      error_text=null,
      updated_at=now()
    where r.id=v_row_id and r.batch_id=p_batch_id and r.space_id=p_space_id and r.status<>'imported';
    if not found then raise exception 'import_row_not_reviewable'; end if;
  end loop;

  update public.import_batches b set
    status=case when b.status='partially_completed' then 'reviewing' else b.status end,
    selected_rows=(select count(*) from public.import_rows r where r.batch_id=b.id and r.user_decision='include' and r.status<>'imported'),
    updated_at=now()
  where b.id=p_batch_id and b.space_id=p_space_id;
end;
$$;

create or replace function public.confirm_transaction_import(
  p_space_id uuid,
  p_batch_id uuid
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_batch public.import_batches%rowtype;
  v_row public.import_rows%rowtype;
  v_event_id uuid;
  v_payment_account uuid;
  v_from uuid;
  v_to uuid;
  v_kind text;
  v_timezone text;
  v_pending integer;
  v_imported integer;
  v_ignored integer;
  v_duplicates integer;
  v_errors integer;
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if not private.can_write_space(p_space_id) then raise exception 'write_access_denied'; end if;

  select * into v_batch from public.import_batches b
  where b.id=p_batch_id and b.space_id=p_space_id
  for update;
  if not found then raise exception 'invalid_import_batch'; end if;
  if v_batch.status='cancelled' then raise exception 'import_batch_cancelled'; end if;
  if v_batch.status='completed' then
    select count(*) filter(where status='imported'),count(*) filter(where status='ignored'),count(*) filter(where duplicate_state<>'unique'),count(*) filter(where status='error'),count(*) filter(where status='staged')
    into v_imported,v_ignored,v_duplicates,v_errors,v_pending from public.import_rows where batch_id=p_batch_id;
    return jsonb_build_object('batch_id',p_batch_id,'status','completed','imported',v_imported,'ignored',v_ignored,'duplicates',v_duplicates,'errors',v_errors,'pending',v_pending);
  end if;

  update public.import_batches set status='importing',updated_at=now() where id=p_batch_id;
  select coalesce(fs.timezone,'America/Sao_Paulo') into v_timezone from public.financial_spaces fs where fs.id=p_space_id;

  update public.import_rows set status='ignored',updated_at=now()
  where batch_id=p_batch_id and status='staged' and user_decision='ignore';

  for v_row in
    select * from public.import_rows r
    where r.batch_id=p_batch_id and r.space_id=p_space_id and r.status in ('staged','error') and r.user_decision='include'
    order by r.row_number
  loop
    begin
      if v_row.occurred_at is null or v_row.amount<=0 or nullif(btrim(v_row.description),'') is null then raise exception 'invalid_import_row'; end if;
      if v_row.final_type is null then raise exception 'import_type_requires_review'; end if;

      if v_row.category_id is not null then
        v_kind := case when v_row.final_type in ('income','benefit_credit') then 'income' else 'expense' end;
        if not exists(select 1 from public.categories c where c.id=v_row.category_id and c.space_id=p_space_id and c.kind=v_kind and c.active and c.is_selectable) then
          raise exception 'invalid_category';
        end if;
      end if;

      if v_row.canonical_external_id is not null and exists(select 1 from public.financial_events e where e.space_id=p_space_id and e.external_id=v_row.canonical_external_id) then
        update public.import_rows set status='ignored',duplicate_state='already_imported',user_decision='ignore',updated_at=now() where id=v_row.id;
        continue;
      end if;

      v_event_id := null;
      case v_row.final_type
        when 'expense' then
          if v_batch.source_kind<>'account' then raise exception 'expense_requires_cash_account'; end if;
          v_event_id := public.register_expense(p_space_id,v_batch.source_account_id,v_row.amount,v_row.description,v_row.category_id,v_row.occurred_at,(v_row.occurred_at at time zone v_timezone)::date,'statement-import',v_row.canonical_external_id);
        when 'income' then
          if v_batch.source_kind<>'account' then raise exception 'income_requires_cash_account'; end if;
          v_event_id := public.register_income(p_space_id,v_batch.source_account_id,v_row.amount,v_row.description,v_row.category_id,v_row.occurred_at,(v_row.occurred_at at time zone v_timezone)::date,'statement-import',v_row.canonical_external_id);
        when 'card_purchase' then
          if v_batch.source_kind<>'card' then raise exception 'card_purchase_requires_card'; end if;
          v_event_id := public.register_card_purchase(p_space_id,v_batch.source_card_id,v_row.amount,v_row.description,1,v_row.category_id,v_row.occurred_at,v_row.merchant,'statement-import',v_row.canonical_external_id);
        when 'benefit_expense' then
          if v_batch.source_kind<>'benefit' then raise exception 'benefit_requires_benefit_account'; end if;
          v_event_id := public.register_benefit(p_space_id,v_batch.source_account_id,v_row.amount,v_row.description,false,v_row.category_id);
          update public.financial_events set source='statement-import',external_id=v_row.canonical_external_id,occurred_at=v_row.occurred_at,competence_date=(v_row.occurred_at at time zone v_timezone)::date,updated_at=now() where id=v_event_id and space_id=p_space_id;
          update public.financial_impacts set effective_date=(v_row.occurred_at at time zone v_timezone)::date where event_id=v_event_id and space_id=p_space_id;
        when 'benefit_credit' then
          if v_batch.source_kind<>'benefit' then raise exception 'benefit_requires_benefit_account'; end if;
          v_event_id := public.register_benefit(p_space_id,v_batch.source_account_id,v_row.amount,v_row.description,true,v_row.category_id);
          update public.financial_events set source='statement-import',external_id=v_row.canonical_external_id,occurred_at=v_row.occurred_at,competence_date=(v_row.occurred_at at time zone v_timezone)::date,updated_at=now() where id=v_event_id and space_id=p_space_id;
          update public.financial_impacts set effective_date=(v_row.occurred_at at time zone v_timezone)::date where event_id=v_event_id and space_id=p_space_id;
        when 'transfer' then
          if v_batch.source_kind<>'account' or v_row.counterpart_account_id is null then raise exception 'transfer_requires_counterpart'; end if;
          if not exists(select 1 from public.accounts a where a.id=v_row.counterpart_account_id and a.space_id=p_space_id and a.active and a.type<>'benefit') then raise exception 'invalid_counterpart_account'; end if;
          if v_row.counterpart_account_id=v_batch.source_account_id then raise exception 'transfer_accounts_must_differ'; end if;
          if v_row.direction='debit' then v_from:=v_batch.source_account_id; v_to:=v_row.counterpart_account_id; else v_from:=v_row.counterpart_account_id; v_to:=v_batch.source_account_id; end if;
          v_event_id := public.register_transfer(p_space_id,v_from,v_to,v_row.amount,v_row.description,v_row.occurred_at,'statement-import',v_row.canonical_external_id);
        when 'card_payment' then
          if v_row.invoice_id is null then raise exception 'card_payment_requires_invoice'; end if;
          if not exists(select 1 from public.card_invoices ci where ci.id=v_row.invoice_id and ci.space_id=p_space_id) then raise exception 'invalid_invoice'; end if;
          if v_batch.source_kind='account' then
            v_payment_account:=v_batch.source_account_id;
          elsif v_batch.source_kind='card' then
            if v_row.counterpart_account_id is null then raise exception 'card_payment_requires_account'; end if;
            v_payment_account:=v_row.counterpart_account_id;
            if not exists(select 1 from public.card_invoices ci where ci.id=v_row.invoice_id and ci.card_id=v_batch.source_card_id and ci.space_id=p_space_id) then raise exception 'invoice_card_mismatch'; end if;
          else
            raise exception 'benefit_cannot_pay_card';
          end if;
          if not exists(select 1 from public.accounts a where a.id=v_payment_account and a.space_id=p_space_id and a.active and a.type<>'benefit') then raise exception 'invalid_payment_account'; end if;
          v_event_id := public.pay_card_invoice(p_space_id,v_row.invoice_id,v_payment_account,v_row.amount,'payment',v_row.occurred_at,'statement-import',v_row.canonical_external_id);
        else
          raise exception 'unsupported_import_type';
      end case;

      if v_event_id is null then raise exception 'import_event_not_created'; end if;
      update public.financial_events e set metadata=coalesce(e.metadata,'{}'::jsonb)||jsonb_strip_nulls(jsonb_build_object(
        'import_batch_id',p_batch_id,'import_row_id',v_row.id,'import_filename',v_batch.filename,
        'import_format',v_batch.file_type,'import_source_kind',v_batch.source_kind,'import_external_id',v_row.external_id
      )),updated_at=now() where e.id=v_event_id and e.space_id=p_space_id;

      update public.import_rows set status='imported',imported_event_id=v_event_id,error_text=null,
        original_fields=jsonb_strip_nulls(jsonb_build_object(
          'document',original_fields->'document','file_category',original_fields->'file_category',
          'statement_type',original_fields->'statement_type','checknum',original_fields->'checknum'
        )),updated_at=now()
      where id=v_row.id;
    exception when others then
      update public.import_rows set status='error',error_text=left(SQLERRM,240),updated_at=now() where id=v_row.id;
    end;
  end loop;

  select count(*) filter(where status='imported'),count(*) filter(where status='ignored'),count(*) filter(where duplicate_state<>'unique'),count(*) filter(where status='error'),count(*) filter(where status='staged')
  into v_imported,v_ignored,v_duplicates,v_errors,v_pending from public.import_rows where batch_id=p_batch_id;

  update public.import_batches set
    imported_rows=v_imported,ignored_rows=v_ignored,duplicate_rows=v_duplicates,error_rows=v_errors,
    selected_rows=(select count(*) from public.import_rows r where r.batch_id=p_batch_id and r.user_decision='include' and r.status<>'imported'),
    status=case when v_errors>0 or v_pending>0 then 'partially_completed' else 'completed' end,
    completed_at=case when v_errors=0 and v_pending=0 then now() else completed_at end,
    updated_at=now()
  where id=p_batch_id;

  return jsonb_build_object(
    'batch_id',p_batch_id,'status',case when v_errors>0 or v_pending>0 then 'partially_completed' else 'completed' end,
    'imported',v_imported,'ignored',v_ignored,'duplicates',v_duplicates,'errors',v_errors,'pending',v_pending
  );
end;
$$;

create or replace function public.cancel_transaction_import(p_space_id uuid,p_batch_id uuid)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if not private.can_write_space(p_space_id) then raise exception 'write_access_denied'; end if;
  if exists(select 1 from public.import_rows r where r.batch_id=p_batch_id and r.space_id=p_space_id and r.status='imported') then
    raise exception 'import_already_confirmed';
  end if;
  update public.import_batches set status='cancelled',updated_at=now() where id=p_batch_id and space_id=p_space_id and status<>'completed';
  if not found then raise exception 'invalid_import_batch'; end if;
  update public.import_rows set user_decision='ignore',status='ignored',updated_at=now() where batch_id=p_batch_id and space_id=p_space_id and status<>'imported';
end;
$$;

revoke all on public.import_batches from anon;
revoke all on public.import_rows from anon;
grant select,insert,update,delete on public.import_batches to authenticated;
grant select,insert,update,delete on public.import_rows to authenticated;

revoke all on function public.stage_transaction_import(uuid,text,text,text,uuid,uuid,text,text,jsonb,text,jsonb) from public,anon;
revoke all on function public.update_import_rows_review(uuid,uuid,jsonb) from public,anon;
revoke all on function public.confirm_transaction_import(uuid,uuid) from public,anon;
revoke all on function public.cancel_transaction_import(uuid,uuid) from public,anon;
grant execute on function public.stage_transaction_import(uuid,text,text,text,uuid,uuid,text,text,jsonb,text,jsonb) to authenticated;
grant execute on function public.update_import_rows_review(uuid,uuid,jsonb) to authenticated;
grant execute on function public.confirm_transaction_import(uuid,uuid) to authenticated;
grant execute on function public.cancel_transaction_import(uuid,uuid) to authenticated;
