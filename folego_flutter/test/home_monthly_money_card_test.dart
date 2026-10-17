import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/utils/formatters.dart';
import 'package:folego/data/models/monthly_money_summary.dart';
import 'package:folego/features/home/home_monthly_money_card.dart';
import 'package:folego/features/home/home_value_explanation.dart';
import 'package:folego/core/privacy/financial_privacy.dart';

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


  test('main card explanations keep real economic and cash concepts distinct', () {
    final income = HomeValueExplanation.fromSummary(
      summary, HomeValueKind.income);
    final spending = HomeValueExplanation.fromSummary(
      summary, HomeValueKind.spending);
    final economic = HomeValueExplanation.fromSummary(
      summary, HomeValueKind.economic);
    expect(income.amount, 5000);
    expect(income.lines.single.amount, 5000);
    expect(spending.amount, 4731.89);
    expect(spending.lines.map((line) => line.amount),
      [2165.96, 2232.63, 365.30, 32]);
    expect(spending.lines.last.subtract, isTrue);
    expect(economic.amount, closeTo(4432.36, .001));
    expect(economic.lines.last.amount, closeTo(567.64, .001));
    expect(economic.meaning, contains('Não é o dinheiro no banco'));
    expect(spending.excluded, contains('Pagar a fatura'));
  });

  testWidgets('tapping each main amount explains before opening transactions',
      (tester) async {
    FinancialPrivacy.hidden.value = false;
    addTearDown(() => FinancialPrivacy.hidden.value = false);
    final opened = <MonthlyMoneyTransactionKind>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(
        child: HomeMonthlyMoneyCard(
          summary: summary, unavailable: false,
          onOpenTransactions: (kind, _) => opened.add(kind),
        ),
      )),
    ));
    await tester.tap(find.byKey(
      const ValueKey('monthly-income-open-transactions')));
    await tester.pumpAndSettle();
    expect(find.text('me explica esse valor'), findsOneWidget);
    expect(find.text('de onde veio esse número?'), findsOneWidget);
    expect(opened, isEmpty);
    await tester.tap(find.byKey(
      const ValueKey('home-explain-open-transactions')));
    await tester.pumpAndSettle();
    expect(opened, [MonthlyMoneyTransactionKind.income]);

    await tester.tap(find.byKey(
      const ValueKey('monthly-spending-open-transactions')));
    await tester.pumpAndSettle();
    expect(find.text('conta, débito e PIX'), findsOneWidget);
    expect(find.text('estornos e reembolsos'), findsOneWidget);
    expect(opened.length, 1);
    await tester.tap(find.byTooltip('fechar explicação'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(
      const ValueKey('monthly-economic-explain')));
    await tester.pumpAndSettle();
    expect(find.text('resultado do mês'), findsOneWidget);
    expect(find.textContaining('Não é o dinheiro no banco'), findsOneWidget);
    expect(find.byKey(
      const ValueKey('home-explain-open-transactions')), findsNothing);
  });

  testWidgets('explanation respects hide money preference', (tester) async {
    FinancialPrivacy.hidden.value = true;
    addTearDown(() => FinancialPrivacy.hidden.value = false);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(
        child: HomeMonthlyMoneyCard(summary: summary, unavailable: false),
      )),
    ));
    await tester.tap(find.byKey(
      const ValueKey('monthly-spending-open-transactions')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-explained-value')), findsOneWidget);
    expect(find.text(FinancialPrivacy.maskMoney()), findsWidgets);
    expect(find.text('de onde veio esse número?'), findsOneWidget);
  });

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
          body: SingleChildScrollView(
            child: HomeMonthlyMoneyCard(
              summary: summary,
              unavailable: false,
            ),
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
          body: SingleChildScrollView(
            child: HomeMonthlyMoneyCard(summary: summary, unavailable: false),
          ),
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
