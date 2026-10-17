import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/realtime/realtime_invalidation.dart';
import 'package:folego/core/realtime/realtime_session.dart';
import 'package:folego/core/theme/app_icons.dart';
import 'package:folego/data/models/budget_overview_item.dart';
import 'package:folego/data/models/category_item.dart';
import 'package:folego/data/models/financial_space.dart';
import 'package:folego/data/models/recurring_item.dart';
import 'package:folego/data/models/transaction_filters.dart';
import 'package:folego/data/models/transaction_item.dart';
import 'package:folego/data/models/transaction_page.dart';
import 'package:folego/data/repositories/folego_repository.dart';
import 'package:folego/features/plan/plan_screen.dart' as realtime_plan;
import 'package:folego/features/transactions/transactions_screen_base.dart';
import 'package:folego/shared/widgets/category_search_picker.dart';

void main() {
  testWidgets('categories realtime refreshes Plan with new closed hierarchy and preserves state', (
    tester,
  ) async {
    final repository = _MutablePlanRepository(_longPlanFixture());
    final coordinator = RealtimeInvalidationCoordinator();
    AppRealtimeRegistry.attach(coordinator);
    addTearDown(() {
      AppRealtimeRegistry.detach(coordinator);
      coordinator.dispose();
    });
    _setViewport(tester, const Size(390, 700));

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

    final scroll = find.byKey(const ValueKey('plan-scroll'));
    final openParent = find.byKey(const ValueKey('plan-parent-parent-7'));
    await tester.dragUntilVisible(openParent, scroll, const Offset(0, -300));
    await tester.pump();
    await tester.ensureVisible(openParent);
    await tester.pump();
    await tester.tap(openParent);
    await tester.pump();
    expect(find.byKey(const ValueKey('plan-children-parent-7')), findsOneWidget);
    final before = _scrollPosition(tester, scroll).pixels;
    expect(before, greaterThan(0));

    repository.items.addAll([
      _planItem(id: 'travel', name: 'Viagens'),
      _planItem(
        id: 'hotel',
        name: 'Hospedagem',
        parentId: 'travel',
        parentName: 'Viagens',
      ),
    ]);

    coordinator.invalidateDomains(domainsForRealtimeTable('categories'));
    await tester.pump(const Duration(milliseconds: 250));
    await _flush(tester);

    expect(repository.loads, greaterThanOrEqualTo(2));
    expect(find.byKey(const ValueKey('plan-children-parent-7')), findsOneWidget);
    expect(_scrollPosition(tester, scroll).pixels, greaterThan(0));
    expect(find.byKey(const ValueKey('plan-parent-travel')), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-children-travel')), findsNothing);
  });

  testWidgets('Quick Register category picker exposes a new custom icon_key', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    const category = CategoryItem(
      id: 'custom-travel',
      name: 'Viagens locais',
      essential: false,
      kind: 'expense',
      iconKey: 'travel',
      colorHex: '#8C8CA8',
      categoryRole: 'economic',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 700,
            child: CategorySearchPicker(
              categories: [category],
              eventType: 'expense',
              dialogMode: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Viagens locais'), findsOneWidget);
    expect(find.byIcon(AppIcons.categoryTravel), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('categories realtime refreshes filter taxonomy without refetching keyset page', (
    tester,
  ) async {
    const space = FinancialSpace(id: 'space-1', name: 'Pessoal');
    final repository = _TransactionsRepository();
    final coordinator = RealtimeInvalidationCoordinator();
    AppRealtimeRegistry.attach(coordinator);
    addTearDown(() {
      AppRealtimeRegistry.detach(coordinator);
      coordinator.dispose();
    });

    var pageLoads = 0;
    var optionLoads = 0;
    var categories = const <CategoryItem>[];

    await tester.pumpWidget(
      MaterialApp(
        home: TransactionsScreenV3(
          repository: repository,
          space: space,
          pageLoader: ({
            required spaceId,
            required filters,
            required cursor,
            required pageSize,
          }) async {
            pageLoads += 1;
            expect(pageSize, transactionPageSize);
            return const TransactionPage(
              items: <TransactionItem>[],
              hasMore: false,
              nextCursor: null,
            );
          },
          optionsLoader: (_) async {
            optionLoads += 1;
            return TransactionFilterOptions(categories: categories);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(pageLoads, 1);
    expect(optionLoads, 1);

    categories = const [
      CategoryItem(
        id: 'new-category',
        name: 'Nova categoria',
        essential: false,
        kind: 'expense',
        iconKey: 'gift',
        categoryRole: 'economic',
      ),
    ];
    coordinator.invalidate(AppRealtimeDomain.categories);
    coordinator.invalidate(AppRealtimeDomain.categories);
    coordinator.invalidate(AppRealtimeDomain.categories);

    await tester.pump(const Duration(milliseconds: 249));
    expect(optionLoads, 1);
    expect(pageLoads, 1);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    await tester.pump();

    expect(optionLoads, 2);
    expect(pageLoads, 1);

    await tester.tap(find.byKey(const ValueKey('transaction-filter-button')));
    await tester.pumpAndSettle();
    final categoryPicker = find.byKey(
      const ValueKey('transaction-category-filter-picker'),
    );
    await tester.ensureVisible(categoryPicker);
    await tester.tap(categoryPicker);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('category-search-field')), findsOneWidget);
    expect(find.text('Nova categoria'), findsOneWidget);
  });

  testWidgets('categories table targets canonical domains with central 250ms debounce', (
    tester,
  ) async {
    final domains = domainsForRealtimeTable('categories');
    expect(domains, contains(AppRealtimeDomain.categories));
    expect(domains, contains(AppRealtimeDomain.plan));
    expect(domains, isNot(contains(AppRealtimeDomain.transactions)));

    final coordinator = RealtimeInvalidationCoordinator();
    expect(coordinator.debounce, const Duration(milliseconds: 250));
    var categoryRefreshes = 0;
    var planRefreshes = 0;
    final categoryBinding = coordinator.bind(
      domain: AppRealtimeDomain.categories,
      onRefresh: () async => categoryRefreshes += 1,
    );
    final planBinding = coordinator.bind(
      domain: AppRealtimeDomain.plan,
      onRefresh: () async => planRefreshes += 1,
    );

    for (var i = 0; i < 5; i++) {
      coordinator.invalidateDomains(domains);
    }
    await tester.pump(const Duration(milliseconds: 249));
    expect(categoryRefreshes, 0);
    expect(planRefreshes, 0);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    expect(categoryRefreshes, 1);
    expect(planRefreshes, 1);
    categoryBinding.dispose();
    planBinding.dispose();
    coordinator.dispose();
  });
}

void _setViewport(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
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

List<BudgetOverviewItem> _longPlanFixture() {
  final items = <BudgetOverviewItem>[];
  for (var index = 0; index < 18; index++) {
    final parentId = 'parent-$index';
    items
      ..add(
        _planItem(
          id: parentId,
          name: 'Categoria ${index.toString().padLeft(2, '0')}',
          planned: 100,
          actual: 20,
        ),
      )
      ..add(
        _planItem(
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

BudgetOverviewItem _planItem({
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

class _MutablePlanRepository implements FolegoRepository {
  _MutablePlanRepository(this.items);

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

class _TransactionsRepository implements FolegoRepository {
  @override
  Future<List<RecurringItem>> listRecurringItems(String spaceId) async =>
      const <RecurringItem>[];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
