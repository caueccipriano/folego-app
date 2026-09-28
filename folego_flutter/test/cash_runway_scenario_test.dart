import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/intelligence/cash_runway.dart';
import 'package:folego/core/intelligence/cash_runway_scenario.dart';

void main() {
  test('what-if expense changes balance without modifying original events', () {
    final events = <DatedCashEvent>[
      DatedCashEvent(date: DateTime(2026, 9, 28), amount: -50, label: 'Bill'),
    ];
    final result = CashRunwayScenario.compare(
      asOf: DateTime(2026, 9, 27), nextPayday: DateTime(2026, 9, 30),
      verifiedOpeningBalance: 500, scheduledEvents: events,
      hypotheticalExpense: DatedCashEvent(
        date: DateTime(2026, 9, 29), amount: -200, label: 'What if',
      ),
    );
    expect(result.original.balanceAtPayday, 450);
    expect(result.simulated.balanceAtPayday, 250);
    expect(result.differenceAtPayday, -200);
    expect(events.length, 1);
  });
  test('rejects invalid hypothetical income', () {
    expect(() => CashRunwayScenario.compare(
      asOf: DateTime(2026, 9, 27), nextPayday: DateTime(2026, 9, 30),
      verifiedOpeningBalance: 500, scheduledEvents: [],
      hypotheticalExpense: DatedCashEvent(
        date: DateTime(2026, 9, 29), amount: 200, label: 'Not an expense',
      ),
    ), throwsArgumentError);
  });
}
