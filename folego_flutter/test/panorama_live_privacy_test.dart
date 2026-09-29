import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/privacy/financial_privacy.dart';
import 'package:folego/core/utils/formatters.dart';
import 'package:folego/data/models/financial_space.dart';
import 'package:folego/data/models/folego_snapshot.dart';
import 'package:folego/data/models/monthly_money_summary.dart';
import 'package:folego/data/repositories/folego_repository.dart';
import 'package:folego/features/panorama/panorama_360_data.dart';
import 'package:folego/features/panorama/panorama_360_screen.dart';

class _SyntheticRepository extends Fake implements FolegoRepository {}

FolegoSnapshot _syntheticSnapshot() => FolegoSnapshot(
      asOfDate: DateTime(2026, 9, 29),
      nextIncomeDate: DateTime(2026, 10, 1),
      nextIncomeAmount: 1500,
      daysUntilIncome: 2,
      liquidBalance: 1000,
      protectedBalance: 250,
      mandatoryOutflowsUntilIncome: 600,
      cashHeadroom: 150,
      monthlyBudgetPlanned: 800,
      monthlyBudgetUsed: 700,
      economicHeadroom: 100,
      spendablePool: 120,
      dailyFolego: 60,
      shortfall: 0,
      limitingFactor: 'budget',
      status: 'ok',
      budgetConfigured: true,
      needsIncomeSetup: false,
    );

Panorama360Data _syntheticView() => Panorama360Data(
      snapshot: _syntheticSnapshot(),
      monthlyMoney: MonthlyMoneySummary.fromJson({
        'period_month': '2026-09-01',
        'income_amount': 1500,
        'competence_net': 400,
        'cash_outflow': 950,
        'movement_card_payments': 400,
        'movement_transfers': 150,
      }),
      budgets: const [],
      goals: const [],
      upcoming: const [],
    );

Widget _page(
  Future<Panorama360Data> Function(String spaceId) loader,
) =>
    MaterialApp(
      home: Panorama360Screen(
        repository: _SyntheticRepository(),
        space: const FinancialSpace(
          id: 'fictional-private-space',
          name: 'Fictitious space',
        ),
        loadOverride: loader,
      ),
    );

void main() {
  setUp(() => FinancialPrivacy.hidden.value = false);
  tearDown(() => FinancialPrivacy.hidden.value = false);

  testWidgets('existing Panorama figures immediately mask AND unmask',
      (tester) async {
    var queries = 0;
    await tester.pumpWidget(_page((_) async {
      queries++;
      return _syntheticView();
    }));
    await tester.pumpAndSettle();

    final spendable = find.byKey(const ValueKey('panorama-spendable'));
    expect(spendable, findsOneWidget);
    expect(tester.widget<Text>(spendable).data, Formatters.money(120));
    expect(queries, 1);

    FinancialPrivacy.hidden.value = true;
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(spendable).data, FinancialPrivacy.maskMoney());
    expect(find.textContaining('R$ 120,00'), findsNothing);
    expect(find.textContaining('R$ 250,00'), findsNothing);
    expect(queries, 1, reason: 'Privacy toggle must not refetch data');

    FinancialPrivacy.hidden.value = false;
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(spendable).data, Formatters.money(120));
    expect(queries, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('if privacy activates DURING loading, fetched numbers stay hidden',
      (tester) async {
    final late = Completer<Panorama360Data>();
    await tester.pumpWidget(_page((_) => late.future));
    await tester.pump();

    FinancialPrivacy.hidden.value = true;
    late.complete(_syntheticView());
    await tester.pumpAndSettle();

    final spendable = find.byKey(const ValueKey('panorama-spendable'));
    expect(spendable, findsOneWidget);
    expect(tester.widget<Text>(spendable).data, FinancialPrivacy.maskMoney());
    expect(find.textContaining('R$ 120,00'), findsNothing);
  });

  testWidgets('privacy immediately masks mounted economic amount rows',
      (tester) async {
    await tester.pumpWidget(_page((_) async => _syntheticView()));
    await tester.pumpAndSettle();

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('resultado econômico do mês'),
      220,
      scrollable: scrollable,
    );
    final originallyVisibleIncome = Formatters.money(1500);
    final originallyVisibleExpense = Formatters.money(400);
    expect(find.text(originallyVisibleIncome), findsWidgets);
    expect(find.text(originallyVisibleExpense), findsWidgets);
    FinancialPrivacy.hidden.value = true;
    await tester.pumpAndSettle();
    expect(find.text(originallyVisibleIncome), findsNothing);
    expect(find.text(originallyVisibleExpense), findsNothing);
    expect(find.text(FinancialPrivacy.maskMoney()), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
