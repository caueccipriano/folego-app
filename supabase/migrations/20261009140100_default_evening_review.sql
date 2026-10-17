-- Set an evening default only for preferences created after this migration.
-- Existing users keep their selected notification times and reminder styles.
alter table public.notification_preferences
  alter column daily_summary_time set default '19:00:00'::time;
