import 'package:flutter_test/flutter_test.dart';

import 'package:folego/data/models/monthly_money_summary.dart';
import 'package:folego/features/home/closed_month_evolution.dart';

void main() {
  MonthlyMoneySummary month(String date, double spend, double income) =>
    MonthlyMoneySummary.fromJson({
      'period_month': date,
      'spending_net': spend,
      'income_amount': income,
      'competence_net': spend,
    });

  test('compares two complete calendar months without current-month data', () {
    final comparison = ClosedMonthEvolution(
      latest: month('2026-09-01', 900, 2000),
      previous: month('2026-08-01', 1200, 1800),
    );
    expect(comparison.spendingChange, -300);
    expect(comparison.spendingPercent, closeTo(-25, .0001));
    expect(comparison.incomeChange, 200);
    expect(comparison.resultChange, 500);
  });

  test('never divides by zero in relative change', () {
    final comparison = ClosedMonthEvolution(
      latest: month('2026-09-01', 100, 300),
      previous: month('2026-08-01', 0, 300),
    );
    expect(comparison.spendingPercent, isNull);
    expect(comparison.spendingChange, 100);
  });
}
