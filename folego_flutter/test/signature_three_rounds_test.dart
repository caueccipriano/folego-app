import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('round 1: visible release version is build-stamped, not guessed', () {
    final more = File('lib/features/shell/more_tools_sheet.dart')
        .readAsStringSync();
    final deploy = File('../.github/workflows/deploy-web.yml')
        .readAsStringSync();
    expect(more, contains("String.fromEnvironment('FOLEGO_RELEASE')"));
    expect(more, contains("ValueKey('folego-visible-build-version')"));
    expect(deploy, contains('--dart-define=FOLEGO_RELEASE='));
    expect(more, contains("ValueKey('tools-financial-ai')"));
    expect(more, contains("ValueKey('tools-profile')"));
  });

  test('round 1: only visible balances reveal the budget excess amount', () {
    final source = File('lib/features/home/home_mobile_summary_strip.dart')
        .readAsStringSync();
    expect(source, contains("ValueKey('home-budget-excess-amount')"));
    expect(source, contains('if (budgetExceeded && showTiles)'));
    expect(source, contains('if (ratio != null && !hidden)'));
    expect(source, contains(
      'snapshot.monthlyBudgetUsed - snapshot.monthlyBudgetPlanned'));
    expect(source, contains("ValueKey('home-mobile-budget')"));
  });

  test('round 2: movements retain financial amounts and interactive filters', () {
    final source =
        File('lib/features/transactions/transactions_screen_base.dart')
            .readAsStringSync();
    expect(source, contains("hintText: 'buscar lançamento'"));
    expect(source, contains('Semantics(\n                      header: true'));
    expect(source, contains("ValueKey('transaction-day-\$index')"));
    expect(source, contains('transactionDayLabel(item.occurredAt)'));
    expect(source, contains('onLoadMore()'));
    expect(source, contains("ValueKey('transaction-row-amount')"));
    expect(source, contains('Formatters.money(item.amount.abs())'));
    expect(source, contains('onTap: onOpen'));
    expect(source, contains('AppColors.positiveText(brightness)'));
    expect(source, contains('AppColors.expenseText(brightness)'));
  });

  test('round 3: planning highlights overruns without changing totals', () {
    final source = File('lib/features/plan/plan_screen_web2.dart')
        .readAsStringSync();
    expect(source, contains("'limites ultrapassados neste mês'"));
    expect(source, contains('summary.remainingAmount < 0'));
    expect(source, contains('progressColor.withValues(alpha: .52)'));
    expect(source, contains('Formatters.money(summary.remainingAmount.abs())'));
    expect(source, contains('summary.usageRatio.clamp(0.0, 1.0)'));
  });

  test('round 3: empty, error and loading use coherent accessible surfaces', () {
    for (final path in [
      'lib/shared/widgets/app_empty_state.dart',
      'lib/shared/widgets/app_error_state.dart',
      'lib/shared/widgets/app_loading_state.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, contains('FolegoColorTokens.of(context)'));
      expect(source, contains('MediaQuery.highContrastOf(context)'));
      expect(source, contains('tokens.borda'));
      expect(source, isNot(contains('BackdropFilter(')));
    }
  });
}
