import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/privacy/financial_privacy.dart';
import 'package:folego/data/models/budget_overview_item.dart';
import 'package:folego/features/plan/plan_guidance.dart';
import 'package:folego/features/plan/plan_guidance_card.dart';

BudgetOverviewItem category(
  String id, {
  String? parent,
  bool essential = false,
  String source = 'none',
  double planned = 0,
  double actual = 0,
}) => BudgetOverviewItem(
  categoryId: id,
  categoryName: id,
  parentId: parent,
  parentName: parent == null ? null : 'Grupo',
  essential: essential,
  plannedAmount: planned,
  actualAmount: actual,
  remainingAmount: planned - actual,
  warningThreshold: .7,
  criticalThreshold: .9,
  usageRatio: planned <= 0 ? 0 : actual / planned,
  status: planned > 0 && actual > planned ? 'exceeded' : 'ok',
  budgetSource: source,
);

void main() {
  tearDown(() => FinancialPrivacy.hidden.value = false);

  test('review prioritizes pending and excess, then no-limit spending', () {
    final entries = [
      category('alimentação', planned: 200, actual: 350),
      category('mercado', parent: 'alimentação', planned: 200, actual: 350),
      category('compras', actual: 450),
      category('pendências', source: 'pending', actual: 25),
      category('transporte', planned: 200, actual: 130),
      category('assinaturas', planned: 300, actual: 100),
    ];
    final result = spendingReviewTargets(entries);
    expect(result.map((x) => x.category.categoryId),
      ['pendências', 'alimentação', 'compras']);
    expect(result.map((x) => x.reason),
      [PlanReviewReason.uncategorized, PlanReviewReason.overLimit,
       PlanReviewReason.noLimit]);
  });

  test('largest unbudgeted active subcategory is next, never a parent', () {
    final entries = [
      category('parent', actual: 800),
      category('one', parent: 'parent', actual: 80),
      category('two', parent: 'parent', actual: 350),
      category('budgeted', parent: 'parent', planned: 500, actual: 600),
      category('pending', source: 'pending', actual: 500),
    ];
    expect(nextPlanCategory(entries)?.categoryId, 'two');
    expect(nextPlanCategory([category('parent')]), isNull);
  });

  test('review action targets a real editable child instead of a parent', () {
    final parent = category('Compras', actual: 300);
    final items = [
      parent,
      category('Calçados', parent: 'Compras', actual: 200),
      category('Roupas', parent: 'Compras', actual: 100),
    ];
    expect(editableChildForReview(parent, items)?.categoryId, 'Calçados');
    expect(editableChildForReview(parent, [
      parent,
      category('Calçados', parent: 'Compras', planned: 250, actual: 200),
    ]), isNull);
    expect(editableChildForReview(
      category('Pendente', source: 'pending', actual: 20), items,
    ), isNull);
  });

  test('healthy established limits do not demand another edit', () {
    final entries = [
      category('Pai', planned: 200, actual: 40),
      category('Filho', parent: 'Pai', planned: 200, actual: 40),
    ];
    expect(nextPlanCategory(entries), isNull);
    expect(spendingReviewTargets(entries), isEmpty);
  });

  test('monthly read only amounts never create artificial warnings', () {
    final entries = [
      category('A', planned: 500, actual: 140),
      category('B', planned: 300, actual: 150),
    ];
    expect(spendingReviewTargets(entries), isEmpty);
  });

  testWidgets('guided planning shows real monthly spending and requires a tap',
      (tester) async {
    final items = [
      category('Alimentação', planned: 100, actual: 260),
      category('Restaurante', parent: 'Alimentação', actual: 260),
    ];
    BudgetOverviewItem? edited;
    BudgetOverviewItem? reviewed;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ListView(children: [
        PlanGuidanceCard(
          items: items,
          canEdit: true,
          onEdit: (item, _) => edited = item,
          onReviewSpending: (item) => reviewed = item,
        ),
      ])),
    ));
    await tester.pumpAndSettle();
    expect(edited, isNull);
    expect(find.byKey(const ValueKey('plan-guided-start')), findsOneWidget);
    expect(find.text('comece por: Restaurante'), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-largest-category')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('plan-guided-edit')));
    await tester.pump();
    expect(edited?.categoryId, 'Restaurante');
    await tester.ensureVisible(find.byKey(const ValueKey('plan-focus-Alimentação')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('plan-focus-Alimentação')));
    expect(reviewed?.categoryId, 'Alimentação');

    FinancialPrivacy.hidden.value = true;
    await tester.pump();
    expect(find.textContaining('R\$ ••••'), findsWidgets);
    expect(find.textContaining('260,00'), findsNothing);
  });

  testWidgets('one-tap actions classify and open child limit without saving',
      (tester) async {
    final items = [
      category('A classificar', source: 'pending', actual: 50),
      category('Compras', actual: 350),
      category('Tênis', parent: 'Compras', actual: 350),
    ];
    var classified = 0;
    var compared = 0;
    BudgetOverviewItem? edited;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ListView(children: [
        PlanGuidanceCard(
          items: items,
          canEdit: true,
          onEdit: (_, _) {},
          onReviewSpending: (_) {},
          onClassify: () => classified++,
          onEditReviewCategory: (item) => edited = item,
          onCompareMonths: () => compared++,
        ),
      ])),
    ));
    await tester.pumpAndSettle();
    final classify = find.byKey(const ValueKey('plan-focus-action-A classificar'));
    await tester.ensureVisible(classify);
    await tester.pumpAndSettle();
    await tester.tap(classify);
    expect(classified, 1);

    final review = find.byKey(const ValueKey('plan-focus-action-Compras'));
    await tester.ensureVisible(review);
    await tester.pumpAndSettle();
    await tester.tap(review);
    expect(edited?.categoryId, 'Tênis');

    final comparison = find.byKey(const ValueKey('plan-compare-months'));
    await tester.ensureVisible(comparison);
    await tester.pumpAndSettle();
    await tester.tap(comparison);
    expect(compared, 1);
  });

  testWidgets('private amounts also hide biggest-category percentage',
      (tester) async {
    FinancialPrivacy.hidden.value = true;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ListView(children: [
        PlanGuidanceCard(
          items: [
            category('Alimentação', actual: 300),
            category('Transporte', actual: 100),
          ],
          canEdit: false,
          onEdit: (_, _) {},
          onReviewSpending: (_) {},
        ),
      ])),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('75%'), findsNothing);
    expect(find.textContaining('R\$ ••••'), findsWidgets);
  });

  testWidgets('past months show no editable planning action', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ListView(children: [
        PlanGuidanceCard(
          items: [category('Grupo', actual: 45)],
          canEdit: false,
          onEdit: (_, _) => fail('should not edit past months'),
          onReviewSpending: (_) {},
        ),
      ])),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('plan-guided-edit')), findsNothing);
    expect(find.textContaining('apenas para consulta'), findsOneWidget);
  });
}
