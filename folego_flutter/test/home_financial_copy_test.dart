import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:folego/data/models/folego_snapshot.dart';
import 'package:folego/features/home/home_financial_hero.dart';

void main() {
  group('Fôlego contextual copy', () {
    test('explains budget when budget is the active constraint', () {
      expect(
        homeFolegoContextLabel(_snapshot(limitingFactor: 'budget')),
        'o espaço do seu orçamento para gastos flexíveis já foi usado',
      );
    });

    test('keeps commitment copy when cash is the active constraint', () {
      expect(
        homeFolegoContextLabel(_snapshot(limitingFactor: 'cash')),
        'seus compromissos já ocupam o dinheiro disponível até o próximo recebimento',
      );
    });

    test('explains both constraints when both are active', () {
      expect(
        homeFolegoContextLabel(_snapshot(limitingFactor: 'both')),
        'seu dinheiro disponível e o orçamento para gastos flexíveis chegaram ao limite',
      );
    });

    testWidgets('explainer names the discretionary budget clearly', (tester) async {
      final snapshot = _snapshot(
        limitingFactor: 'budget',
        budgetConfigured: true,
        monthlyBudgetPlanned: 1652.80,
        monthlyBudgetUsed: 2945,
        economicHeadroom: 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeFinancialHero(snapshot: snapshot),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('home-folego-explainer')));
      await tester.pumpAndSettle();

      expect(find.text('orçamento para gastos flexíveis'), findsWidgets);
      expect(find.text('gastos flexíveis no mês'), findsOneWidget);
      expect(find.text('ainda disponível para gastos flexíveis'), findsOneWidget);
      expect(find.text('limite de orçamento do mês'), findsNothing);
      expect(find.text('já usado no orçamento'), findsNothing);
    });
  });
}

FolegoSnapshot _snapshot({
  required String limitingFactor,
  bool budgetConfigured = false,
  double monthlyBudgetPlanned = 0,
  double monthlyBudgetUsed = 0,
  double economicHeadroom = 0,
}) {
  return FolegoSnapshot(
    asOfDate: DateTime(2026, 9, 17),
    nextIncomeDate: DateTime(2026, 9, 30),
    nextIncomeAmount: 2300,
    daysUntilIncome: 13,
    liquidBalance: 179.76,
    protectedBalance: 650,
    mandatoryOutflowsUntilIncome: 0,
    cashHeadroom: 179.76,
    monthlyBudgetPlanned: monthlyBudgetPlanned,
    monthlyBudgetUsed: monthlyBudgetUsed,
    economicHeadroom: economicHeadroom,
    spendablePool: 0,
    dailyFolego: 0,
    shortfall: 0,
    limitingFactor: limitingFactor,
    status: 'sem_folga',
    budgetConfigured: budgetConfigured,
    needsIncomeSetup: false,
  );
}
