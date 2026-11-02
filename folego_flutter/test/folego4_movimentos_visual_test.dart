import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:folego/features/transactions/transaction_day_label.dart';

void main() {
  test('daily groups preserve exact calendar days', () {
    final today = DateTime.utc(2026, 11, 1);
    expect(
      transactionDayLabel(DateTime.utc(2026, 11, 1, 12), referenceDate: today),
      'hoje · 01 nov',
    );
    expect(
      transactionDayLabel(DateTime.utc(2026, 10, 31, 18), referenceDate: today),
      'ontem · 31 out',
    );
    expect(
      transactionDayLabel(DateTime.utc(2026, 10, 30), referenceDate: today),
      'sex · 30 out',
    );
    expect(
      transactionDayLabel(DateTime.utc(2026, 10, 29), referenceDate: today),
      'qui · 29 out',
    );
  });

  test('historical groups distinguish years and daylight savings', () {
    expect(
      transactionDayLabel(
        DateTime.utc(2025, 11, 1),
        referenceDate: DateTime.utc(2026, 11, 1),
      ),
      'sáb · 01 nov 2025',
    );
    expect(
      transactionDayLabel(
        DateTime.utc(2026, 3, 8),
        referenceDate: DateTime.utc(2026, 3, 9),
      ),
      'ontem · 08 mar',
    );
  });

  test('transaction list keeps paging and adds day headings', () {
    final source =
        File('lib/features/transactions/transactions_screen_base.dart')
            .readAsStringSync();
    expect(source, contains('transactionDayLabel(item.occurredAt)'));
    expect(source, contains('transactionDayLabel(transactions[index - 1].occurredAt)'));
    expect(source, contains(r'transaction-day-$index'));
    expect(source, isNot(contains('esta semana')));
    expect(source, contains('onLoadMore()'));
    expect(source, contains('hasMore &&'));
    expect(source, contains('onOpen(item)'));
    expect(source, contains("ValueKey('transaction-row-amount')"));
    expect(source, contains('financialDisplayDescription(item.description)'));
    expect(source, contains('Formatters.money(item.amount.abs())'));
    expect(source, contains('showCheckmark: false'));
  });
}
