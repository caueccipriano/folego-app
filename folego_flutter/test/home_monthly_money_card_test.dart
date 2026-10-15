import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/utils/formatters.dart';
import 'package:folego/data/models/monthly_money_summary.dart';
import 'package:folego/features/home/home_monthly_money_card.dart';

void main() {
  final summary = MonthlyMoneySummary(
    periodMonth: DateTime(2026, 9),
    incomeAmount: 5000,
    spendingAccount: 2165.96,
    spendingCards: 2232.63,
    spendingBenefits: 365.30,
    refundsAmount: 32,
    spendingNet: 4731.89,
    incomeMinusSpending: 268.11,
    competenceCardsTotal: 149.64,
    competenceDirect: 400,
    competenceBenefits: 50,
    competenceRefunds: 32,
    competenceNet: 567.64,
    competenceCards: [
      MonthlyCardCompetence(
        cardId: 'amex',
        name: 'AMEX Gold',
        amount: 149.64,
      ),
    ],
    cashInflow: 6000,
    cashOutflow: 4800,
    cashNet: 1200,
    movementCardPayments: 700,
    movementTransfers: 300,
    movementReserveInvestment: 250,
    movementReconciliation: 25,
  );

  testWidgets('shows spending made breakdown without calling cash movement spending', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HomeMonthlyMoneyCard(
              summary: summary,
              unavailable: false,
            ),
          ),
        ),
      ),
    );

    expect(find.text('seu mês até agora'), findsOneWidget);
    expect(find.text('quanto gastei?'), findsOneWidget);
    expect(find.text(Formatters.money(4731.89)), findsOneWidget);
    expect(find.text('gastos pela conta / PIX'), findsOneWidget);
    expect(find.text('compras no cartão'), findsOneWidget);
    expect(find.text('benefícios utilizados'), findsOneWidget);
    expect(find.text('reembolsos abatidos dos gastos'), findsOneWidget);
    expect(find.text('quanto entrou?'), findsOneWidget);
    expect(find.text('resultado econômico · não é saldo disponível'), findsOneWidget);
    expect(find.text('pagamentos de fatura'), findsNothing);
  });

  testWidgets('composition separates purchases, competence and cash movement', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeMonthlyMoneyCard(
            summary: summary,
            unavailable: false,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('monthly-money-composition')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.text('gastos feitos no mês'),
      ),
      findsOneWidget,
    );
    expect(find.text('despesas atribuídas a este mês'), findsOneWidget);
    expect(find.text('cartões na competência'), findsOneWidget);
    expect(find.text('despesa por competência'), findsOneWidget);
    expect(find.text('movimentações que não são novos gastos'), findsOneWidget);
    expect(find.text('pagamentos de fatura'), findsOneWidget);
    expect(find.text('transferências / investimentos'), findsOneWidget);
    expect(find.text('ajustes de conciliação'), findsOneWidget);
    expect(find.text('movimentação de caixa'), findsOneWidget);
    expect(find.text(monthlyCardSemanticsTooltip), findsOneWidget);
  });
  testWidgets('clarifies real October values and never calls movements balances', (
    tester,
  ) async {
    final october = MonthlyMoneySummary(
      periodMonth: DateTime(2026, 10),
      incomeAmount: 2503.80,
      spendingAccount: 723.69,
      spendingCards: 1961.24,
      spendingBenefits: 402.74,
      refundsAmount: 0,
      spendingNet: 3087.67,
      incomeMinusSpending: -583.87,
      competenceCardsTotal: 2186.61,
      competenceDirect: 723.69,
      competenceBenefits: 402.74,
      competenceRefunds: 0,
      competenceNet: 3313.04,
      competenceCards: const [],
      cashInflow: 0,
      cashOutflow: 0,
      cashNet: 0,
      movementCardPayments: 0,
      movementTransfers: 0,
      movementReserveInvestment: 0,
      movementReconciliation: 0,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HomeMonthlyMoneyCard(summary: october, unavailable: false),
          ),
        ),
      ),
    );

    expect(find.text('quanto entrou?'), findsOneWidget);
    expect(find.text('quanto gastei?'), findsOneWidget);
    expect(find.text('resultado econômico · não é saldo disponível'), findsOneWidget);
    expect(find.text('-${Formatters.money(october.economicResult.abs())}'), findsOneWidget);
    expect(find.textContaining(Formatters.money(october.competenceExpenses)), findsOneWidget);
    expect(find.textContaining(Formatters.money((october.competenceExpenses - october.spendingMade).abs())), findsOneWidget);
    expect(find.text('reembolsos abatidos dos gastos'), findsNothing);
    expect(find.byKey(const ValueKey('monthly-spending-origins')), findsOneWidget);
  });

  testWidgets('comparison and result remain explained in the detail sheet', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeMonthlyMoneyCard(summary: summary, unavailable: false),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('monthly-money-composition')));
    await tester.pumpAndSettle();
    expect(find.text('como chegamos ao resultado econômico'), findsOneWidget);
    expect(find.text('resultado econômico (não é saldo)'), findsOneWidget);
    expect(find.byKey(const ValueKey('monthly-economic-calculation')), findsOneWidget);
  });

}
