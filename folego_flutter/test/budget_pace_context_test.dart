import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/features/plan/budget_pace_context.dart';

void main() {
  test('current month pace is read-only, grounded and handles month lengths', () {
    final pace = currentMonthBudgetPace(
      periodMonth: DateTime(2026, 10, 1),
      today: DateTime(2026, 10, 14),
      plannedAmount: 1000,
      usedAmount: 700,
    );
    expect(pace, isNotNull);
    expect(pace!.elapsedDays, 14);
    expect(pace.daysInMonth, 31);
    expect(pace.elapsedPercent, 45);
    expect(pace.usedPercent, 70);
  });

  test('february leap year and over budget are shown without a fake forecast', () {
    final pace = currentMonthBudgetPace(
      periodMonth: DateTime(2028, 2, 1),
      today: DateTime(2028, 2, 29),
      plannedAmount: 500,
      usedAmount: 600,
    )!;
    expect(pace.daysInMonth, 29);
    expect(pace.elapsedPercent, 100);
    expect(pace.usedPercent, 120);
  });

  test('past/future months and missing budgets never receive pace claims', () {
    final today = DateTime(2026, 10, 14);
    for (final month in [DateTime(2026, 9), DateTime(2026, 11)]) {
      expect(
        currentMonthBudgetPace(
          periodMonth: month, today: today,
          plannedAmount: 500, usedAmount: 250,
        ),
        isNull,
      );
    }
    expect(currentMonthBudgetPace(
      periodMonth: today, today: today, plannedAmount: 0, usedAmount: 20,
    ), isNull);
    expect(currentMonthBudgetPace(
      periodMonth: today, today: today,
      plannedAmount: double.nan, usedAmount: 20,
    ), isNull);
  });

  test('Plan UI explicitly warns pace is not a future prediction', () {
    final source = File('lib/features/plan/plan_screen_web2.dart')
        .readAsStringSync();
    expect(source, contains("ValueKey('plan-budget-pace-context')"));
    expect(source, contains('não é previsão'));
  });
}
