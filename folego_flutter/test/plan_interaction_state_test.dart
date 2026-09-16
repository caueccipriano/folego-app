import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/realtime/realtime_invalidation.dart';
import 'package:folego/core/realtime/realtime_session.dart';
import 'package:folego/data/models/budget_overview_item.dart';
import 'package:folego/data/repositories/folego_repository.dart';
import 'package:folego/features/plan/plan_screen.dart' as realtime_plan;
import 'package:folego/features/plan/plan_screen_web2.dart' as plan;

void main() {
  testWidgets('first Plan entry keeps every category closed', (tester) async {
    final repository = _FakePlanRepository(_fixture(planned: 100, actual: 35));
    await _pumpPlan(tester, repository);

    expect(find.byKey(const ValueKey('plan-children-food')), findsNothing);
    expect(find.byKey(const ValueKey('plan-children-transport')), findsNothing);
  });

  testWidgets('category opens only after click', (tester) async {
    final repository = _FakePlanRepository(_fixture());
    await _pumpPlan(tester, repository);

    final parent = find.byKey(const ValueKey('plan-parent-food'));
    await tester.ensureVisible(parent);
    await tester.tap(parent);
    await tester.pump();

    expect(find.byKey(const ValueKey('plan-children-food')), findsOneWidget);
  });

  testWidgets('second category click closes it again', (tester) async {
    final repository = _FakePlanRepository(_fixture());
    await _pumpPlan(tester, repository);

    final parent = find.byKey(const ValueKey('plan-parent-food'));
    await tester.ensureVisible(parent);
    await tester.tap(parent);
    await tester.pump();
    await tester.tap(parent);
    await tester.pump();

    expect(find.byKey(const ValueKey('plan-children-food')), findsNothing);
  });

  testWidgets('open category survives creating a limit', (tester) async {
    final repository = _FakePlanRepository(_fixture());
    final captured = <double>[];
    await _pumpPlan(
      tester,
      repository,
      saver: _captureSaver(captured),
    );

    await _openAndSave(tester, amount: '250,00');

    expect(captured, [250]);
    expect(find.byKey(const ValueKey('plan-children-food')), findsOneWidget);
  });

  testWidgets('open category survives editing a limit', (tester) async {
    final repository = _FakePlanRepository(_fixture(planned: 100));
    final captured = <double>[];
    await _pumpPlan(
      tester,
      repository,
      saver: _captureSaver(captured),
    );

    await _openAndSave(tester, amount: '180,00');

    expect(captured, [180]);
    expect(find.byKey(const ValueKey('plan-children-food')), findsOneWidget);
  });

  testWidgets('open category survives removing a limit', (tester) async {
    final repository = _FakePlanRepository(_fixture(planned: 100));
    final captured = <double>[];
    await _pumpPlan(
      tester,
      repository,
      saver: _captureSaver(captured),
    );

    await _openAndSave(tester, amount: '0');

    expect(captured, [0]);
    expect(find.byKey(const ValueKey('plan-children-food')), findsOneWidget);
  });

  testWidgets('open category survives local refresh', (tester) async {
    final repository = _FakePlanRepository(_fixture());
    await _pumpPlan(tester, repository);
    final parent = find.byKey(const ValueKey('plan-parent-food'));
    await tester.ensureVisible(parent);
    await tester.tap(parent);
    await tester.pump();

    final indicator = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator).first,
    );
    final refresh = indicator.onRefresh();
    await tester.pump();
    await refresh;
    await _flush(tester);

    expect(repository.loads, greaterThanOrEqualTo(2));
    expect(find.byKey(const ValueKey('plan-children-food')), findsOneWidget);
  });

  testWidgets('open category survives shared Realtime invalidation', (
    tester,
  ) async {
    final repository = _FakePlanRepository(_fixture());
    final coordinator = RealtimeInvalidationCoordinator();
    AppRealtimeRegistry.attach(coordinator);
    addTearDown(() {
      AppRealtimeRegistry.detach(coordinator);
      coordinator.dispose();
    });
    _setViewport(tester, const Size(390, 1200));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: realtime_plan.PlanScreen(
            repository: repository,
            spaceId: 'space',
          ),
        ),
      ),
    );
    await _flush(tester);

    final parent = find.byKey(const ValueKey('plan-parent-food'));
    await tester.ensureVisible(parent);
    await tester.tap(parent);
    await tester.pump();
    expect(find.byKey(const ValueKey('plan-children-food')), findsOneWidget);

    coordinator.invalidate(AppRealtimeDomain.plan);
    await tester.pump(const Duration(milliseconds: 250));
    await _flush(tester);

    expect(repository.loads, greaterThanOrEqualTo(2));
    expect(find.byKey(const ValueKey('plan-children-food')), findsOneWidget);
  });

  testWidgets('new Plan instance starts closed again', (tester) async {
    final repository = _FakePlanRepository(_fixture());
    await _pumpPlan(tester, repository);
    final parent = find.byKey(const ValueKey('plan-parent-food'));
    await tester.ensureVisible(parent);
    await tester.tap(parent);
    await tester.pump();
    expect(find.byKey(const ValueKey('plan-children-food')), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
    );
    await tester.pump();
    await _pumpPlan(tester, repository);

    expect(find.byKey(const ValueKey('plan-children-food')), findsNothing);
  });

  testWidgets('saving after scrolling never sends Plan back to the top', (
    tester,
  ) async {
    final repository = _FakePlanRepository(_longFixture());
    await _pumpPlan(
      tester,
      repository,
      saver: _captureSaver(<double>[]),
      size: const Size(390, 700),
    );

    final scroll = find.byKey(const ValueKey('plan-scroll'));
    final parent = find.byKey(const ValueKey('plan-parent-parent-7'));
    await tester.dragUntilVisible(
      parent,
      scroll,
      const Offset(0, -300),
    );
    await tester.pump();
    await tester.tap(parent);
    await tester.pump();

    final child = find.byKey(const ValueKey('plan-child-child-7'));
    await tester.ensureVisible(child);
    await tester.pump();
    final before = _scrollPosition(tester, scroll).pixels;
    expect(before, greaterThan(0));

    await tester.tap(child);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('plan-budget-amount')),
      '75,00',
    );
    await tester.tap(find.byKey(const ValueKey('plan-save-budget')));
    await tester.pumpAndSettle();

    final after = _scrollPosition(tester, scroll).pixels;
    expect(after, greaterThan(0));
    expect(after, greaterThan(before * .50));
    expect(find.byKey(const ValueKey('plan-children-parent-7')), findsOneWidget);
  });

  testWidgets('desktop keeps month summary visible while categories scroll', (
    tester,
  ) async {
    final repository = _FakePlanRepository(_longFixture());
    await _pumpPlan(
      tester,
      repository,
      size: const Size(1366, 820),
    );

    expect(find.byKey(const ValueKey('plan-desktop-layout')), findsOneWidget);
    final summary = find.byKey(const ValueKey('plan-summary'));
    final before = tester.getTopLeft(summary).dy;

    await tester.drag(
      find.byKey(const ValueKey('plan-scroll')),
      const Offset(0, -650),
    );
    await tester.pump();

    expect(tester.getTopLeft(summary).dy, before);
  });
}

