-- Temporary private beta: only the verified Folego account can call the AI.
-- Enforce by auth UID, not a client-supplied email or premium flag.
create or replace function public.consume_premium_ai_question(p_user_id uuid)
returns boolean language plpgsql security definer set search_path='' as $$
declare v_month date := date_trunc('month',now() at time zone 'UTC')::date;
begin
 if auth.role() <> 'service_role' then raise exception 'service role required'; end if;
 if p_user_id <> '5de8e34a-c6f5-4667-8fe0-2b4b89b42880'::uuid then return false; end if;
 insert into public.ai_question_usage(user_id,period_month,used) values(p_user_id,v_month,1)
 on conflict(user_id,period_month) do update set used=public.ai_question_usage.used+1 where public.ai_question_usage.used<30;
 return found;
end;$$;
revoke all on function public.consume_premium_ai_question(uuid) from public,anon,authenticated;
grant execute on function public.consume_premium_ai_question(uuid) to service_role;