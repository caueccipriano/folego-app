import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/automation_rule.dart';
import 'package:folego/data/models/category_item.dart';
import 'package:folego/data/models/folego_snapshot.dart';
import 'package:folego/data/models/projection_model.dart';
import 'package:folego/data/models/transaction_item.dart';
import 'package:folego/features/home/home_financial_hero.dart';
import 'package:folego/features/transactions/transaction_classification_inbox.dart';

void main() {
  FolegoSnapshot snapshot({
    int? days = 6, DateTime? payday,
    double spendable = 0, double shortfall = 0,
    String factor = 'cash', bool needIncome = false,
  }) => FolegoSnapshot(
    asOfDate: DateTime(2026, 10, 9),
    nextIncomeDate: needIncome ? null : (payday ?? DateTime(2026, 10, 15)),
    nextIncomeAmount: needIncome ? 0 : 6000,
    daysUntilIncome: needIncome ? null : days,
    liquidBalance: 120,
    protectedBalance: 0,
    mandatoryOutflowsUntilIncome: 150,
    cashHeadroom: 0,
    monthlyBudgetPlanned: 1000,
    monthlyBudgetUsed: 1000,
    economicHeadroom: 0,
    spendablePool: spendable,
    dailyFolego: spendable > 0 ? 10 : 0,
    shortfall: shortfall,
    limitingFactor: factor,
    status: 'atencao',
    budgetConfigured: true,
    needsIncomeSetup: needIncome,
  );

  test('next financial step prioritizes missing income and shortfall', () {
    expect(homeNextStep(snapshot(needIncome: true)), contains('cadastre'));
    expect(homeNextStep(snapshot(shortfall: 10)), contains('vencimentos'));
    expect(homeNextStep(snapshot(factor: 'budget')), contains('flexível'));
    expect(homeNextStep(snapshot()), contains('contas'));
    expect(homeNextStep(snapshot(spendable: 100)), contains('gastos diários'));
  });

  test('debt amortization simulates only a one-off cash outflow', () {
    final adjustment = buildExtraDebtPaymentSimulation(
      id: 'extra-1', debtName: 'Empréstimo pessoal',
      amount: 600, paymentDate: DateTime(2026, 11, 2),
    );
    expect(adjustment.component, 'other_outflow');
    expect(adjustment.frequency, 'once');
    expect(adjustment.amountDelta, 600);
    expect(adjustment.toJson()['category_name'], 'dívidas');
    expect(() => buildExtraDebtPaymentSimulation(
      id: 'bad', debtName: 'x', amount: -200,
      paymentDate: DateTime(2026, 11, 2),
    ), throwsArgumentError);
  });

  TransactionItem tx({String name = 'Uber Trip', String type = 'expense',
    String? account = 'account-1'}) => TransactionItem(
    id: 'event-1', eventType: type, description: name, amount: 35,
    occurredAt: DateTime(2026, 10, 9), status: 'confirmed',
    source: 'manual', accountId: account,
  );
  AutomationRule rule({
    String name = 'Uber Trip', AutomationMatchType match = AutomationMatchType.equals,
    AutomationSourceScope scope = AutomationSourceScope.account,
    String? account = 'account-1', AutomationDirection direction = AutomationDirection.debit,
  }) => AutomationRule(
    id: 'rule-1', spaceId: 'space-1', name: 'uber', active: true,
    matchField: AutomationMatchField.description, matchType: match,
    matchValue: name, sourceScope: scope, sourceAccountId: account,
    direction: direction, categoryId: 'travel',
    actionType: AutomationActionType.reviewCategory,
    executionMode: AutomationExecutionMode.review, priority: 1,
  );
  const categories = [
    CategoryItem(id: 'travel', name: 'transporte', essential: false),
  ];

  test('only exact user-reviewed matching rule is offered as suggestion', () {
    expect(reviewedCategorySuggestion(
      item: tx(name: ' UBER  TRIP '), rules: [rule()],
      categories: categories,
    )?.id, 'travel');
    expect(reviewedCategorySuggestion(
      item: tx(name: 'Uber Eats'), rules: [rule()],
      categories: categories,
    ), isNull);
    expect(reviewedCategorySuggestion(
      item: tx(account: 'account-2'), rules: [rule()],
      categories: categories,
    ), isNull);
    expect(reviewedCategorySuggestion(
      item: tx(), rules: [rule(match: AutomationMatchType.contains)],
      categories: categories,
    ), isNull);
    expect(reviewedCategorySuggestion(
      item: tx(type: 'income'), rules: [rule()],
      categories: categories,
    ), isNull);
  });
}
