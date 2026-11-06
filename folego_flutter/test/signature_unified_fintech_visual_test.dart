import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('statement uses quiet day markers and legible banking search', () {
    final source = File('lib/features/transactions/transactions_screen_base.dart')
        .readAsStringSync();
    expect(source, contains("ValueKey('transaction-day-\$index')"));
    expect(source, contains('height: 17,'));
    expect(source, contains('focusedBorder: OutlineInputBorder('));
    expect(source, contains('selectedColor: accent.withValues(alpha: .13)'));
    expect(source, contains("ValueKey('transaction-row-amount')"));
    expect(source, contains('transactionAmountNeedsOwnLine('));
    expect(source, contains('onTap: onOpen'));
    expect(source, contains('onLoadMore()'));
    expect(source, contains('financialDisplayDescription(item.description)'));
  });

  test('plan keeps real figures readable without inventing values', () {
    final source = File('lib/features/plan/plan_screen_web2.dart')
        .readAsStringSync();
    expect(source, contains('VISÃO FINANCEIRA'));
    expect(source, contains("ValueKey('plan-metrics-stacked')"));
    expect(source, contains("ValueKey('plan-metrics-inline')"));
    expect(source, contains('limits.maxWidth < 330'));
    expect(source, contains('MediaQuery.textScalerOf(context).scale(14) >= 18'));
    expect(source, contains('Formatters.money(summary.plannedAmount)'));
    expect(source, contains('Formatters.money(summary.actualAmount)'));
    expect(source, contains('Formatters.money(summary.remainingAmount.abs())'));
    expect(source, contains('não é saldo em conta'));
    expect(source, contains("ValueKey('plan-summary-usage-progress')"));
  });

  test('More menu retains destinations and version while improving style', () {
    final source = File('lib/features/shell/more_tools_sheet.dart')
        .readAsStringSync();
    expect(source, contains('TUDO EM UM LUGAR'));
    expect(source, contains("ValueKey('tools-compact-grid')"));
    expect(source, contains('tools-single-column'));
    expect(source, contains('tools-two-columns'));
    for (final key in [
      'tools-wallet', 'tools-goals', 'tools-diary', 'tools-profile',
      'tools-financial-ai', 'folego-visible-build-version',
    ]) {
      expect(source, contains(key));
    }
    for (var index = 0; index < 5; index++) {
      expect(source, contains('onSelected(\$index)'.replaceAll(
          '\$index', index.toString())));
    }
    expect(source, contains('minimumSize: const Size.fromHeight(52)'));
    expect(source, isNot(contains('BackdropFilter(')));
  });
}
