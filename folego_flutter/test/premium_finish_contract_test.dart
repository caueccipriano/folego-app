import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:folego/features/transactions/transaction_card_layout.dart';

void main() {
  test('short mobile rows keep readable amounts on a separate line', () {
    expect(transactionAmountNeedsOwnLine(width: 300, textScale: 1), isTrue);
    expect(transactionAmountNeedsOwnLine(width: 349, textScale: 1), isTrue);
    expect(transactionAmountNeedsOwnLine(width: 350, textScale: 1), isFalse);
    expect(transactionAmountNeedsOwnLine(width: 400, textScale: 1), isFalse);
  });

  test('accessibility font scaling preserves full-sized currency amounts', () {
    expect(transactionAmountNeedsOwnLine(width: 500, textScale: 1.3), isTrue);
    expect(transactionAmountNeedsOwnLine(width: 500, textScale: 1.6), isTrue);
    expect(transactionAmountNeedsOwnLine(width: 500, textScale: 1.2), isFalse);
  });

  test('transaction amount is rendered once with no financial recalculation', () {
    final source = File('lib/features/transactions/transactions_screen_base.dart')
        .readAsStringSync();
    expect(source, contains('transactionAmountNeedsOwnLine('));
    expect(source, contains("ValueKey('transaction-row-amount')"));
    expect(source, contains('if (ownLine) ...['));
    expect(source, contains('if (!ownLine) ...['));
    expect(source, contains('onTap: onOpen'));
    expect(source, contains('MediaQuery.highContrastOf(context) ? 0 : .8'));
  });

  test('compact Home keeps a premium sheen with accessible tap regions', () {
    final source = File('lib/features/home/home_fixed_dashboard.dart')
        .readAsStringSync();
    expect(source, contains("ValueKey('home-fixed-spendable-tap')"));
    expect(source, contains('MediaQuery.highContrastOf(context) ? 0 : 5'));
    expect(source, contains('withValues(alpha: .09)'));
    expect(source, contains('onTap: onDetails'));
    expect(source, isNot(contains('BackdropFilter(')));
  });
}
