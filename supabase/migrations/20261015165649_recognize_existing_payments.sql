-- Explicit, reversible recognition. Existing cash impact and source identities survive.
create table public.payment_recognitions (
 event_id uuid primary key,
 space_id uuid not null,
 target_kind text not null check (target_kind in ('invoice','debt')),
 target_id uuid not null,
 original_event jsonb not null,
 original_impacts jsonb not null,
 linked_at timestamptz not null default now(),
 unlinked_at timestamptz,
 foreign key(event_id,space_id) references public.financial_events(id,space_id) on delete restrict
);
create index payment_recognitions_space_idx on public.payment_recognitions(space_id);
alter table public.payment_recognitions enable row level security;
create policy payment_recognitions_member on public.payment_recognitions for select to authenticated
 using ((select private.is_space_member(space_id)));
revoke all on public.payment_recognitions from public,anon,authenticated;
grant select on public.payment_recognitions to authenticated;

create function private.recognize_existing_payment(p_space_id uuid,p_event_id uuid,p_target_kind text,p_target_id uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare
 e public.financial_events; i public.debt_installments; d public.debts;
 c public.card_invoices; a uuid; cash_count integer; outstanding numeric; saved jsonb;
begin
 if auth.uid() is null or not private.can_write_space(p_space_id) then raise exception 'write_access_denied' using errcode='42501'; end if;
 -- Serialize recognition, unlinking and invoice/debt payment within this space.
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_space_id::text,71015));
 select * into e from public.financial_events where id=p_event_id and space_id=p_space_id for update;
 if e.id is null then raise exception 'invalid_payment_candidate'; end if;
 if exists(select 1 from public.payment_recognitions r where r.event_id=e.id and r.unlinked_at is null and r.target_kind=p_target_kind and r.target_id=p_target_id) then return e.id; end if;
 if e.event_type<>'expense' or e.status<>'confirmed' or e.amount<=0 or e.parent_event_id is not null
 or e.metadata ? 'legacy_exception'
 or exists(select 1 from public.card_payments where event_id=e.id)
 or exists(select 1 from public.debt_payments where event_id=e.id)
 or exists(select 1 from public.recurring_occurrences where event_id=e.id and space_id=p_space_id)
 then raise exception 'invalid_payment_candidate'; end if;
 select count(*),min(fi.account_id::text)::uuid into cash_count,a from public.financial_impacts fi
 where fi.event_id=e.id and fi.space_id=p_space_id and fi.dimension='cash' and fi.amount=-e.amount;
 if cash_count<>1 or (select count(*) from public.financial_impacts where event_id=e.id and dimension='cash')<>1
 or exists(select 1 from public.financial_impacts where event_id=e.id and dimension not in ('cash','economic','budget'))
 or not exists(select 1 from public.accounts where id=a and space_id=p_space_id and active and type<>'benefit')
 then raise exception 'invalid_payment_candidate'; end if;
 if p_target_kind='invoice' then
  select * into c from public.card_invoices where id=p_target_id and space_id=p_space_id and status<>'cancelled' for update;
  if c.id is null then raise exception 'invalid_invoice'; end if;
  select c.opening_balance+coalesce((select sum(amount) from public.card_installments where invoice_id=c.id and space_id=p_space_id and status not in ('cancelled','refunded')),0)
   -coalesce((select sum(amount) from public.card_payments where invoice_id=c.id and space_id=p_space_id and status='confirmed'),0) into outstanding;
 elsif p_target_kind='debt' then
  select * into i from public.debt_installments where id=p_target_id and space_id=p_space_id and status not in ('paid','cancelled') for update;
  select * into d from public.debts where id=i.debt_id and space_id=p_space_id and status='active' and archived_at is null for update;
  if i.id is null or d.id is null then raise exception 'invalid_debt'; end if;
  outstanding:=i.planned_amount-i.paid_amount;
 else raise exception 'invalid_payment_target'; end if;
 if round(e.amount,2)>round(outstanding,2) or outstanding<=0 then raise exception 'payment_exceeds_outstanding_balance'; end if;
 select coalesce(jsonb_agg(to_jsonb(fi)),'[]'::jsonb) into saved from public.financial_impacts fi where fi.event_id=e.id and fi.dimension in ('economic','budget');
 insert into public.payment_recognitions(event_id,space_id,target_kind,target_id,original_event,original_impacts)
 values(e.id,p_space_id,p_target_kind,p_target_id,to_jsonb(e),saved)
 on conflict(event_id) do update set target_kind=excluded.target_kind,target_id=excluded.target_id,original_event=excluded.original_event,original_impacts=excluded.original_impacts,linked_at=now(),unlinked_at=null;
 delete from public.financial_impacts where event_id=e.id and space_id=p_space_id and dimension in ('economic','budget');
 update public.financial_events set event_type=case p_target_kind when 'invoice' then 'card_payment' else 'debt_payment' end,
  category_id=null, metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('recognized_payment',true,'payment_target',p_target_id),updated_at=now() where id=e.id;
 if p_target_kind='invoice' then
  insert into public.card_payments(space_id,invoice_id,account_id,event_id,amount,paid_at,payment_type,status)
  values(p_space_id,c.id,a,e.id,e.amount,e.occurred_at,'payment','confirmed');
  update public.card_invoices set status=case when outstanding-e.amount<=0 then 'paid' else 'partially_paid' end,updated_at=now() where id=c.id;
 else
  insert into public.debt_payments(space_id,debt_id,installment_id,event_id,account_id,amount,paid_at,status)
  values(p_space_id,d.id,i.id,e.id,a,e.amount,e.occurred_at,'confirmed');
  update public.debt_installments set paid_amount=paid_amount+e.amount,payment_event_id=e.id,
   status=case when paid_amount+e.amount>=planned_amount then 'paid' else 'partially_paid' end,updated_at=now() where id=i.id;
  if not exists(select 1 from public.debt_installments where debt_id=d.id and space_id=p_space_id and status not in ('paid','cancelled')) then
   update public.debts set status='paid',closed_at=now(),updated_at=now() where id=d.id;
  end if;
 end if;
 return e.id;
