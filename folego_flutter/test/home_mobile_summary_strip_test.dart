import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/folego_snapshot.dart';
import 'package:folego/data/models/upcoming_events.dart';
import 'package:folego/features/home/home_mobile_summary_strip.dart';

FolegoSnapshot snapshot({bool configured = true, double planned = 200,
    double used = 125}) => FolegoSnapshot(
  asOfDate: DateTime(2026, 10, 31),
  nextIncomeDate: DateTime(2026, 11, 15),
  nextIncomeAmount: 6000,
  daysUntilIncome: 15,
  liquidBalance: 500,
  protectedBalance: 100,
  mandatoryOutflowsUntilIncome: 200,
  cashHeadroom: 300,
  monthlyBudgetPlanned: planned,
  monthlyBudgetUsed: used,
  economicHeadroom: 75,
  spendablePool: 75,
  dailyFolego: 5,
  shortfall: 0,
  limitingFactor: 'budget',
  status: 'attention',
  budgetConfigured: configured,
  needsIncomeSetup: false,
);

Widget host({bool hidden = false, bool showTiles = true,
    required VoidCallback onBudget, required VoidCallback onUpcoming}) =>
  MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(width: 320, child: HomeMobileSummaryStrip(
          snapshot: snapshot(),
          monthly: null,
          upcoming: [
            UpcomingEvent(
              id: 'test', source: 'recurring', name: 'Conta teste',
              dueDate: DateTime(2026, 11, 12), amount: 240.0,
              direction: 'expense', status: 'pending'),
          ],
          upcomingAvailable: true,
          hidden: hidden,
          showTiles: showTiles,
          onBudget: onBudget,
          onMonthly: () {},
          onUpcoming: onUpcoming,
        )),
      ),
    ),
  );

void main() {
  test('progresso usa apenas dados reais do snapshot e respeita limites', () {
    expect(HomeMobileSummaryStrip.progress(snapshot()), .625);
    expect(HomeMobileSummaryStrip.progress(snapshot(used: 300)), 1);
    expect(HomeMobileSummaryStrip.progress(snapshot(configured: false)), isNull);
    expect(HomeMobileSummaryStrip.progress(snapshot(planned: 0)), isNull);
    expect(HomeMobileSummaryStrip.progress(snapshot(used: -1)), isNull);
  });

  testWidgets('resumo no espaço de 320 px mostra contexto e atalhos', (tester) async {
    var budgetTaps = 0, agendaTaps = 0;
    await tester.pumpWidget(host(
      onBudget: () => budgetTaps++,
      onUpcoming: () => agendaTaps++,
    ));
    expect(find.text('orçamento flexível'), findsOneWidget);
    expect(find.text('63% utilizado'), findsOneWidget);
    expect(find.text('gastos do mês'), findsOneWidget);
    expect(find.text('próxima conta'), findsOneWidget);
    expect(find.textContaining('240,00'), findsOneWidget);
    final amount = tester.widget<Text>(find.byKey(
      const ValueKey('home-mobile-next-bill-amount')));
    expect(amount.style!.fontFamily, 'Manrope');
    expect(amount.style!.fontSize, greaterThanOrEqualTo(17));
    expect(amount.style!.fontFeatures, isNotEmpty);
    final title = tester.widget<Text>(find.text('orçamento flexível'));
    expect(title.style!.fontFamily, 'Manrope');
    expect(title.style!.fontSize, greaterThanOrEqualTo(13));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('home-mobile-budget')));
    await tester.tap(find.byKey(const ValueKey('home-mobile-next-bill')));
    expect(budgetTaps, 1);
    expect(agendaTaps, 1);
  });

  testWidgets('modo privado não expõe percentual nem contas', (tester) async {
    await tester.pumpWidget(host(
      hidden: true, onBudget: () {}, onUpcoming: () {}));
    expect(find.text('valores ocultos'), findsOneWidget);
    expect(find.byKey(const ValueKey('home-mobile-budget-progress')), findsNothing);
    expect(find.textContaining('63%'), findsNothing);
    expect(find.textContaining('240,00'), findsNothing);
    expect(find.textContaining('Conta teste'), findsNothing);
    expect(find.text('próxima conta'), findsOneWidget);
  });
}
