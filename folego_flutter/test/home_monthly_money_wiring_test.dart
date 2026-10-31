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
  test('mobile Home prioritizes spendable before actions and attention cards', () {
    final source = File('lib/features/home/home_screen_base.dart').readAsStringSync();
    final start = source.indexOf('if (layout == AppLayoutSize.compact) ...[');
    final end = source.indexOf('] else if (layout == AppLayoutSize.medium)', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final mobile = source.substring(start, end);
    expect(mobile.indexOf('hero'), lessThan(mobile.indexOf('quickActions')));
    expect(mobile.indexOf('quickActions'), lessThan(mobile.indexOf('pulse')));
    expect(mobile.indexOf('pulse'), lessThan(mobile.indexOf('smartCheckin')));
    expect(mobile, contains("ValueKey('home-monthly-details')"));
    expect(mobile.indexOf('home-monthly-details'), lessThan(mobile.indexOf('monthlyMoney')));
    expect(mobile, contains('projectionInsight'));
    expect(mobile, contains('latestSection'));
    // Daily review was removed from the everyday Home in Fôlego 3.0.
    expect(mobile, isNot(contains('optionalReview')));
    expect(mobile.indexOf('home-monthly-details'), lessThan(mobile.indexOf('latestSection')));
  });
}

