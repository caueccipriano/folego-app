import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:folego/data/models/folego_snapshot.dart';
import 'package:folego/data/models/transaction_item.dart';
import 'package:folego/features/home/home_financial_hero.dart';
import 'package:folego/features/transactions/transaction_classification_inbox.dart';

void main() {
  FolegoSnapshot snapshot({
    String factor = 'cash',
    num liquid = 179.76,
    num protected = 0,
    num mandatory = 190,
    num planned = 500,
    num used = 500,
    num spendable = 0,
  }) => FolegoSnapshot(
    asOfDate: DateTime(2026, 10, 9),
    nextIncomeDate: DateTime(2026, 10, 15),
    nextIncomeAmount: 6000,
    daysUntilIncome: 6,
    liquidBalance: liquid,
    protectedBalance: protected,
    mandatoryOutflowsUntilIncome: mandatory,
    cashHeadroom: 0,
    monthlyBudgetPlanned: planned,
    monthlyBudgetUsed: used,
    economicHeadroom: 0,
    spendablePool: spendable,
    dailyFolego: 0,
    shortfall: 0,
    limitingFactor: factor,
    status: 'sem_folga',
    budgetConfigured: true,
    needsIncomeSetup: false,
  );

  test('zero cash explains account balance and upcoming obligations', () {
    final facts = homeZeroBalanceFacts(snapshot());
    expect(facts, hasLength(2));
    expect(facts[0], contains('em contas'));
    expect(facts[1], contains('contas até receber'));
  });

  test('budget limit describes headroom without claiming cash is zero', () {
    final facts = homeZeroBalanceFacts(snapshot(
      factor: 'budget',
      liquid: 179.76,
      mandatory: 0,
      planned: 300,
      used: 500,
      protected: 100,
    ));
    expect(facts.join(' '), contains('em contas'));
    expect(facts.join(' '), contains('protegido'));
    expect(facts.join(' '), contains('limite flexível excedido'));
    expect(facts.join(' '), isNot(contains('contas até receber')));
    expect(homeZeroBalanceFacts(snapshot(spendable: 50)), isEmpty);
  });

  testWidgets('zero balance breakdown stays within hero and opens detailed explanation',
    (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(width: 360, child: HomeFinancialHero(snapshot: snapshot())),
      ),
    ));
    expect(find.byKey(const ValueKey('home-folego-zero-breakdown')), findsOneWidget);
    expect(find.text('por que zerou?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home-folego-explainer')));
    await tester.pumpAndSettle();
    expect(find.text('como chegamos nisso?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  TransactionItem entry(
    String id, {
    String desc = 'Café do Centro',
    String type = 'expense',
    String? account = 'account-1',
    String source = 'manual',
    String? category,
  }) => TransactionItem(
    id: id,
    eventType: type,
    description: desc,
    amount: 25,
    occurredAt: DateTime(2026, 10, 9),
    status: 'confirmed',
    source: source,
    categoryId: category,
    accountId: account,
  );

  test('bulk classification only suggests exact matching same-account entries', () {
    final original = entry('a');
    final matches = matchingClassificationCandidates(original, [
      original,
      entry('b', desc: 'cafe   DO centro'),
      entry('c', account: 'account-2'),
      entry('d', type: 'income'),
      entry('e', desc: 'Cafe Centro Shopping'),
      entry('f', source: 'import'),
      entry('g', category: 'classified'),
    ]);
    expect(matches.map((e) => e.id), ['b']);
  });

  test('unknown source account and short descriptions never trigger bulk actions', () {
    expect(matchingClassificationCandidates(
      entry('a', account: null),
      [entry('b', account: null)],
    ), isEmpty);
    expect(matchingClassificationCandidates(
      entry('a', desc: 'AB'),
      [entry('b', desc: 'AB')],
    ), isEmpty);
  });
}
