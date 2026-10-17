import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/privacy/financial_privacy.dart';
import 'package:folego/data/models/budget_overview_item.dart';
import 'package:folego/features/plan/monthly_category_donut.dart';
import 'package:folego/features/diary/diary_review_card.dart';

BudgetOverviewItem category(String id, double amount, {String? parent}) =>
    BudgetOverviewItem(
      categoryId: id,
      categoryName: id,
      parentId: parent,
      essential: false,
      plannedAmount: 0,
      actualAmount: amount,
      remainingAmount: -amount,
      warningThreshold: .8,
      criticalThreshold: 1,
      usageRatio: 0,
      status: 'ok',
    );

void main() {
  tearDown(() => FinancialPrivacy.hidden.value = false);
  final items = [
    category('Alimentação', 300),
    category('Lazer', 200),
    category('Restaurante', 100, parent: 'Alimentação'),
    category('Crédito', -50),
  ];
  test('parent and child aggregates are not added twice', () {
    final slices = monthlyCategorySlices(items);
    expect(slices.length, 2);
    expect(slices.fold<double>(0, (s, i) => s + i.actualAmount), 500);
  });
  for (final width in [320.0, 768.0, 1440.0]) {
    for (final mode in Brightness.values) {
      testWidgets('monthly donut and diary action fit $width $mode', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: mode),
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    DiaryReviewCard(
                      reviewed: 1,
                      total: 3,
                      onReview: () {},
                      onTransactions: () {},
                    ),
                    MonthlyCategoryDonut(items: items, onCategory: (_) {}),
                  ],
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const ValueKey('category-donut-paint')),
          findsOneWidget,
        );
        expect(find.textContaining('60,0%'), findsOneWidget);
        expect(find.textContaining('créditos líquidos'), findsOneWidget);
      });
    }
  }
  testWidgets(
    'legend opens the correct category and privacy hides proportions live',
    (tester) async {
      String? opened;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MonthlyCategoryDonut(
                items: items,
                onCategory: (i) => opened = i.categoryId,
              ),
            ),
          ),
        ),
      );
      final target = find.byKey(const ValueKey('category-donut-Alimentação'));
      await tester.ensureVisible(target);
      await tester.tap(target);
      expect(opened, 'Alimentação');
      FinancialPrivacy.hidden.value = true;
      await tester.pump();
      expect(find.byKey(const ValueKey('category-donut-paint')), findsNothing);
      expect(find.textContaining('60,0%'), findsNothing);
      expect(find.textContaining('500,00'), findsNothing);
    },
  );
  testWidgets(
    'review action is explicit and a completed month does not ask for another expense',
    (tester) async {
      var reviewed = false;
      Future<void> pump(int count, VoidCallback? action) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DiaryReviewCard(
              reviewed: count,
              total: 2,
              onReview: action,
              onTransactions: () {},
            ),
          ),
        ),
      );
      await pump(0, () => reviewed = true);
      await tester.tap(find.byKey(const ValueKey('diary-review-one')));
      expect(reviewed, isTrue);
      await pump(2, null);
      expect(find.byKey(const ValueKey('diary-review-one')), findsNothing);
      expect(
        find.textContaining('todos os gastos disponíveis'),
        findsOneWidget,
      );
    },
  );
  for (final width in [320.0, 390.0]) {
    testWidgets('donut center stays inside ring with large text at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(1.6)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: MonthlyCategoryDonut(
                items: [
                  category(
                    'Dívidas, financiamentos e compromissos de longo prazo',
                    1234567.89,
                  ),
                ],
                onCategory: (_) {},
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final ring = tester.getRect(
        find.byKey(const ValueKey('category-donut-paint')),
      );
      final center = tester.getRect(
        find.byKey(const ValueKey('category-donut-center')),
      );
      expect(center.width, lessThanOrEqualTo(ring.width * .61));
      expect(center.height, lessThan(ring.height - 48));
      expect(center.center, ring.center);
      expect(find.text('nas categorias acima de zero'), findsNothing);
      final explanation = find.byKey(
        const ValueKey('category-donut-explanation'),
      );
      await tester.ensureVisible(explanation);
      await tester.tap(find.text('Como esse gráfico é calculado'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Pagar a fatura não conta'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('empty month has no misleading donut', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MonthlyCategoryDonut(items: const [], onCategory: (_) {}),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('category-donut-paint')), findsNothing);
    expect(find.textContaining('ainda não há gastos'), findsOneWidget);
  });
}