end; $$;
create function public.recognize_existing_payment(p_space_id uuid,p_event_id uuid,p_target_kind text,p_target_id uuid)
returns uuid language sql security invoker set search_path='' as $$ select private.recognize_existing_payment(p_space_id,p_event_id,p_target_kind,p_target_id); $$;

create function private.unlink_recognized_payment(p_space_id uuid,p_event_id uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare r public.payment_recognitions; e public.financial_events; saved public.financial_impacts; item jsonb; outstanding numeric;
begin
 if auth.uid() is null or not private.can_write_space(p_space_id) then raise exception 'write_access_denied' using errcode='42501'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_space_id::text,71015));
 select * into e from public.financial_events where id=p_event_id and space_id=p_space_id for update;
 select * into r from public.payment_recognitions where event_id=p_event_id and space_id=p_space_id for update;
 if r.event_id is null then raise exception 'recognition_not_found'; end if;
 if r.unlinked_at is not null then return p_event_id; end if;
 -- Do not rewrite invoices that have already carried balances into a later one.
 if r.target_kind='invoice' and exists(select 1 from public.card_invoices c join public.card_invoices later on later.card_id=c.card_id and later.space_id=c.space_id and later.reference_month>c.reference_month and later.opening_balance<>0 where c.id=r.target_id and c.space_id=p_space_id) then raise exception 'card_payment_has_later_carryover'; end if;
 update public.payment_recognitions set unlinked_at=now() where event_id=p_event_id;
 if r.target_kind='invoice' then
  perform 1 from public.card_invoices where id=r.target_id and space_id=p_space_id for update;
  delete from public.card_payments where event_id=p_event_id and space_id=p_space_id;
  select c.opening_balance+coalesce((select sum(amount) from public.card_installments where invoice_id=c.id and space_id=p_space_id and status not in ('cancelled','refunded')),0)-coalesce((select sum(amount) from public.card_payments where invoice_id=c.id and space_id=p_space_id and status='confirmed'),0)
  into outstanding from public.card_invoices c where c.id=r.target_id;
  update public.card_invoices set status=case when outstanding<=0 then 'paid' when exists(select 1 from public.card_payments where invoice_id=r.target_id and status='confirmed') then 'partially_paid' when due_date<current_date then 'overdue' when closing_date<current_date then 'closed' else 'open' end,updated_at=now() where id=r.target_id;
 else
  perform 1 from public.debt_installments where id=r.target_id and space_id=p_space_id for update;
  delete from public.debt_payments where event_id=p_event_id and space_id=p_space_id;
  update public.debt_installments set paid_amount=greatest(0,paid_amount-e.amount),
   status=case when paid_amount-e.amount>=planned_amount then 'paid' when paid_amount-e.amount>0 then 'partially_paid' else 'pending' end,
   payment_event_id=(select event_id from public.debt_payments where installment_id=r.target_id and status='confirmed' order by paid_at desc limit 1),updated_at=now() where id=r.target_id;
  update public.debts set status='active',closed_at=null,updated_at=now() where id=(select debt_id from public.debt_installments where id=r.target_id) and status='paid';
 end if;
 update public.financial_events set event_type=r.original_event->>'event_type',category_id=(r.original_event->>'category_id')::uuid,metadata=r.original_event->'metadata',updated_at=now() where id=p_event_id;
 for item in select * from jsonb_array_elements(r.original_impacts) loop
  saved:=jsonb_populate_record(null::public.financial_impacts,item);
  insert into public.financial_impacts select saved.*;
 end loop;
 return p_event_id;
