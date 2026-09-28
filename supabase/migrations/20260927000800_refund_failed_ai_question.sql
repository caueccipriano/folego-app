create or replace function public.refund_premium_ai_question(p_user_id uuid)
returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.role() <> 'service_role' then raise exception 'service role required'; end if;
 update public.ai_question_usage set used=greatest(0,used-1)
 where user_id=p_user_id and period_month=date_trunc('month',now() at time zone 'UTC')::date and used>0;
end;$$;
revoke all on function public.refund_premium_ai_question(uuid) from public,anon,authenticated;
grant execute on function public.refund_premium_ai_question(uuid) to service_role;