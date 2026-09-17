import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Home uses canonical monthly money summary instead of legacy event totals', () {
    final source = File(
      'lib/features/home/home_screen_base.dart',
    ).readAsStringSync();

    expect(source, contains('getMonthlyMoneySummary'));
    expect(source, contains('HomeMonthlyMoneyCard'));
    expect(source, isNot(contains('getHomeExpenseTransactions')));
    expect(source, isNot(contains('buildHomeExpenseBreakdown(')));
  });
}
