import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/financial_goal.dart';

void main() {
  group('FinancialGoal progress', () {
    test('0%', () {
      final goal = _goal(current: 0, target: 1000);
      expect(goal.progressPercent, 0);
      expect(goal.visualProgress, 0);
    });

    test('partial', () {
      final goal = _goal(current: 240, target: 1000);
      expect(goal.progressPercent, 24);
      expect(goal.visualProgress, closeTo(.24, .0001));
      expect(goal.remaining, 760);
    });

    test('100%', () {
      final goal = _goal(current: 1000, target: 1000);
      expect(goal.progressPercent, 100);
      expect(goal.visualProgress, 1);
      expect(goal.remaining, 0);
    });

    test('above 100% clamps visual progress but preserves amount', () {
      final goal = _goal(current: 1250, target: 1000);
      expect(goal.currentAmount, 1250);
      expect(goal.progress, 1.25);
      expect(goal.visualProgress, 1);
      expect(goal.progressPercent, 100);
    });
  });

  test('target date is optional', () {
    final withoutDate = FinancialGoal.fromJson(_json(targetDate: null));
    final withDate = FinancialGoal.fromJson(_json(targetDate: '2027-01-31'));

    expect(withoutDate.targetDate, isNull);
    expect(withDate.targetDate, DateTime(2027, 1, 31));
  });

  test('goal icon keys round-trip through stable database keys', () {
    for (final icon in GoalIcon.values) {
      expect(GoalIcon.fromKey(icon.key), icon);
    }
    expect(GoalIcon.fromKey('unknown'), GoalIcon.piggyBank);
  });

  test('active total excludes completed and archived goals', () {
    final goals = [
      _goal(current: 400, target: 1000),
      _goal(current: 200, target: 500),
      _goal(current: 800, target: 800, status: GoalStatus.completed),
      _goal(current: 90, target: 100, status: GoalStatus.archived),
    ];

    expect(totalActiveGoalAmount(goals), 600);
  });

  test('completed status remains explicit in the model', () {
    final goal = _goal(
      current: 1000,
      target: 1000,
      status: GoalStatus.completed,
    );
    expect(goal.isCompleted, isTrue);
    expect(goal.isActive, isFalse);
  });

  test('contributions sort newest first', () {
    final old = _contribution('old', DateTime(2026, 8, 30));
    final newest = _contribution('new', DateTime(2026, 9, 14));
    final middle = _contribution('middle', DateTime(2026, 9, 1));

    final sorted = sortGoalContributionsNewestFirst([old, newest, middle]);
    expect(sorted.map((item) => item.id), ['new', 'middle', 'old']);
  });
}

FinancialGoal _goal({
  required num current,
  required num target,
  GoalStatus status = GoalStatus.active,
}) {
  return FinancialGoal(
    id: 'goal',
    spaceId: 'space',
    name: 'Entrada do carro',
    target: target,
    icon: GoalIcon.car,
    status: status,
    currentAmount: current,
    createdAt: DateTime(2026, 9, 1),
    updatedAt: DateTime(2026, 9, 1),
  );
}

GoalContribution _contribution(String id, DateTime date) {
  return GoalContribution(
    id: id,
    goalId: 'goal',
    spaceId: 'space',
    amount: 100,
    contributedAt: date,
    createdAt: date,
    updatedAt: date,
  );
}

Map<String, dynamic> _json({String? targetDate}) {
  return {
    'id': 'goal',
    'space_id': 'space',
    'name': 'Viagem',
    'target': 5000,
    'target_date': targetDate,
    'icon_key': 'plane',
    'status': 'active',
    'created_at': '2026-09-01T12:00:00Z',
    'updated_at': '2026-09-01T12:00:00Z',
    'completed_at': null,
    'goal_contributions': <Map<String, dynamic>>[],
  };
}
