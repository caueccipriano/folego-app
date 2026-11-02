import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/privacy/financial_privacy.dart';
import 'package:folego/data/models/budget_overview_item.dart';
import 'package:folego/features/plan/monthly_category_donut.dart';

BudgetOverviewItem _category(
  String id, {
  String? parentId,
  required double actual,
}) => BudgetOverviewItem(
  categoryId: id,
  categoryName: id,
  parentId: parentId,
  parentName: parentId == null ? null : 'Pai',
  essential: false,
  plannedAmount: 500,
  actualAmount: actual,
  remainingAmount: 500 - actual,
  warningThreshold: .7,
  criticalThreshold: .9,
  usageRatio: actual / 500,
  status: 'ok',
  budgetSource: 'month',
);

void main() {
  setUp(() => FinancialPrivacy.hidden.value = false);
  tearDown(() => FinancialPrivacy.hidden.value = false);

  test('slices include parent values exactly once, ordered by actual', () {
    final rows = monthlyCategorySlices([
      _category('alimentação', actual: 500),
      _category('mercado', actual: 400, parentId: 'alimentação'),
      _category('transporte', actual: 200),
      _category('estorno', actual: -100),
      _category('sem gasto', actual: 0),
    ]);
    expect(rows.map((r) => r.categoryId), ['alimentação', 'transporte']);
    expect(rows.fold<double>(0, (sum, r) => sum + r.actualAmount), 700);
  });

  testWidgets('share bars explain the dominant category without duplicates',
      (tester) async {
    final selected = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: MonthlyCategoryDonut(
            items: [
              _category('alimentação', actual: 500),
              _category('mercado', actual: 400, parentId: 'alimentação'),
              _category('transporte', actual: 200),
            ],
            onCategory: (r) => selected.add(r.categoryId),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('category-donut-top-contributor')),
        findsOneWidget);
    expect(find.textContaining('maior peso: alimentação'), findsOneWidget);
    expect(find.byKey(const ValueKey('category-share-progress-alimentação')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('category-share-progress-transporte')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('category-share-progress-mercado')),
        findsNothing);

    final share = tester.widget<LinearProgressIndicator>(
      find.byKey(const ValueKey('category-share-progress-alimentação')),
    );
    expect(share.value, closeTo(500 / 700, .001));

    await tester.ensureVisible(
      find.byKey(const ValueKey('category-donut-alimentação')),
    );
    await tester.tap(find.byKey(const ValueKey('category-donut-alimentação')));
    expect(selected, ['alimentação']);

    FinancialPrivacy.hidden.value = true;
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('category-donut-top-contributor')),
        findsNothing);
    expect(find.byKey(const ValueKey('category-share-progress-alimentação')),
        findsNothing);
    expect(find.byKey(const ValueKey('category-donut-hidden')),
        findsOneWidget);
  });
}
