-- Cash commitments follow payment instruments and active debt state.
-- Synthetic space only; all fixtures are rolled back.
begin;
do $test$
declare u uuid; s uuid:=gen_random_uuid(); a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); cc uuid:=gen_random_uuid(); d uuid; inc uuid:=gen_random_uuid(); r uuid:=gen_random_uuid(); e uuid; snap record; archived numeric; before_archive numeric; card_only numeric; benefit_only numeric;
begin
 select owner_id into u from public.financial_spaces order by created_at limit 1;
 perform set_config('request.jwt.claim.sub',u::text,true);
 insert into public.financial_spaces(id,owner_id,name) values(s,u,'Synthetic cash obligation audit');
 insert into public.space_members(space_id,user_id,role) values(s,u,'owner');
 insert into public.accounts(id,space_id,name,type,available_for_spending) values(a,s,'Synthetic cash','checking',true),(b,s,'Synthetic benefit','benefit',false);
 insert into public.credit_cards(id,space_id,name,closing_day,due_day,payment_account_id) values(cc,s,'Synthetic card',25,5,a);
 insert into public.financial_events(space_id,event_type,description,amount,currency,occurred_at,competence_date,status,source) values(s,'opening_balance','Synthetic balance',500,'BRL','2026-10-01','2026-10-01','confirmed','test') returning id into e;
 insert into public.financial_impacts(space_id,event_id,dimension,amount,account_id,effective_date) values(s,e,'cash',500,a,'2026-10-01');
 insert into public.recurring_items(id,space_id,name,item_type,amount,frequency,day_of_month,monthly_days,starts_on,certainty,active,account_id)
 values(inc,s,'Synthetic income','income',1000,'monthly',20,array[20],'2026-10-01','confirmed',true,a);
 d:=public.create_debt_v2(s,'Synthetic debt','Synthetic',100,1,'2026-10-16',a,'2026-10-01',null,'loan',null);
 select mandatory_outflows_until_income into before_archive from public.get_folego_snapshot(s,'2026-10-15');
 perform public.archive_debt(s,d);
 select mandatory_outflows_until_income into archived from public.get_folego_snapshot(s,'2026-10-15');
 -- Isolate each obligation without deleting financial records.
 update public.debt_installments set status='cancelled' where debt_id=d;
 insert into public.recurring_items(id,space_id,name,item_type,amount,frequency,day_of_month,monthly_days,starts_on,certainty,active,card_id)
 values(r,s,'Synthetic card subscription','expense',25,'monthly',16,array[16],'2026-10-01','confirmed',true,cc);
 select mandatory_outflows_until_income into card_only from public.get_folego_snapshot(s,'2026-10-15');
 update public.recurring_items set active=false where id=r;
 insert into public.recurring_items(space_id,name,item_type,amount,frequency,day_of_month,monthly_days,starts_on,certainty,active,account_id)
 values(s,'Synthetic benefit use','expense',17,'monthly',16,array[16],'2026-10-01','confirmed',true,b);
 select mandatory_outflows_until_income into benefit_only from public.get_folego_snapshot(s,'2026-10-15');
 if before_archive<>100 or archived<>0 or card_only<>0 or benefit_only<>0 then
  raise exception 'cash_obligation_mismatch active_debt=%, archived_debt=%, card_purchase=%, benefit=%',before_archive,archived,card_only,benefit_only;
 end if;
 -- Benefit credits must not become the next cash payday.
 insert into public.recurring_items(space_id,name,item_type,amount,frequency,day_of_month,monthly_days,starts_on,certainty,active,account_id)
 values(s,'Synthetic benefit credit','income',200,'monthly',16,array[16],'2026-10-01','confirmed',true,b);
 select * into snap from public.get_folego_snapshot(s,'2026-10-15');
 if snap.next_income_date <> date '2026-10-20' then raise exception 'benefit_credit_became_cash_payday'; end if;
 -- A real cash commitment and the card invoice still reserve cash exactly once.
 insert into public.recurring_items(space_id,name,item_type,amount,frequency,day_of_month,monthly_days,starts_on,certainty,active,account_id)
 values(s,'Synthetic cash bill','expense',40,'monthly',16,array[16],'2026-10-01','confirmed',true,a);
 insert into public.card_invoices(space_id,card_id,reference_month,closing_date,due_date,opening_balance,status)
 values(s,cc,'2026-10-01','2026-10-10','2026-10-18',30,'closed');
 select * into snap from public.get_folego_snapshot(s,'2026-10-15');
 if snap.mandatory_outflows_until_income<>70 or snap.cash_headroom<>430 or snap.spendable_pool<>430 then raise exception 'cash_or_invoice_commitment_lost'; end if;
 if exists(select 1 from public.get_upcoming_events(p_space_id=>s,p_from=>date '2026-10-15',p_until=>date '2026-10-19') where id=inc) then raise exception 'agenda_ignored_requested_end'; end if;
 if not exists(select 1 from public.get_upcoming_events(p_space_id=>s,p_from=>date '2026-10-20',p_until=>date '2026-10-21') where id=inc and due_date=date '2026-10-20') then raise exception 'agenda_lost_requested_income'; end if;
end; $test$;
rollback;
