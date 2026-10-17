-- Only the existing authenticated sheet-sync service may call this function.
create or replace function public.sheet_sync_classify_event_cas(
 p_space_id uuid, p_event_id uuid, p_category_id uuid,
 p_expected_category_id uuid, p_expected_updated_at timestamptz
) returns jsonb language plpgsql security invoker set search_path='' as $fn$
declare e public.financial_events%rowtype; c public.categories%rowtype; k text;
begin
 select * into e from public.financial_events where id=p_event_id and space_id=p_space_id for update;
 if not found then return jsonb_build_object('status','missing_event'); end if;
 if e.status<>'confirmed' then return jsonb_build_object('status','invalid_status'); end if;
 k:=case when e.event_type in ('income','benefit_credit','reimbursement') then 'income'
 when e.event_type in ('expense','card_purchase','benefit_expense','refund','debt_payment') then 'expense' else null end;
 if k is null then return jsonb_build_object('status','not_classifiable'); end if;
 select * into c from public.categories where id=p_category_id and space_id=p_space_id
 and active and kind=k and category_role='economic' and is_selectable;
 if not found then return jsonb_build_object('status','invalid_category'); end if;
 if e.category_id is not distinct from p_category_id then
 return jsonb_build_object('status','unchanged','event_id',e.id,'category_id',e.category_id,'updated_at',e.updated_at); end if;
 if p_expected_updated_at is null or e.updated_at<>p_expected_updated_at
 or e.category_id is distinct from p_expected_category_id then
 return jsonb_build_object('status','conflict_version','event_id',e.id,'category_id',e.category_id,'updated_at',e.updated_at); end if;
 update public.financial_events set category_id=p_category_id,
 metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('needs_classification',false,'classified_at',clock_timestamp(),'classified_via','sheet'), updated_at=clock_timestamp()
 where id=e.id and space_id=p_space_id returning * into e;
 update public.financial_impacts set category_id=p_category_id
 where event_id=e.id and space_id=p_space_id and dimension in ('economic','budget');
 update public.card_purchases set category_id=p_category_id,updated_at=clock_timestamp()
 where event_id=e.id and space_id=p_space_id;
 return jsonb_build_object('status','updated','event_id',e.id,'category_id',e.category_id,'updated_at',e.updated_at);
end;
$fn$;
revoke all on function public.sheet_sync_classify_event_cas(uuid,uuid,uuid,uuid,timestamptz) from public,anon,authenticated;
grant execute on function public.sheet_sync_classify_event_cas(uuid,uuid,uuid,uuid,timestamptz) to service_role;