end; $$;
create function public.unlink_recognized_payment(p_space_id uuid,p_event_id uuid)
returns uuid language sql security invoker set search_path='' as $$ select private.unlink_recognized_payment(p_space_id,p_event_id); $$;

-- Existing edit/reversal/import paths must unlink explicitly before altering a recognized payment.
create function private.guard_recognized_payment() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if exists(select 1 from public.payment_recognitions where event_id=old.id and unlinked_at is null)
 and (tg_op='DELETE' or new.status is distinct from old.status or new.amount is distinct from old.amount or new.occurred_at is distinct from old.occurred_at or new.event_type not in ('card_payment','debt_payment') or new.metadata->>'recognized_payment' is distinct from 'true') then
  raise exception 'unlink_recognized_payment_first';
 end if;
 if tg_op='DELETE' then return old; end if; return new;
end; $$;
create trigger guard_recognized_payment before update or delete on public.financial_events for each row execute function private.guard_recognized_payment();
revoke all on function private.guard_recognized_payment() from public,anon,authenticated;
revoke all on function private.recognize_existing_payment(uuid,uuid,text,uuid),public.recognize_existing_payment(uuid,uuid,text,uuid),private.unlink_recognized_payment(uuid,uuid),public.unlink_recognized_payment(uuid,uuid) from public,anon;
grant execute on function private.recognize_existing_payment(uuid,uuid,text,uuid),public.recognize_existing_payment(uuid,uuid,text,uuid),private.unlink_recognized_payment(uuid,uuid),public.unlink_recognized_payment(uuid,uuid) to authenticated;
create function private.guard_invoice_payment_balance() returns trigger language plpgsql security definer set search_path='' as $$
declare outstanding numeric;
begin
 if new.status<>'confirmed' then return new; end if;
 perform 1 from public.card_invoices where id=new.invoice_id and space_id=new.space_id for update;
 select c.opening_balance+coalesce((select sum(amount) from public.card_installments where invoice_id=c.id and space_id=c.space_id and status not in ('cancelled','refunded')),0)-coalesce((select sum(amount) from public.card_payments where invoice_id=c.id and space_id=c.space_id and status='confirmed'),0)
 into outstanding from public.card_invoices c where c.id=new.invoice_id and c.space_id=new.space_id;
 if outstanding is null or new.amount>outstanding+0.01 then raise exception 'payment_exceeds_outstanding_balance'; end if;
 return new;
end; $$;
create trigger guard_invoice_payment_balance before insert on public.card_payments for each row execute function private.guard_invoice_payment_balance();
revoke all on function private.guard_invoice_payment_balance() from public,anon,authenticated;
create function private.guard_recognized_payment_cash() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if exists(select 1 from public.payment_recognitions where event_id=old.event_id and unlinked_at is null) then raise exception 'unlink_recognized_payment_first'; end if;
 if tg_op='DELETE' then return old; end if; return new;
end; $$;
create trigger guard_recognized_payment_cash before update or delete on public.financial_impacts for each row when(old.dimension='cash') execute function private.guard_recognized_payment_cash();
revoke all on function private.guard_recognized_payment_cash() from public,anon,authenticated;
