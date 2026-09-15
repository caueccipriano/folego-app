import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/layout/app_breakpoints.dart';
import 'package:folego/data/models/budget_overview_item.dart';

BudgetOverviewItem item({
  required String id,
  required String name,
  String? parentId,
  double planned = 0,
  double actual = 0,
  double? usage,
  String status = 'none',
  String source = 'none',
  bool recurring = false,
}) {
  return BudgetOverviewItem(
    categoryId: id,
    categoryName: name,
    parentId: parentId,
    parentName: parentId == null ? null : 'Parent',
    essential: false,
    plannedAmount: planned,
    actualAmount: actual,
    remainingAmount: planned - actual,
    warningThreshold: .70,
    criticalThreshold: .90,
    usageRatio: usage ?? (planned > 0 ? actual / planned : 0),
    status: status,
    budgetSource: source,
    isRecurring: recurring,
  );
}

void main() {
  group('budget frequency state', () {
    test('maps month, monthly and cancellation scopes to backend contract', () {
      expect(BudgetLimitScope.month.rpcValue, 'month');
      expect(BudgetLimitScope.fromMonth.rpcValue, 'from_month');
      expect(
        BudgetLimitScope.cancelFromMonth.rpcValue,
        'cancel_from_month',
      );
    });

    test('parses once, recurring and month override sources', () {
      final once = BudgetOverviewItem.fromJson({
        'category_id': 'once',
        'category_name': 'Restaurante',
        'parent_id': 'food',
        'parent_name': 'Alimentação',
        'essential': false,
        'planned_amount': 500,
        'actual_amount': 100,
        'remaining_amount': 400,
        'warning_threshold': .7,
        'critical_threshold': .9,
        'usage_ratio': .2,
        'status': 'ok',
        'budget_source': 'month',
        'is_recurring': false,
      });
      final recurring = BudgetOverviewItem.fromJson({
        'category_id': 'monthly',
        'category_name': 'Mercado',
        'parent_id': 'food',
        'parent_name': 'Alimentação',
        'essential': false,
        'planned_amount': 700,
        'actual_amount': 200,
        'remaining_amount': 500,
        'warning_threshold': .7,
        'critical_threshold': .9,
        'usage_ratio': 200 / 700,
        'status': 'ok',
        'budget_source': 'recurring',
        'is_recurring': true,
      });
      final override = BudgetOverviewItem.fromJson({
        'category_id': 'override',
        'category_name': 'Mercado',
        'parent_id': 'food',
        'parent_name': 'Alimentação',
        'essential': false,
        'planned_amount': 850,
        'actual_amount': 200,
        'remaining_amount': 650,
        'warning_threshold': .7,
        'critical_threshold': .9,
        'usage_ratio': 200 / 850,
        'status': 'ok',
        'budget_source': 'override',
        'is_recurring': true,
      });

      expect(once.isRecurring, isFalse);
      expect(recurring.recurringLabel, 'todo mês');
      expect(override.isMonthlyOverride, isTrue);
      expect(override.recurringLabel, 'todo mês · ajuste do mês');
    });
  });

  group('budget progress', () {
    test('handles zero, partial, 100% and above 100%', () {
      expect(
        item(id: 'zero', name: 'Zero').progressState,
        BudgetProgressState.noLimit,
      );
      expect(
        item(id: 'partial', name: 'Parcial', planned: 100, actual: 50)
            .progressState,
        BudgetProgressState.comfortable,
      );
      expect(
        item(id: 'attention', name: 'Atenção', planned: 100, actual: 70)
            .progressState,
        BudgetProgressState.attention,
      );
      expect(
        item(id: 'full', name: 'Cheio', planned: 100, actual: 100)
            .progressState,
        BudgetProgressState.attention,
      );
      expect(
        item(
          id: 'over',
          name: 'Acima',
          planned: 100,
          actual: 120,
          status: 'exceeded',
        ).progressState,
        BudgetProgressState.exceeded,
      );
    });

    test('subcategory without budget can still expose actual activity', () {
      final noBudget = item(
        id: 'uber',
        name: 'Uber',
        parentId: 'transport',
        actual: 120,
      );

      expect(noBudget.hasBudget, isFalse);
      expect(noBudget.hasActivity, isTrue);
      expect(noBudget.progress, 0);
    });
  });

  group('month summary and parent aggregation', () {
    test('summary uses parents only and does not double count children', () {
      final parent = item(
        id: 'food',
        name: 'Alimentação',
        planned: 1200,
        actual: 700,
      );
      final market = item(
        id: 'market',
        name: 'Mercado',
        parentId: 'food',
        planned: 700,
        actual: 420,
      );
      final restaurant = item(
        id: 'restaurant',
        name: 'Restaurante',
        parentId: 'food',
        planned: 500,
        actual: 280,
      );

      final summary = BudgetMonthSummary.fromItems([
        parent,
        market,
        restaurant,
      ]);

      expect(parent.isParent, isTrue);
      expect(market.isSubcategory, isTrue);
      expect(summary.plannedAmount, 1200);
      expect(summary.actualAmount, 700);
      expect(summary.remainingAmount, 500);
    });

    test('empty month stays a valid zero summary', () {
      final summary = BudgetMonthSummary.fromItems(const []);
      expect(summary.plannedAmount, 0);
      expect(summary.actualAmount, 0);
      expect(summary.progressState, BudgetProgressState.noLimit);
    });
  });

  group('plan responsive targets', () {
    test('keeps target phones compact and scales through web widths', () {
      expect(AppBreakpoints.fromWidth(375), AppLayoutSize.compact);
      expect(AppBreakpoints.fromWidth(390), AppLayoutSize.compact);
      expect(AppBreakpoints.fromWidth(430), AppLayoutSize.compact);
      expect(AppBreakpoints.fromWidth(768), AppLayoutSize.medium);
      expect(AppBreakpoints.fromWidth(1024), AppLayoutSize.expanded);
      expect(AppBreakpoints.fromWidth(1366), AppLayoutSize.expanded);
      expect(AppBreakpoints.fromWidth(1440), AppLayoutSize.wide);
      expect(AppBreakpoints.fromWidth(1920), AppLayoutSize.wide);
    });
  });
}
