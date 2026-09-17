-- Relevant spend alerts are part of the essential notification experience.
-- Existing rows predate this preference, so opt them in once at rollout.
alter table public.notification_preferences
  alter column large_expenses_enabled set default true;

update public.notification_preferences
set large_expenses_enabled = true
where large_expenses_enabled = false;
