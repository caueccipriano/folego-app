import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/financial_space.dart';
import 'package:folego/data/models/folego_snapshot.dart';
import 'package:folego/data/models/monthly_money_summary.dart';
import 'package:folego/data/repositories/folego_repository.dart';
import 'package:folego/features/panorama/panorama_360_data.dart';
import 'package:folego/features/panorama/panorama_360_screen.dart';

class _FakeRepo extends Fake implements FolegoRepository {}

const _spaceA = FinancialSpace(id: 'fake-space-A', name: 'A');
const _spaceB = FinancialSpace(id: 'fake-space-B', name: 'B');

FolegoSnapshot _fakeSnapshot(num amount) => FolegoSnapshot(
      asOfDate: DateTime(2026, 9, 29),
      nextIncomeDate: DateTime(2026, 10, 1),
      nextIncomeAmount: 1500,
      daysUntilIncome: 2,
      liquidBalance: 1500,
      protectedBalance: 250,
      mandatoryOutflowsUntilIncome: 500,
      cashHeadroom: 750,
      monthlyBudgetPlanned: 800,
      monthlyBudgetUsed: 500,
      economicHeadroom: 300,
      spendablePool: amount,
      dailyFolego: 80,
      shortfall: 0,
      limitingFactor: 'budget',
      status: 'ok',
      budgetConfigured: true,
      needsIncomeSetup: false,
    );

MonthlyMoneySummary _fakeMonthly() => MonthlyMoneySummary.fromJson({
      'period_month': '2026-09-01',
      'income_amount': 1500,
      'competence_net': 400,
      'cash_outflow': 1100,
      'movement_card_payments': 400,
      'movement_transfers': 100,
    });

Future<void> _show(
  WidgetTester tester,
  Future<Panorama360Data> Function(String space) loader, {
  FinancialSpace space = _spaceA,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Panorama360Screen(
      key: const ValueKey('panorama-same-state'),
      repository: _FakeRepo(),
      space: space,
      loadOverride: loader,
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('all-user Panorama uses existing canonical money, no extra expenses',
      (tester) async {
    await _show(tester, (_) async => Panorama360Data(
      snapshot: _fakeSnapshot(120),
      monthlyMoney: _fakeMonthly(),
      budgets: const [],
      goals: const [],
      upcoming: const [],
    ));

    expect(find.byKey(const ValueKey('panorama-content')), findsOneWidget);
    expect(find.byKey(const ValueKey('panorama-spendable')), findsOneWidget);
    expect(find.text('resultado econômico do mês'), findsOneWidget);
    // A historical-comparison card now sits between economics and budgets.
    // The compact dashboard lazy-builds lower sections during scrolling.
    await tester.scrollUntilVisible(
      find.text('limites do mês'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('limites do mês'), findsOneWidget);
    expect(
      find.text('nenhum limite por categoria configurado'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('suas metas'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('suas metas'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('próximos compromissos'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('próximos compromissos'), findsOneWidget);
  });

  testWidgets('partial source failure shows unavailable, not synthetic zero',
      (tester) async {
    await _show(tester, (_) async => Panorama360Data(
      snapshot: _fakeSnapshot(120),
    ));

    expect(find.byKey(const ValueKey('panorama-spendable')), findsOneWidget);
    // ListView builds only visible sections. Missing data stays unknown
    // for every section, including sections scrolled into view later.
    expect(
      find.text('não foi possível confirmar esta informação'),
      findsWidgets,
    );
    expect(find.text('nenhum limite por categoria configurado'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('próximos compromissos'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('próximos compromissos'), findsOneWidget);
    expect(
      find.text('não foi possível confirmar esta informação'),
      findsWidgets,
    );
  });

  testWidgets('completely failed fetch has honest retry, not an empty dashboard',
      (tester) async {
    var requests = 0;
    await _show(tester, (_) async {
      requests++;
      if (requests == 1) throw StateError('fictional unavailable backend');
      return Panorama360Data(snapshot: _fakeSnapshot(120));
    });

    expect(find.byKey(const ValueKey('panorama-retry')), findsOneWidget);
    expect(find.byKey(const ValueKey('panorama-content')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('panorama-retry')));
    await tester.pumpAndSettle();
    expect(requests, 2);
    expect(find.byKey(const ValueKey('panorama-spendable')), findsOneWidget);
  });

  testWidgets('switching financial spaces discards in-flight old data',
      (tester) async {
    final lateA = Completer<Panorama360Data>();
    final fakeRepo = _FakeRepo();
    Future<Panorama360Data> loader(String space) {
      if (space == _spaceA.id) return lateA.future;
      return Future<Panorama360Data>.value(
        Panorama360Data(snapshot: _fakeSnapshot(80)),
      );
    }

    await tester.pumpWidget(MaterialApp(
      home: Panorama360Screen(
        key: const ValueKey('same-panorama'),
        repository: fakeRepo,
        space: _spaceA,
        loadOverride: loader,
      ),
    ));
    await tester.pump();
    await tester.pumpWidget(MaterialApp(
      home: Panorama360Screen(
        key: const ValueKey('same-panorama'),
        repository: fakeRepo,
        space: _spaceB,
        loadOverride: loader,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('panorama-spendable')), findsOneWidget);
    lateA.complete(Panorama360Data(snapshot: _fakeSnapshot(900)));
    await tester.pumpAndSettle();

    final label = tester.widget<Text>(
      find.byKey(const ValueKey('panorama-spendable')),
    );
    expect(label.data, contains('80'));
    expect(label.data, isNot(contains('900')));
  });
}
