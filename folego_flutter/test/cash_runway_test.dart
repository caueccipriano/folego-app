import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/intelligence/cash_runway.dart';

void main() {
  test('tracks dated bills and identifies first negative day', () {
    final result = CashRunway.calculate(
      asOf: DateTime(2026, 9, 27), nextPayday: DateTime(2026, 9, 30),
      verifiedOpeningBalance: 200, protectedReserve: 20,
      confirmedEvents: [
        DatedCashEvent(date: DateTime(2026, 9, 28), amount: -250, label: 'Bill'),
        DatedCashEvent(date: DateTime(2026, 9, 29), amount: 100, label: 'Income'),
      ],
    );
    expect(result.firstNegativeDay, DateTime(2026, 9, 28));
    expect(result.balanceAtPayday, 50);
    expect(result.discretionaryDailyReference, 0);
    expect(result.days.length, 3);
  });
  test('later income cannot justify spending before an earlier bill', () {
    final result = CashRunway.calculate(
      asOf: DateTime(2026, 9, 27),
      nextPayday: DateTime(2026, 10, 1),
      verifiedOpeningBalance: 100,
      confirmedEvents: [
        DatedCashEvent(date: DateTime(2026, 9, 28),
            amount: -150, label: 'Earlier bill'),
        DatedCashEvent(date: DateTime(2026, 9, 30),
            amount: 300, label: 'Later income'),
      ],
    );
    expect(result.balanceAtPayday, 250);
    expect(result.firstNegativeDay, DateTime(2026, 9, 28));
    expect(result.discretionaryDailyReference, 0);
  });
  test('excludes already posted transactions and next payday income', () {
    final result = CashRunway.calculate(
      asOf: DateTime(2026, 9, 27), nextPayday: DateTime(2026, 9, 29),
      verifiedOpeningBalance: 100,
      confirmedEvents: [
        DatedCashEvent(date: DateTime(2026, 9, 26), amount: -80, label: 'Paid'),
        DatedCashEvent(date: DateTime(2026, 9, 29), amount: 1000, label: 'Payday'),
      ],
    );
    expect(result.balanceAtPayday, 100);
    expect(result.discretionaryDailyReference, 50);
  });
  test('rejects unverified non-finite opening balance', () {
    expect(() => CashRunway.calculate(
      asOf: DateTime(2026, 9, 27), nextPayday: DateTime(2026, 9, 29),
      verifiedOpeningBalance: double.nan, confirmedEvents: [],
    ), throwsArgumentError);
  });
}
