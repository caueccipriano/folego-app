import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/monthly_money_summary.dart';
import 'package:folego/features/panorama/panorama_360_data.dart';
import 'package:folego/features/panorama/panorama_360_trends.dart';

MonthlyMoneySummary _month(
  String period, {
  required num income,
  required num economicExpenses,
  num cashMovement = 0,
}) => MonthlyMoneySummary.fromJson(<String, dynamic>{
      'period_month': period,
      'income_amount': income,
      'competence_net': economicExpenses,
      'cash_outflow': cashMovement,
      'movement_card_payments': cashMovement,
    });

void main() {
  test('three canonical monthly totals are chronological across the year', () {
    final trend = Panorama360Trend(
      currentMonth: DateTime(2027, 1),
      current: _month('2027-01-01', income: 3000, economicExpenses: 800),
      previous: <MonthlyMoneySummary?>[
        _month('2026-12-01', income: 2200, economicExpenses: 900),
        _month('2026-11-01', income: 2000, economicExpenses: 1100),
      ],
    );
    expect(trend.months.map((month) => month.monthLabel),
        <String>['nov/2026', 'dez/2026', 'jan/2027']);
    expect(trend.months.map((month) => month.income),
        <double?>[2000, 2200, 3000]);
    expect(trend.months.map((month) => month.expenses),
        <double?>[1100, 900, 800]);
    expect(trend.expenseChange, -100);
    expect(trend.resultChange, 900);
    expect(trend.verifiedCount, 3);
    expect(trend.complete, isTrue);
  });

  test('card payments and own transfers are not counted twice as expenses', () {
    final current = _month(
      '2026-09-01',
      income: 2500,
      economicExpenses: 700,
      cashMovement: 1200,
    );
    final trend = Panorama360Trend(
      currentMonth: DateTime(2026, 9),
      current: current,
      previous: const <MonthlyMoneySummary?>[null, null],
    );
    expect(trend.months.last.expenses, 700);
    expect(trend.months.last.economicResult, 1800);
    expect(trend.months.last.expenses, isNot(current.cashOutflow));
    expect(trend.expenseChange, isNull);
  });

  test('failed previous query stays unavailable instead of displaying zero', () {
    final trend = Panorama360Trend(
      currentMonth: DateTime(2026, 9),
      current: _month('2026-09-01', income: 2000, economicExpenses: 400),
      previous: <MonthlyMoneySummary?>[
        null,
        _month('2026-07-01', income: 1000, economicExpenses: 600),
      ],
    );
    expect(trend.hasAnyVerifiedMonth, isTrue);
    expect(trend.verifiedCount, 2);
    expect(trend.complete, isFalse);
    expect(trend.months[1].available, isFalse);
    expect(trend.months[1].expenses, isNull);
    expect(trend.expenseChange, isNull);
    expect(trend.resultChange, isNull);
  });

  test('a legitimate reported zero is different from an unavailable month', () {
    final trend = Panorama360Trend(
      currentMonth: DateTime(2026, 9),
      current: _month('2026-09-01', income: 0, economicExpenses: 0),
      previous: <MonthlyMoneySummary?>[
        _month('2026-08-01', income: 0, economicExpenses: 0),
        null,
      ],
    );
    expect(trend.months.last.available, isTrue);
    expect(trend.months.last.expenses, 0);
    expect(trend.months.first.expenses, isNull);
    expect(trend.expenseChange, 0);
  });

  test('mismatched backend months fail closed as unknown', () {
    final trend = Panorama360Trend(
      currentMonth: DateTime(2026, 9),
      current: _month('2026-08-01', income: 5000, economicExpenses: 200),
      previous: <MonthlyMoneySummary?>[
        _month('2026-09-01', income: 4000, economicExpenses: 500),
        null,
      ],
    );
    expect(trend.hasAnyVerifiedMonth, isFalse);
    expect(trend.months.every((month) => !month.available), isTrue);
    expect(trend.expenseChange, isNull);
  });

  test('full Panorama can be useful if only historical months succeed', () {
    final data = Panorama360Data(
      trendReferenceMonth: DateTime(2026, 9),
      previousMonthly: <MonthlyMoneySummary?>[
        null,
        _month('2026-07-01', income: 1000, economicExpenses: 200),
      ],
    );
    expect(data.hasAnyData, isTrue);
    expect(data.monthlyMoney, isNull);
    expect(data.monthlyTrend.verifiedCount, 1);
    expect(data.monthlyTrend.months.last.available, isFalse);
  });

  test('expense comparison is descriptive, not an invented cash forecast', () {
    final trend = Panorama360Trend(
      currentMonth: DateTime(2026, 9),
      current: _month('2026-09-01', income: 3000, economicExpenses: 900),
      previous: <MonthlyMoneySummary?>[
        _month('2026-08-01', income: 3500, economicExpenses: 600),
        null,
      ],
    );
    expect(trend.expenseChange, 300);
    expect(trend.resultChange, -800);
    expect(trend.months.last.economicResult, 2100);
  });
}
