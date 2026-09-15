drop index public.goal_contributions_goal_date_idx;

create index goal_contributions_goal_space_date_idx
  on public.goal_contributions(
    goal_id,
    space_id,
    contributed_at desc,
    created_at desc
  );
