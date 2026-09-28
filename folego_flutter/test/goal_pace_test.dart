import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/intelligence/goal_pace.dart';
import 'package:folego/data/models/financial_goal.dart';

FinancialGoal goal({DateTime? deadline, num target = 1200, num saved = 600,
  GoalStatus status = GoalStatus.active}) => FinancialGoal(
  id: '1', spaceId: 'space', name: 'Emergency fund', target: target,
  targetDate: deadline, icon: GoalIcon.piggyBank, status: status,
  currentAmount: saved, createdAt: DateTime(2026, 1),
  updatedAt: DateTime(2026, 9),
);

void main() {
  test('calculates monthly contribution including current month', () {
    final pace = GoalPace.forGoal(
      goal(deadline: DateTime(2026, 11, 30)), DateTime(2026, 9, 27),
    )!;
    expect(pace.monthsRemaining, 3);
    expect(pace.remaining, 600);
    expect(pace.monthlyContribution, 200);
  });
  test('does not suggest amounts without future deadline or remaining target', () {
    expect(GoalPace.forGoal(goal(), DateTime(2026, 9, 27)), isNull);
    expect(GoalPace.forGoal(
      goal(deadline: DateTime(2026, 8)), DateTime(2026, 9, 27),
    ), isNull);
    expect(GoalPace.forGoal(
      goal(deadline: DateTime(2026, 11), saved: 1200), DateTime(2026, 9, 27),
    ), isNull);
  });
}
