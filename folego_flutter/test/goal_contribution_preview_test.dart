import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/intelligence/cash_runway.dart';
import 'package:folego/core/intelligence/goal_contribution_preview.dart';

void main() {
  test('goal contribution highlights only newly introduced shortfall', () {
    final preview = GoalContributionPreview.simulate(
      input: CashRunwayPreparationInput(
        asOf: DateTime(2026, 9, 27),
        nextIncomeDate: DateTime(2026, 9, 30),
        openingBalance: 400,
        events: [
          DatedCashEvent(date: DateTime(2026, 9, 28),
            amount: -250, label: 'Bill'),
        ],
      ),
      contribution: 200,
    );
    expect(preview.before.balanceAtPayday, 150);
    expect(preview.after.balanceAtPayday, -50);
    expect(preview.firstNewShortfall, DateTime(2026, 9, 28));
  });

  test('rejects invalid contribution', () {
    expect(() => GoalContributionPreview.simulate(
      input: CashRunwayPreparationInput(
        asOf: DateTime(2026, 9, 27),
        nextIncomeDate: DateTime(2026, 9, 30),
        openingBalance: 400, events: [],
      ),
      contribution: -1,
    ), throwsArgumentError);
  });
}
