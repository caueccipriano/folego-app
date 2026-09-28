import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/intelligence/budget_pace.dart';

void main() {
  test('uses actual month length and explains overspend', () {
    final pace = BudgetPace.forDate(
      used: 600, limit: 1000, asOf: DateTime(2026, 9, 15),
    );
    expect(pace.dailyAverage, 40);
    expect(pace.projectedMonthSpending, 1200);
    expect(pace.projectedDifference, 200);
    expect(pace.projectedOverLimit, isTrue);
    expect(pace.canEstimate, isTrue);
  });
  test('does not estimate from fewer than seven elapsed days', () {
    final pace = BudgetPace.forDate(
      used: 150, limit: 1000, asOf: DateTime(2026, 2, 4),
    );
    expect(pace.daysInMonth, 28);
    expect(pace.canEstimate, isFalse);
  });
  test('does not estimate without a configured limit', () {
    final pace = BudgetPace.forDate(
      used: 200, limit: 0, asOf: DateTime(2026, 9, 20),
    );
    expect(pace.canEstimate, isFalse);
    expect(pace.projectedOverLimit, isFalse);
  });
}
