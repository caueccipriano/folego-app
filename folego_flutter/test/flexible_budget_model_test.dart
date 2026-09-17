import 'package:flutter_test/flutter_test.dart';

import 'package:folego/data/models/budget_overview_item.dart';

void main() {
  group('FlexibleBudgetOverview', () {
    test('parses explicit exceeded budget', () {
      final overview = FlexibleBudgetOverview.fromJson({
        'period_month': '2026-09-01',
        'configured': true,
        'explicit_limit': true,
        'limit_amount': 1652.80,
        'used_amount': 2945,
        'remaining_amount': 0,
        'exceeded_amount': 1292.20,
        'category_limits_total': 1262.80,
      });

      expect(overview.explicitLimit, isTrue);
      expect(overview.isExceeded, isTrue);
      expect(overview.exceededAmount, closeTo(1292.20, .001));
      expect(overview.progressState, BudgetProgressState.exceeded);
      expect(overview.categoryLimitsTotal, closeTo(1262.80, .001));
    });

    test('keeps category fallback distinguishable from explicit global cap', () {
      final overview = FlexibleBudgetOverview.fromJson({
        'period_month': '2026-10-01',
        'configured': true,
        'explicit_limit': false,
        'limit_amount': 900,
        'used_amount': 250,
        'remaining_amount': 650,
        'exceeded_amount': 0,
        'category_limits_total': 900,
      });

      expect(overview.explicitLimit, isFalse);
      expect(overview.configured, isTrue);
      expect(overview.remainingAmount, 650);
      expect(overview.progressState, BudgetProgressState.comfortable);
    });
  });
}
