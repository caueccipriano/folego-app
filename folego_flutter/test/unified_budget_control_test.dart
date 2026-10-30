import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/privacy/financial_privacy.dart';
import 'package:folego/data/models/budget_overview_item.dart';
import 'package:folego/data/repositories/folego_repository.dart';
import 'package:folego/features/plan/unified_budget_control.dart';

class _Repository implements FolegoRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

FlexibleBudgetOverview _overview(DateTime month, {
  double limit = 300, double used = 150, bool explicit = true,
}) => FlexibleBudgetOverview(
  periodMonth: month, configured: true, explicitLimit: explicit,
  limitAmount: limit, usedAmount: used, remainingAmount: limit - used,
  exceededAmount: used > limit ? used - limit : 0,
  categoryLimitsTotal: 220,
);

Widget _app(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  tearDown(() => FinancialPrivacy.hidden.value = false);

  testWidgets('fallback is not presented as an independently set ceiling',
      (tester) async {
    final month = DateTime(DateTime.now().year, DateTime.now().month);
    var details = 0;
    await tester.pumpWidget(_app(UnifiedBudgetControl(
      repository: _Repository(),
      spaceId: 'A',
      periodMonth: month,
      onOpenDetails: () => details++,
      overviewLoader: (m) async => _overview(m, explicit: false),
    )));
    await tester.pumpAndSettle();

    expect(find.textContaining('herdado dos limites por categoria'),
        findsOneWidget);
    expect(find.text('definir teto próprio'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('plan-open-flex-budget')));
    expect(details, 1);
  });

  testWidgets('editing a ceiling requires confirmation and preserves categories',
      (tester) async {
    final month = DateTime(DateTime.now().year, DateTime.now().month);
    var current = 300.0;
    final saved = <double>[];
    var updates = 0;
    await tester.pumpWidget(_app(UnifiedBudgetControl(
      repository: _Repository(), spaceId: 'A', periodMonth: month,
      onOpenDetails: () {},
      overviewLoader: (m) async => _overview(m, limit: current),
      saveOverride: (m, value) async {
        saved.add(value);
        current = value;
      },
      onSaved: () => updates++,
    )));
    await tester.pumpAndSettle();
    expect(find.textContaining('teto R\$'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('unified-flex-edit')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('unified-flex-limit-input')), '450,00');
    await tester.tap(find.byKey(const ValueKey('unified-flex-save')));
    await tester.pumpAndSettle();

    expect(saved, [450]);
    expect(updates, 1);
    expect(find.textContaining('450,00'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hidden amounts stay hidden inside the unified control',
      (tester) async {
    FinancialPrivacy.hidden.value = true;
    final month = DateTime(DateTime.now().year, DateTime.now().month);
    await tester.pumpWidget(_app(UnifiedBudgetControl(
      repository: _Repository(), spaceId: 'A', periodMonth: month,
      onOpenDetails: () {},
      overviewLoader: (m) async => _overview(m, limit: 987.65),
    )));
    await tester.pumpAndSettle();
    expect(find.textContaining('R\$ ••••'), findsWidgets);
    expect(find.textContaining('987,65'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('unified-flex-edit')));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byKey(
      const ValueKey('unified-flex-limit-input')));
    expect(field.controller!.text, isEmpty);
  });

  testWidgets('late request from old space does not show its amounts',
      (tester) async {
    final month = DateTime(DateTime.now().year, DateTime.now().month);
    final old = Completer<FlexibleBudgetOverview>();
    Widget control(String space) => _app(UnifiedBudgetControl(
      repository: _Repository(), spaceId: space, periodMonth: month,
      onOpenDetails: () {},
      overviewLoader: (m) => space == 'A'
          ? old.future : Future.value(_overview(m, limit: 42)),
    ));
    await tester.pumpWidget(control('A'));
    await tester.pump();
    await tester.pumpWidget(control('B'));
    await tester.pumpAndSettle();
    old.complete(_overview(month, limit: 99999));
    await tester.pumpAndSettle();

    expect(find.textContaining('42,00'), findsWidgets);
    expect(find.textContaining('99.999'), findsNothing);
  });
}
