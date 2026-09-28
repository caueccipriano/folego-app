alter table public.store_subscriptions add column if not exists last_event_at timestamptz;
create or replace function public.apply_verified_subscription_event(
 p_event_id text,p_event_type text,p_user_id uuid,p_expires_at_ms bigint,p_event_at_ms bigint)
returns void language plpgsql security definer set search_path=''
as $$
declare v_at timestamptz; v_exp timestamptz; v_status text;
begin
 if p_event_id is null or length(p_event_id)>200 or length(p_event_id)=0 then raise exception 'Invalid event'; end if;
 if p_event_at_ms is null or p_event_at_ms<0 then raise exception 'Missing event timestamp'; end if;
 v_at:=to_timestamp(p_event_at_ms/1000.0);
 if v_at>now()+interval '1 day' then raise exception 'Invalid future event'; end if;
 if p_expires_at_ms is not null then v_exp:=to_timestamp(p_expires_at_ms/1000.0); end if;
 -- Cancellation disables auto-renew, NOT an existing paid entitlement.
 if p_event_type not in ('INITIAL_PURCHASE','RENEWAL','PRODUCT_CHANGE','UNCANCELLATION','EXPIRATION','REFUND') then return; end if;
 if p_event_type in ('INITIAL_PURCHASE','RENEWAL','PRODUCT_CHANGE','UNCANCELLATION') and v_exp is null then raise exception 'Missing expiration'; end if;
 insert into public.subscription_webhook_events(event_id,event_type) values(p_event_id,p_event_type) on conflict do nothing;
 if not found then return; end if;
 v_status:=case when p_event_type in ('EXPIRATION','REFUND') then 'revoked' when v_exp>now() then 'active' else 'expired' end;
 insert into public.store_subscriptions(user_id,entitlement,expires_at,status,last_event_at)
 values(p_user_id,'premium',v_exp,v_status,v_at)
 on conflict(user_id) do update set
 expires_at=excluded.expires_at,status=excluded.status,last_event_at=excluded.last_event_at,updated_at=now()
 where public.store_subscriptions.last_event_at is null or excluded.last_event_at>public.store_subscriptions.last_event_at;
end; $$;
revoke all on function public.apply_verified_subscription_event(text,text,uuid,bigint,bigint) from public,anon,authenticated;
grant execute on function public.apply_verified_subscription_event(text,text,uuid,bigint,bigint) to service_role;