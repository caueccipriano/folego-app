import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/privacy/financial_privacy.dart';
import 'package:folego/data/models/budget_overview_item.dart';
import 'package:folego/features/panorama/panorama_category_comparison.dart';
import 'package:folego/features/panorama/panorama_category_trend.dart';

BudgetOverviewItem _cat(String id, double used, {String? parent}) =>
    BudgetOverviewItem(
      categoryId: id,
      categoryName: id,
      parentId: parent,
      essential: false,
      plannedAmount: 0,
      actualAmount: used,
      remainingAmount: -used,
      warningThreshold: .7,
      criticalThreshold: .9,
      usageRatio: 0,
      status: 'none',
    );

PanoramaCategoryTrend _data({
  double old = 100,
  double recent = 150,
}) =>
    PanoramaCategoryTrend.tryFrom(
      earlier: PanoramaCategoryMonth(
        periodMonth: DateTime(2026, 7),
        categories: [_cat('Categoria fictícia', old)],
      ),
      later: PanoramaCategoryMonth(
        periodMonth: DateTime(2026, 8),
        categories: [_cat('Categoria fictícia', recent)],
      ),
      referenceDate: DateTime(2026, 9, 29),
    )!;

Future<void> _pump(WidgetTester tester, PanoramaCategoryTrend? trend) async {
  tester.view.physicalSize = const Size(350, 760);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PanoramaCategoryComparison(trend: trend),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => FinancialPrivacy.hidden.value = false);
  tearDown(() => FinancialPrivacy.hidden.value = false);

  testWidgets('compact category movement explicitly labels recorded differences',
      (tester) async {
    await _pump(tester, _data());
    expect(find.byKey(const ValueKey('panorama-category-comparison')),
        findsOneWidget);
    expect(find.text('mudanças por categoria'), findsOneWidget);
    expect(find.text('Categoria fictícia'), findsOneWidget);
    expect(find.textContaining('a mais'), findsOneWidget);
    expect(find.textContaining('Não inclui automaticamente'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unavailable month never renders false zero-history conclusion',
      (tester) async {
    await _pump(tester, null);
    expect(find.byKey(const ValueKey('panorama-category-unavailable')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('panorama-category-no-match')),
        findsNothing);
  });

  testWidgets('matched categories with no changes differ from missing match',
      (tester) async {
    await _pump(tester, _data(old: 100, recent: 100));
    expect(find.byKey(const ValueKey('panorama-category-no-change')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('panorama-category-unavailable')),
        findsNothing);
  });

  testWidgets('hide-values also suppresses category labels and direction',
      (tester) async {
    await _pump(tester, _data());
    expect(find.text('Categoria fictícia'), findsOneWidget);
    FinancialPrivacy.hidden.value = true;
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('panorama-category-hidden')),
        findsOneWidget);
    expect(find.text('Categoria fictícia'), findsNothing);
    expect(find.textContaining('a mais'), findsNothing);
    expect(find.textContaining('100,00'), findsNothing);
    expect(find.textContaining('150,00'), findsNothing);
    FinancialPrivacy.hidden.value = false;
    await tester.pumpAndSettle();
    expect(find.text('Categoria fictícia'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
