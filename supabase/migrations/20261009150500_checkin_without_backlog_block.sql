-- Users can finish the two-minute daily check-in without resolving a historical
-- classification backlog. The backlog remains visible in the review and inbox.
-- Preserve membership authorization through get_daily_financial_review.
create or replace function public.save_daily_financial_review(
  p_space_id uuid,
  p_movements_checked boolean,
  p_commitments_checked boolean,
  p_no_movements boolean default false,
  p_complete boolean default false,
  p_snooze boolean default false
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  uid uuid := auth.uid();
  state jsonb;
  today date;
begin
  state := public.get_daily_financial_review(p_space_id);
  today := (state->>'today')::date;
  if p_complete and (
    not coalesce(p_movements_checked,false)
    or not coalesce(p_commitments_checked,false)
  ) then
    raise exception 'review_incomplete';
  end if;

  insert into public.daily_financial_reviews (
    user_id, space_id, review_date,
    movements_checked, commitments_checked, no_movements,
    completed_at, snoozed_until
  )
  values (
    uid, p_space_id, today,
    coalesce(p_movements_checked,false),
    coalesce(p_commitments_checked,false),
    coalesce(p_no_movements,false),
    case when p_complete then now() end,
    case when p_snooze then now() + interval '30 minutes' end
  )
  on conflict(user_id,space_id,review_date) do update
  set movements_checked = excluded.movements_checked,
      commitments_checked = excluded.commitments_checked,
      no_movements = excluded.no_movements,
      completed_at = coalesce(daily_financial_reviews.completed_at, excluded.completed_at),
      snoozed_until = excluded.snoozed_until;

  return public.get_daily_financial_review(p_space_id);
end; $$;

revoke all on function public.save_daily_financial_review(uuid,boolean,boolean,boolean,boolean,boolean)
from public,anon;
grant execute on function public.save_daily_financial_review(uuid,boolean,boolean,boolean,boolean,boolean)
to authenticated;
