import 'cash_runway.dart';
import 'cash_runway_scenario.dart';

/// A hypothetical contribution paid today, never saved to the database.
/// Use only when the user has selected a goal and confirmed its amount.
class GoalContributionPreview {
  const GoalContributionPreview({
    required this.before,
    required this.after,
    required this.contribution,
    required this.firstNewShortfall,
  });
  final CashRunway before;
  final CashRunway after;
  final double contribution;
  final DateTime? firstNewShortfall;

  static GoalContributionPreview simulate({
    required CashRunwayPreparationInput input,
    required double contribution,
  }) {
    if (!contribution.isFinite || contribution <= 0) {
      throw ArgumentError.value(contribution, 'contribution');
    }
    final result = CashRunwayScenario.compare(
      asOf: input.asOf,
      nextPayday: input.nextIncomeDate,
      verifiedOpeningBalance: input.openingBalance,
      scheduledEvents: input.events,
      protectedReserve: input.protectedReserve,
      hypotheticalExpense: DatedCashEvent(
        date: input.asOf,
        amount: -contribution,
        label: 'Hypothetical goal contribution',
      ),
    );
    DateTime? firstNewShortfall;
    for (var i = 0; i < result.simulated.days.length; i++) {
      final after = result.simulated.days[i];
      final before = result.original.days[i];
      if (after.closingBalance < 0 && before.closingBalance >= 0) {
        firstNewShortfall = after.date;
        break;
      }
    }
    return GoalContributionPreview(
      before: result.original,
      after: result.simulated,
      contribution: contribution,
      firstNewShortfall: firstNewShortfall,
    );
  }
}

class CashRunwayPreparationInput {
  const CashRunwayPreparationInput({
    required this.asOf,
    required this.nextIncomeDate,
    required this.openingBalance,
    required this.events,
    this.protectedReserve = 0,
  });
  final DateTime asOf;
  final DateTime nextIncomeDate;
  final double openingBalance;
  final List<DatedCashEvent> events;
  final double protectedReserve;
}
