-- The daily summary edge function existed but had no scheduler.
-- Use the existing private HTTP dispatcher and vault-held token.
-- Idempotent to preserve current installations.
do $$
begin
  if not exists (
    select 1 from cron.job
    where jobname = 'folego-daily-summary-dispatch'
  ) then
    perform cron.schedule(
      'folego-daily-summary-dispatch',
      '*/5 * * * *',
      'select private.invoke_folego_daily_summary_dispatch();'
    );
  end if;
end
$$;
