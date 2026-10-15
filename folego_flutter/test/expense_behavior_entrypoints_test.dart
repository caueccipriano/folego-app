import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/transaction_detail.dart';
import 'package:folego/features/transactions/transaction_detail_sheet_v2.dart';

TransactionDetail expenseFixture(String type, {String status = 'confirmed'}) {
  return TransactionDetail(
    id: 'synthetic-event',
    spaceId: 'synthetic-space',
    eventType: type,
    description: 'test only',
    amount: 42,
    occurredAt: DateTime(2026, 10, 15),
    status: status,
    source: 'synthetic-test',
    impacts: const [],
  );
}

void main() {
  test('only confirmed expense events may open behavior editor', () {
    for (final type in ['expense', 'card_purchase', 'benefit_expense']) {
      expect(canClassifyExpenseBehavior(expenseFixture(type)), isTrue);
    }
    for (final type in ['income', 'transfer', 'card_payment', 'refund']) {
      expect(canClassifyExpenseBehavior(expenseFixture(type)), isFalse);
    }
    expect(
      canClassifyExpenseBehavior(expenseFixture('expense', status: 'pending')),
      isFalse,
    );
  });

  test('transactions and detail screens have reachable fixed-variable actions', () {
    final transactions =
        File('lib/features/transactions/transactions_screen.dart')
            .readAsStringSync();
    final header =
        File('lib/features/transactions/transactions_screen_base.dart')
            .readAsStringSync();
    final detail =
        File('lib/features/transactions/transaction_detail_sheet_v2.dart')
            .readAsStringSync();
    expect(transactions, contains('onSpendingBehaviorRequested: _openExpenseBehaviors'));
    expect(header, contains('transactions-spending-behavior-entry'));
    expect(detail, contains('transaction-edit-spending-behavior'));
    expect(detail, contains('setSpendingBehavior('));
  });
}
