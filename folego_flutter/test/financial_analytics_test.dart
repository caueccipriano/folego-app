import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:folego/core/privacy/financial_privacy.dart';
import 'package:folego/core/theme/app_theme.dart';
import 'package:folego/data/models/budget_overview_item.dart';
import 'package:folego/data/models/monthly_money_summary.dart';
import 'package:folego/data/repositories/folego_repository.dart';
import 'package:folego/features/home/financial_analytics_models.dart';
import 'package:folego/features/home/financial_analytics_screen.dart';

class _FakeRepository implements FolegoRepository {
  const _FakeRepository();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

MonthlyMoneySummary _month(DateTime date) =>
    MonthlyMoneySummary.fromJson({
      'period_month':
          '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-01',
      'income_amount': date.month * 100.0,
      'spending_net': date.month * 50.0,
      'competence_net': date.month * 60.0,
    });

BudgetOverviewItem _category(String id, String name, double amount,
    {String? parent}) =>
    BudgetOverviewItem.fromJson({
      'category_id': id,
      'category_name': name,
      'parent_id': parent,
      'actual_amount': amount,
      'planned_amount': 500,
      'remaining_amount': 500 - amount,
      'usage_ratio': amount / 500,
      'status': 'ok',
    });

void main() {
  test('closed months are ordered, including cross-year boundaries', () {
    final months = recentClosedMonths(DateTime(2026, 1, 5));
    expect(months.first, DateTime(2025, 7));
    expect(months.last, DateTime(2025, 12));
    expect(months.length, 6);
    expect(analyticsMonthLabel(months.last), 'dez/25');
    expect(() => recentClosedMonths(DateTime(2026, 1), count: 0),
        throwsRangeError);
  });

  test('incomes and purchase-date spending are separate from competence', () {
    final data = FinancialAnalyticsSeries([
      MonthlyMoneySummary.fromJson({
        'period_month': '2026-08-01',
        'income_amount': 1500,
        'spending_net': 800,
        'competence_net': 900,
      }),
      MonthlyMoneySummary.fromJson({
        'period_month': '2026-09-01',
        'income_amount': 1800,
        'spending_net': 600,
        'competence_net': 700,
      }),
    ]);
    expect(data.totalIncome, 3300);
    expect(data.totalSpending, 1400);
    expect(data.totalEconomicResult, 1700);
    expect(data.maximumActivity, 1800);
    expect(data.spendingChange(data.months.last), -200);
    expect(data.spendingChange(data.months.first), isNull);
  });

  test('parent category distribution never sums subcategories twice', () {
    final parent = _category('food', 'Alimentação', 500);
    final child = _category('market', 'Mercado', 350, parent: 'food');
    final transport = _category('transport', 'Transporte', 300);
    final ordered = FinancialAnalyticsSeries.parentCategories([
      child, transport, parent,
    ]);
    expect(ordered.map((c) => c.categoryId), ['food', 'transport']);
    expect(FinancialAnalyticsSeries.parentTotal([child, transport, parent]), 800);
  });

  for (final width in [320.0, 390.0]) {
    testWidgets('interactive chart selects complete months on iPhone $width',
        (tester) async {
      FinancialPrivacy.hidden.value = false;
      addTearDown(() => FinancialPrivacy.hidden.value = false);
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final captured = <DateTime>[];
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: FinancialAnalyticsScreen(
          repository: const _FakeRepository(),
          spaceId: 'analytics-demo',
          referenceDate: DateTime(2026, 11, 5),
          monthLoader: (month) async {
            captured.add(month);
            return _month(month);
          },
          categoryLoader: (month) async => [
            _category('food', 'Alimentação', 200),
            _category('transport', 'Transporte', 100),
          ],
        ),
      ));
      await tester.pumpAndSettle();
      expect(captured.length, 6);
      expect(captured.first, DateTime(2026, 5));
      expect(captured.last, DateTime(2026, 10));
      expect(find.text('mês selecionado · out/26'), findsOneWidget);
      expect(find.byKey(const ValueKey('analytics-income')), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('monthly-category-donut')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('category-donut-paint')),
          findsOneWidget);
      expect(find.textContaining('out/26'), findsWidgets);
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(
        find.byKey(const ValueKey('analytics-month-3')),
      );
      await tester.tap(find.byKey(const ValueKey('analytics-month-3')));
      await tester.pumpAndSettle();
      expect(find.text('mês selecionado · ago/26'), findsOneWidget);
      expect(tester.takeException(), isNull);

      FinancialPrivacy.hidden.value = true;
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('analytics-privacy')), findsOneWidget);
      expect(find.byKey(const ValueKey('analytics-economic-result')),
          findsNothing);
      expect(find.byKey(const ValueKey('analytics-income')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('analytics provides a controlled retry after a failed month',
      (tester) async {
    FinancialPrivacy.hidden.value = false;
    var fail = true;
    await tester.pumpWidget(MaterialApp(
      home: FinancialAnalyticsScreen(
        repository: const _FakeRepository(),
        spaceId: 'retry',
        referenceDate: DateTime(2026, 11, 5),
        monthLoader: (month) async {
          if (fail) throw StateError('simulated network failure');
          return _month(month);
        },
        categoryLoader: (month) async => [],
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Não consegui carregar a evolução agora.'),
        findsOneWidget);
    fail = false;
    await tester.tap(find.text('tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('mês selecionado · out/26'), findsOneWidget);
  });
}