Future<void> _pumpPlan(
  WidgetTester tester,
  _FakePlanRepository repository, {
  plan.PlanBudgetSaver? saver,
  Size size = const Size(390, 1200),
}) async {
  _setViewport(tester, size);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: plan.PlanScreen(
          repository: repository,
          spaceId: 'space',
          saveOverride: saver,
        ),
      ),
    ),
  );
  await _flush(tester);
}

void _setViewport(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _flush(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
  await tester.pump();
}

ScrollPosition _scrollPosition(WidgetTester tester, Finder scroll) {
  return tester
      .state<ScrollableState>(
        find.descendant(of: scroll, matching: find.byType(Scrollable)).first,
      )
      .position;
}

plan.PlanBudgetSaver _captureSaver(List<double> captured) {
  return ({
    required spaceId,
    required periodMonth,
    required categoryId,
    required plannedAmount,
    required scope,
  }) async {
    captured.add(plannedAmount.toDouble());
  };
}

Future<void> _openAndSave(
  WidgetTester tester, {
  required String amount,
}) async {
  final parent = find.byKey(const ValueKey('plan-parent-food'));
  await tester.ensureVisible(parent);
  await tester.tap(parent);
  await tester.pump();

  final child = find.byKey(const ValueKey('plan-child-market'));
  await tester.ensureVisible(child);
  await tester.pump();
  await tester.tap(child);
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const ValueKey('plan-budget-amount')),
    amount,
  );
  await tester.tap(find.byKey(const ValueKey('plan-save-budget')));
  await tester.pumpAndSettle();
}

List<BudgetOverviewItem> _fixture({double planned = 0, double actual = 0}) {
  return [
    _item(
      id: 'food',
      name: 'Alimentação',
      planned: planned,
      actual: actual,
    ),
    _item(
      id: 'market',
      name: 'Mercado',
      parentId: 'food',
      parentName: 'Alimentação',
      planned: planned,
      actual: actual,
    ),
    _item(id: 'transport', name: 'Transporte'),
    _item(
      id: 'fuel',
      name: 'Combustível',
      parentId: 'transport',
      parentName: 'Transporte',
    ),
  ];
}

List<BudgetOverviewItem> _longFixture() {
  final items = <BudgetOverviewItem>[];
  for (var index = 0; index < 18; index++) {
    final parentId = 'parent-$index';
    items
      ..add(
        _item(
          id: parentId,
          name: 'Categoria ${index.toString().padLeft(2, '0')}',
          planned: 100,
          actual: 20,
        ),
      )
      ..add(
        _item(
          id: 'child-$index',
          name: 'Subcategoria $index',
          parentId: parentId,
          parentName: 'Categoria ${index.toString().padLeft(2, '0')}',
          planned: 100,
          actual: 20,
        ),
      );
  }
  return items;
}

BudgetOverviewItem _item({
  required String id,
  required String name,
  String? parentId,
  String? parentName,
  double planned = 0,
  double actual = 0,
}) {
  return BudgetOverviewItem(
    categoryId: id,
    categoryName: name,
    parentId: parentId,
    parentName: parentName,
    essential: false,
    plannedAmount: planned,
    actualAmount: actual,
    remainingAmount: planned - actual,
    warningThreshold: .70,
    criticalThreshold: .90,
    usageRatio: planned > 0 ? actual / planned : 0,
    status: planned > 0 ? 'ok' : 'none',
    budgetSource: planned > 0 ? 'month' : 'none',
  );
}

class _FakePlanRepository implements FolegoRepository {
  _FakePlanRepository(this.items);

  final List<BudgetOverviewItem> items;
  int loads = 0;

  @override
  Future<List<BudgetOverviewItem>> getBudgetOverview({
    required String spaceId,
    required DateTime periodMonth,
  }) async {
    loads += 1;
    return List<BudgetOverviewItem>.from(items);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
