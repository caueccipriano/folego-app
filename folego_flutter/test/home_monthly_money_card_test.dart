import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/utils/formatters.dart';
import 'package:folego/data/models/monthly_money_summary.dart';
import 'package:folego/features/home/home_monthly_money_card.dart';

void main() {
  const summary = MonthlyMoneySummary(
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
      const MaterialApp(
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
    expect(find.text('gastos do mês'), findsOneWidget);
    expect(find.text(Formatters.money(4731.89)), findsOneWidget);
    expect(find.text('conta'), findsOneWidget);
    expect(find.text('cartões'), findsOneWidget);
    expect(find.text('benefícios'), findsOneWidget);
    expect(find.text('reembolsos'), findsOneWidget);
    expect(find.text('receitas do mês'), findsOneWidget);
    expect(find.text('saldo compras x renda'), findsOneWidget);
    expect(find.text('pagamentos de fatura'), findsNothing);
  });

  testWidgets('composition separates purchases, competence and cash movement', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
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

    expect(find.text('gastos feitos no mês'), findsOneWidget);
    expect(find.text('faturas e parcelas'), findsOneWidget);
    expect(find.text('fatura AMEX Gold / parcelas'), findsOneWidget);
    expect(find.text('despesa por competência'), findsOneWidget);
    expect(find.text('movimentações que não são gasto'), findsOneWidget);
    expect(find.text('pagamentos de fatura'), findsOneWidget);
    expect(find.text('transferências entre suas contas'), findsOneWidget);
    expect(find.text('investimentos / reserva'), findsOneWidget);
    expect(find.text('ajustes de conciliação'), findsOneWidget);
    expect(find.text('movimentação de caixa'), findsOneWidget);
    expect(find.text(monthlyCardSemanticsTooltip), findsOneWidget);
  });
}
