import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/budget_overview_item.dart';
import 'package:folego/data/models/financial_goal.dart';
import 'package:folego/data/models/folego_snapshot.dart';
import 'package:folego/data/models/monthly_money_summary.dart';
import 'package:folego/data/models/upcoming_events.dart';
import 'package:folego/features/panorama/panorama_360_data.dart';

BudgetOverviewItem budget({
  required String id,
  String? parent,
  required double planned,
  required double actual,
}) => BudgetOverviewItem(
      categoryId: id,
      categoryName: 'categoria fictícia',
      parentId: parent,
      essential: false,
      plannedAmount: planned,
      actualAmount: actual,
      remainingAmount: planned - actual,
      warningThreshold: .70,
      criticalThreshold: .90,
      usageRatio: planned == 0 ? 0 : actual / planned,
      status: 'ok',
    );

FinancialGoal goal(String id, GoalStatus status) => FinancialGoal(
      id: id,
      spaceId: 'test-space-A',
      name: 'meta fictícia',
      target: 1000,
      icon: GoalIcon.piggyBank,
      status: status,
      currentAmount: 200,
      createdAt: DateTime(2026, 1),
      updatedAt: DateTime(2026, 1),
    );

UpcomingEvent event(
  String id, {
  required DateTime due,
  required String direction,
  required String status,
}) => UpcomingEvent(
      id: id,
      source: 'recurring',
      name: 'conta de teste',
      dueDate: due,
      amount: 100,
      direction: direction,
      status: status,
    );

FolegoSnapshot fakeSnapshot() => FolegoSnapshot(
      asOfDate: DateTime(2026, 9, 29),
      nextIncomeDate: DateTime(2026, 10, 1),
      nextIncomeAmount: 2000,
      daysUntilIncome: 2,
      liquidBalance: 1000,
      protectedBalance: 300,
      mandatoryOutflowsUntilIncome: 400,
      cashHeadroom: 300,
      monthlyBudgetPlanned: 800,
      monthlyBudgetUsed: 680,
      economicHeadroom: 120,
      spendablePool: 120,
      dailyFolego: 60,
      shortfall: 0,
      limitingFactor: 'budget',
      status: 'ok',
      budgetConfigured: true,
      needsIncomeSetup: false,
    );

void main() {
  test('missing backend results remain unknown, never fabricated zeros', () {
    const data = Panorama360Data();
    expect(data.hasAnyData, isFalse);
    expect(data.budgetSummary, isNull);
    expect(data.activeGoals, isNull);
    expect(data.pendingOutflows(), isNull);
  });

  test('budget totals include only parent categories, never child twice', () {
    final data = Panorama360Data(
      budgets: [
        budget(id: 'parent', planned: 1000, actual: 450),
        budget(id: 'child', parent: 'parent', planned: 400, actual: 250),
      ],
    );
    expect(data.budgetSummary?.plannedAmount, 1000);
    expect(data.budgetSummary?.actualAmount, 450);
    expect(data.budgetSummary?.remainingAmount, 550);
  });

  test('loaded empty budgets and unavailable budgets are different', () {
    expect(const Panorama360Data(budgets: []).hasAnyData, isTrue);
    expect(const Panorama360Data(budgets: []).budgetSummary?.plannedAmount, 0);
    expect(const Panorama360Data().budgetSummary, isNull);
  });

  test('income minus competence spending excludes separate cash movements', () {
    final monthly = MonthlyMoneySummary.fromJson({
      'period_month': '2026-09-01',
      'income_amount': 2000,
      'competence_net': 600,
      'cash_outflow': 1200,
      'movement_card_payments': 600,
      'movement_transfers': 100,
    });
    const data = Panorama360Data();
    expect(data.monthlyMoney, isNull);
    expect(monthly.economicResult, 1400);
    expect(monthly.nonExpenseCashOutflows, 700);
    expect(monthly.economicResult, isNot(800));
  });

  test('safe-to-spend always uses canonical snapshot without re-subtracting bills',
      () {
    final snapshot = fakeSnapshot();
    final data = Panorama360Data(snapshot: snapshot);
    expect(data.snapshot?.spendablePool, 120);
    expect(data.snapshot?.protectedBalance, 300);
    expect(data.snapshot?.mandatoryOutflowsUntilIncome, 400);
    expect(data.snapshot?.spendablePool,
        isNot(snapshot.liquidBalance - snapshot.mandatoryOutflowsUntilIncome));
  });

  test('only active financial goals are shown, never promoted to bank balance',
      () {
    final data = Panorama360Data(goals: [
      goal('active', GoalStatus.active),
      goal('completed', GoalStatus.completed),
      goal('archived', GoalStatus.archived),
    ]);
    expect(data.activeGoals?.map((g) => g.id), ['active']);
    expect(data.activeGoals?.single.currentAmount, 200);
    expect(data.snapshot, isNull);
  });

  test('upcoming preview only shows current pending outflows in due date order',
      () {
    final data = Panorama360Data(upcoming: [
      event('future', due: DateTime(2026, 10, 2),
          direction: 'expense', status: 'pending'),
      event('yesterday', due: DateTime(2026, 9, 28),
          direction: 'expense', status: 'pending'),
      event('income', due: DateTime(2026, 9, 30),
          direction: 'income', status: 'pending'),
      event('paid', due: DateTime(2026, 9, 30),
          direction: 'expense', status: 'paid'),
      event('today', due: DateTime(2026, 9, 29),
          direction: 'expense', status: 'pending'),
    ]);
    expect(
      data.pendingOutflows(now: DateTime(2026, 9, 29))!.map((x) => x.id),
      ['today', 'future'],
    );
  });
}
