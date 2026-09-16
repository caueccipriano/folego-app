-- Applied to Supabase Dev as 20260916085459_index_debt_payment_foreign_keys.
-- Covers foreign keys introduced with debt_payments; no financial semantics change.

create index if not exists debt_payments_account_space_idx
  on public.debt_payments(account_id, space_id);
create index if not exists debt_payments_debt_space_idx
  on public.debt_payments(debt_id, space_id);
create index if not exists debt_payments_event_space_idx
  on public.debt_payments(event_id, space_id);
create index if not exists debt_payments_installment_space_idx
  on public.debt_payments(installment_id, space_id);
