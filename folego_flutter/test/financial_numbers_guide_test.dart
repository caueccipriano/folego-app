import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/privacy/financial_privacy.dart';
import 'package:folego/core/utils/formatters.dart';
import 'package:folego/features/home/financial_numbers_guide.dart';

void main() {
  tearDown(() => FinancialPrivacy.hidden.value = false);

  Widget screen({double? spending, double? competence}) => MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: FinancialNumbersGuide(
          accountBalance: 140,
          untilIncome: 0,
          spendingByPurchaseDate: spending,
          expensesByCompetence: competence,
        ),
      ),
    ),
  );

  testWidgets('shows registered cash and budget margin as distinct numbers',
      (tester) async {
    await tester.pumpWidget(screen(spending: 68.86, competence: 2870.93));
    expect(find.text('dinheiro nas contas para uso'), findsOneWidget);
    expect(find.text('disponível até receber'), findsOneWidget);
    expect(find.text('gastos feitos no mês'), findsOneWidget);
    expect(find.text('despesas por competência'), findsOneWidget);
    expect(find.text(Formatters.money(140)), findsOneWidget);
    expect(find.text(Formatters.money(0)), findsOneWidget);
    expect(find.text(Formatters.money(68.86)), findsOneWidget);
    expect(find.text(Formatters.money(2870.93)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hide-money mode masks all financial totals', (tester) async {
    FinancialPrivacy.hidden.value = true;
    await tester.pumpWidget(screen(spending: 68.86, competence: 2870.93));
    expect(find.textContaining('140,00'), findsNothing);
    expect(find.textContaining('0,00'), findsNothing);
    expect(find.textContaining('68,86'), findsNothing);
    expect(find.textContaining('2.870,93'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing monthly data does not invent missing metrics',
      (tester) async {
    await tester.pumpWidget(screen());
    expect(find.text('gastos feitos no mês'), findsNothing);
    expect(find.text('despesas por competência'), findsNothing);
    expect(find.text('dinheiro nas contas para uso'), findsOneWidget);
  });
}
