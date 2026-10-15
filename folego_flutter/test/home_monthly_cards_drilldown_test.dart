import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/monthly_money_summary.dart';
import 'package:folego/features/home/home_monthly_money_card.dart';

void main() {
  testWidgets('monthly income and spending cards open the correct drilldown',
      (tester) async {
    final summary = MonthlyMoneySummary.fromJson({
      'period_month': '2026-10-01',
      'income_amount': 6500,
      'spending_net': 1250,
    });
    final selections = <MonthlyMoneyTransactionKind>[];
    final months = <DateTime>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HomeMonthlyMoneyCard(
              summary: summary,
              unavailable: false,
              onOpenTransactions: (kind, month) {
                selections.add(kind);
                months.add(month);
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('quanto entrou?'), findsOneWidget);
    expect(find.text('quanto gastei?'), findsOneWidget);
    expect(find.textContaining('Receitas não incluem transferências internas'),
        findsOneWidget);
    await tester.tap(find.byKey(
      const ValueKey('monthly-income-open-transactions'),
    ));
    expect(selections, [MonthlyMoneyTransactionKind.income]);

    await tester.tap(find.byKey(
      const ValueKey('monthly-spending-open-transactions'),
    ));
    expect(selections, [
      MonthlyMoneyTransactionKind.income,
      MonthlyMoneyTransactionKind.spending,
    ]);
    for (final month in months) {
      expect(month.year, 2026);
      expect(month.month, 10);
    }
  });

  testWidgets('monthly cards have no dead tap action without navigation',
      (tester) async {
    final summary = MonthlyMoneySummary.fromJson({
      'period_month': '2026-10-01',
      'income_amount': 6500,
      'spending_net': 1250,
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeMonthlyMoneyCard(summary: summary, unavailable: false),
        ),
      ),
    );
    final incomeTap = tester.widget<InkWell>(
      find.byKey(const ValueKey('monthly-income-open-transactions')),
    );
    expect(incomeTap.onTap, isNull);
  });
}
