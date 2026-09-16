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
  v_backing_id uuid;
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
      v_backing_id := null;
      case v_row.final_type
        when 'expense' then
          if v_batch.source_kind<>'account' then raise exception 'expense_requires_cash_account'; end if;
          v_event_id := public.register_expense(p_space_id,v_batch.source_account_id,v_row.amount,v_row.description,v_row.category_id,v_row.occurred_at,(v_row.occurred_at at time zone v_timezone)::date,'statement-import',v_row.canonical_external_id);
        when 'income' then
          if v_batch.source_kind<>'account' then raise exception 'income_requires_cash_account'; end if;
          v_event_id := public.register_income(p_space_id,v_batch.source_account_id,v_row.amount,v_row.description,v_row.category_id,v_row.occurred_at,(v_row.occurred_at at time zone v_timezone)::date,'statement-import',v_row.canonical_external_id);
        when 'card_purchase' then
          if v_batch.source_kind<>'card' then raise exception 'card_purchase_requires_card'; end if;
          v_backing_id := public.register_card_purchase(p_space_id,v_batch.source_card_id,v_row.amount,v_row.description,1,v_row.category_id,v_row.occurred_at,v_row.merchant,'statement-import',v_row.canonical_external_id);
          select cp.event_id into v_event_id from public.card_purchases cp where cp.id=v_backing_id and cp.space_id=p_space_id;
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
          v_backing_id := public.pay_card_invoice(p_space_id,v_row.invoice_id,v_payment_account,v_row.amount,'payment',v_row.occurred_at,'statement-import',v_row.canonical_external_id);
          select cp.event_id into v_event_id from public.card_payments cp where cp.id=v_backing_id and cp.space_id=p_space_id;
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

revoke all on function public.confirm_transaction_import(uuid,uuid) from public,anon;
grant execute on function public.confirm_transaction_import(uuid,uuid) to authenticated;
