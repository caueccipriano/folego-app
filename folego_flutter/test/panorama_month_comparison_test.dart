import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/privacy/financial_privacy.dart';
import 'package:folego/core/utils/formatters.dart';
import 'package:folego/data/models/monthly_money_summary.dart';
import 'package:folego/features/panorama/panorama_month_comparison.dart';
import 'package:folego/features/panorama/panorama_month_trend.dart';

MonthlyMoneySummary _fakeMonth(
  int number, {
  double income = 0,
  double expenses = 0,
}) =>
    MonthlyMoneySummary.fromJson({
      'period_month': '2026-${number.toString().padLeft(2, '0')}-01',
      'income_amount': income,
      'competence_net': expenses,
      'cash_outflow': 50000,
      'movement_card_payments': 49000,
    });

PanoramaClosedMonthTrend _fakeTrend({
  double earlierIncome = 1000,
  double laterIncome = 1500,
  double earlierExpenses = 900,
  double laterExpenses = 700,
}) =>
    PanoramaClosedMonthTrend.tryFrom(
      earlier: _fakeMonth(7,
          income: earlierIncome, expenses: earlierExpenses),
      later: _fakeMonth(8,
          income: laterIncome, expenses: laterExpenses),
      referenceDate: DateTime(2026, 9, 29),
    )!;

Future<void> _show(
  WidgetTester tester,
  PanoramaClosedMonthTrend? trend,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 340,
          child: SingleChildScrollView(
            child: PanoramaMonthComparison(trend: trend),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => FinancialPrivacy.hidden.value = false);
  tearDown(() => FinancialPrivacy.hidden.value = false);

  testWidgets('compact comparison uses both closed months, not fake forecast',
      (tester) async {
    await _show(tester, _fakeTrend());

    expect(find.byKey(const ValueKey('panorama-month-comparison')),
        findsOneWidget);
    expect(find.text('evolução financeira'), findsOneWidget);
    expect(find.textContaining('Dois meses encerrados'), findsOneWidget);
    expect(find.text('receitas'), findsOneWidget);
    expect(find.text('despesas'), findsOneWidget);
    expect(find.text('resultado'), findsOneWidget);
    expect(find.text(Formatters.money(1500)), findsOneWidget);
    expect(find.text(Formatters.money(500)), findsNothing);
    expect(find.textContaining('a menos no mês mais recente'), findsOneWidget);
    expect(find.textContaining('Pagamentos de fatura'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing comparison never makes unavailable history look empty',
      (tester) async {
    await _show(tester, null);
    expect(find.byKey(const ValueKey('panorama-trend-unavailable')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('panorama-trend-recorded-empty')),
        findsNothing);
  });

  testWidgets('two verified zero months get a separate recorded-empty state',
      (tester) async {
    await _show(tester, _fakeTrend(
      earlierIncome: 0,
      laterIncome: 0,
      earlierExpenses: 0,
      laterExpenses: 0,
    ));
    expect(find.byKey(const ValueKey('panorama-trend-recorded-empty')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('panorama-trend-unavailable')),
        findsNothing);
  });

  testWidgets('privacy toggle immediately masks historical and delta amounts',
      (tester) async {
    await _show(tester, _fakeTrend());

    expect(find.text(Formatters.money(1500)), findsOneWidget);
    FinancialPrivacy.hidden.value = true;
    await tester.pumpAndSettle();

    expect(find.textContaining('1.500,00'), findsNothing);
    expect(find.textContaining('700,00'), findsNothing);
    expect(find.textContaining('200,00'), findsNothing);
    expect(find.textContaining(FinancialPrivacy.maskMoney()), findsWidgets);
    FinancialPrivacy.hidden.value = false;
    await tester.pumpAndSettle();
    expect(find.text(Formatters.money(1500)), findsOneWidget);
  });
}
