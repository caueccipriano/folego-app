import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/monthly_money_summary.dart';
import 'package:folego/features/panorama/panorama_360_data.dart';
import 'package:folego/features/panorama/panorama_month_trend.dart';

MonthlyMoneySummary month(
  int year,
  int number, {
  double income = 0,
  double expenses = 0,
  double cardPayment = 0,
  double transfer = 0,
}) =>
    MonthlyMoneySummary.fromJson({
      'period_month':
          '${year.toString().padLeft(4, '0')}-'
          '${number.toString().padLeft(2, '0')}-01',
      'income_amount': income,
      'competence_net': expenses,
      // Deliberately high non-economic cash activity must never inflate
      // competence expenses or economic result.
      'movement_card_payments': cardPayment,
      'movement_transfers': transfer,
      'cash_outflow': cardPayment + transfer,
    });

void main() {
  test('last two completed months compare only recorded economic movements',
      () {
    final trend = PanoramaClosedMonthTrend.tryFrom(
      earlier: month(2026, 7,
          income: 2400,
          expenses: 650,
          cardPayment: 10000,
          transfer: 3000),
      later: month(2026, 8,
          income: 2600,
          expenses: 900,
          cardPayment: 25000,
          transfer: 5000),
      referenceDate: DateTime(2026, 9, 29),
    );
    expect(trend, isNotNull);
    expect(trend!.earlierResult, 1750);
    expect(trend.laterResult, 1700);
    expect(trend.incomeChange, 200);
    expect(trend.expenseChange, 250);
    expect(trend.economicResultChange, -50);
    expect(trend.expenseChange, isNot(25000 - 10000));
  });

  test('year boundary uses November and December before January', () {
    final trend = PanoramaClosedMonthTrend.tryFrom(
      earlier: month(2026, 11, income: 700),
      later: month(2026, 12, income: 900),
      referenceDate: DateTime(2027, 1, 12),
    );
    expect(trend?.incomeChange, 200);
  });

  test('does not compare incomplete current month with full prior month', () {
    expect(
      PanoramaClosedMonthTrend.tryFrom(
        earlier: month(2026, 8, income: 1100),
        later: month(2026, 9, income: 500),
        referenceDate: DateTime(2026, 9, 29),
      ),
      isNull,
    );
  });

  test('mismatched or skipped periods fail closed instead of false trend', () {
    expect(
      PanoramaClosedMonthTrend.tryFrom(
        earlier: month(2026, 6, income: 100),
        later: month(2026, 8, income: 800),
        referenceDate: DateTime(2026, 9, 29),
      ),
      isNull,
    );
  });

  test('unavailable earlier or later is unknown, not a zero month', () {
    final july = month(2026, 7, expenses: 300);
    final august = month(2026, 8, expenses: 500);
    expect(
      PanoramaClosedMonthTrend.tryFrom(
        earlier: july,
        later: null,
        referenceDate: DateTime(2026, 9),
      ),
      isNull,
    );
    expect(
      PanoramaClosedMonthTrend.tryFrom(
        earlier: null,
        later: august,
        referenceDate: DateTime(2026, 9),
      ),
      isNull,
    );
    final partial = Panorama360Data(
      closedEarlier: july,
      referenceDate: DateTime(2026, 9),
    );
    expect(partial.closedMonthTrend, isNull);
    expect(partial.hasAnyData, isFalse);
  });

  test('two verified empty months are distinguishable from failed requests',
      () {
    final trend = PanoramaClosedMonthTrend.tryFrom(
      earlier: month(2026, 7),
      later: month(2026, 8),
      referenceDate: DateTime(2026, 9),
    );
    expect(trend?.bothMonthsWithoutRecordedMovements, isTrue);
    expect(
      Panorama360Data(
        closedEarlier: month(2026, 7),
        closedLater: month(2026, 8),
        referenceDate: DateTime(2026, 9),
      ).hasAnyData,
      isTrue,
    );
  });

  test('net refunds may produce a negative recorded economic delta', () {
    final trend = PanoramaClosedMonthTrend.tryFrom(
      earlier: month(2026, 7, income: 1000, expenses: 300),
      later: month(2026, 8, income: 1000, expenses: -100),
      referenceDate: DateTime(2026, 9),
    );
    expect(trend?.expenseChange, -400);
    expect(trend?.laterResult, 1100);
  });

  test('a cross-space late monthly response cannot bypass period checks', () {
    final payload = Panorama360Data(
      closedEarlier: month(2026, 7, income: 1000),
      closedLater: month(2026, 12, income: 10000),
      referenceDate: DateTime(2026, 9),
    );
    expect(payload.closedMonthTrend, isNull);
  });
}
