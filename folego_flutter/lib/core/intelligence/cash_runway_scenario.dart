import 'cash_runway.dart';

/// Read-only what-if scenario. Never persists or schedules an expense.
class CashRunwayScenario {
  const CashRunwayScenario({required this.original, required this.simulated,
    required this.differenceAtPayday});
  final CashRunway original;
  final CashRunway simulated;
  final double differenceAtPayday;

  static CashRunwayScenario compare({
    required DateTime asOf,
    required DateTime nextPayday,
    required double verifiedOpeningBalance,
    required List<DatedCashEvent> scheduledEvents,
    required DatedCashEvent hypotheticalExpense,
    double protectedReserve = 0,
  }) {
    if (hypotheticalExpense.amount >= 0 ||
        !hypotheticalExpense.amount.isFinite) {
      throw ArgumentError('Scenario must be a finite expense');
    }
    final original = CashRunway.calculate(
      asOf: asOf, nextPayday: nextPayday,
      verifiedOpeningBalance: verifiedOpeningBalance,
      confirmedEvents: scheduledEvents,
      protectedReserve: protectedReserve,
    );
    final simulated = CashRunway.calculate(
      asOf: asOf, nextPayday: nextPayday,
      verifiedOpeningBalance: verifiedOpeningBalance,
      confirmedEvents: [...scheduledEvents, hypotheticalExpense],
      protectedReserve: protectedReserve,
    );
    return CashRunwayScenario(
      original: original, simulated: simulated,
      differenceAtPayday: simulated.balanceAtPayday - original.balanceAtPayday,
    );
  }
}
