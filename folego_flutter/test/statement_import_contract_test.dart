import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  test('staging is RLS-protected, bounded and does not store raw files', () {
    final sql = read('../supabase/migrations/20260916161942_add_transaction_import_staging.sql');
    expect(sql, contains('alter table public.import_batches enable row level security'));
    expect(sql, contains('alter table public.import_rows enable row level security'));
    expect(sql, contains("v_count > 2000"));
    expect(sql, contains('4194304'));
    expect(sql, isNot(contains('storage.objects')));
    expect(sql, isNot(contains('file_bytes')));
    expect(sql, isNot(contains('raw_file')));
  });

  test('FITID/external id is namespaced and fallback fingerprint is contextual', () {
    final sql = read('../supabase/migrations/20260916161942_add_transaction_import_staging.sql');
    expect(sql, contains('private.import_external_key'));
    expect(sql, contains("p_space_id::text || '|' || coalesce(p_source_kind,'')"));
    expect(sql, contains("lower(btrim(coalesce(p_institution,'')))"));
    expect(sql, contains('private.import_row_fingerprint'));
    expect(sql, contains('round(p_amount,2)'));
    expect(sql, contains('private.normalize_import_text(p_description)'));
  });

  test('duplicates default conservatively and confirmation is idempotent per row/batch', () {
    final sql = read('../supabase/migrations/20260916161942_add_transaction_import_staging.sql');
    expect(sql, contains("v_duplicate := 'exact_duplicate'"));
    expect(sql, contains("v_decision := 'ignore'"));
    expect(sql, contains("v_duplicate='possible_duplicate'"));
    expect(sql, contains("v_decision := 'review'"));
    expect(sql, contains("if v_batch.status='completed' then"));
    expect(sql, contains("r.status in ('staged','error') and r.user_decision='include'"));
    expect(sql, contains('exception when others then'));
    expect(sql, contains("status='error'"));
  });

  test('confirmation delegates financial semantics to canonical RPCs', () {
    final sql = read('../supabase/migrations/20260916164905_fix_transaction_import_backing_ids.sql');
    expect(sql, contains('public.register_expense('));
    expect(sql, contains('public.register_income('));
    expect(sql, contains('public.register_card_purchase('));
    expect(sql, contains('public.register_benefit('));
    expect(sql, contains('public.register_transfer('));
    expect(sql, contains('public.pay_card_invoice('));
    expect(sql, isNot(contains('insert into public.financial_impacts')));
    expect(sql, isNot(contains('insert into public.financial_events')));
    expect(sql, contains("'statement-import'"));
  });

  test('sensitive types require relations and benefit cannot pay invoice', () {
    final sql = read('../supabase/migrations/20260916164905_fix_transaction_import_backing_ids.sql');
    expect(sql, contains('transfer_requires_counterpart'));
    expect(sql, contains('card_payment_requires_invoice'));
    expect(sql, contains('card_payment_requires_account'));
    expect(sql, contains('benefit_cannot_pay_card'));
    expect(sql, contains("a.type<>'benefit'"));
  });

  test('date-only rows use financial-space timezone and local noon', () {
    final sql = read('../supabase/migrations/20260916161942_add_transaction_import_staging.sql');
    expect(sql, contains("coalesce(fs.timezone,'America/Sao_Paulo')"));
    expect(sql, contains("(v_row->>'local_date')::date + time '12:00'"));
  });

  test('backing IDs for card purchase/payment are resolved to financial events', () {
    final sql = read('../supabase/migrations/20260916164905_fix_transaction_import_backing_ids.sql');
    expect(sql, contains('select cp.event_id into v_event_id from public.card_purchases'));
    expect(sql, contains('select cp.event_id into v_event_id from public.card_payments'));
  });

  test('new staging FKs and auth policy are optimized', () {
    final sql = read('../supabase/migrations/20260916164540_optimize_transaction_import_staging.sql');
    for (final index in [
      'import_batches_user_idx',
      'import_batches_source_account_idx',
      'import_batches_source_card_idx',
      'import_rows_category_idx',
      'import_rows_counterpart_account_idx',
      'import_rows_invoice_idx',
      'import_rows_imported_event_idx',
    ]) {
      expect(sql, contains(index));
    }
    expect(sql, contains('user_id = (select auth.uid())'));
  });

  test('transactions wrapper preserves canonical base and secondary import entry', () {
    final source = read('lib/features/transactions/transactions_screen.dart');
    expect(source, contains('impl.TransactionsScreenV3'));
    expect(source, contains("ValueKey('statement-import-entry')"));
    expect(source, contains('StatementImportScreen'));
    expect(source, isNot(contains('TransactionImportScreen')));
  });

  test('transaction filters/search/keyset and recurring card contracts remain untouched', () {
    final transactions = read('lib/features/transactions/transactions_screen_base.dart');
    expect(transactions, contains('pageSize'));
    expect(transactions, contains('getTransactionsFilteredPage'));
    final recurring = read('lib/features/transactions/recurring_form_sheet.dart');
    expect(recurring, contains('card'));
  });
}
