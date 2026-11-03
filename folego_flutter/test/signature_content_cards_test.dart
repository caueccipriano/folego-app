import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/privacy/financial_privacy.dart';
import 'package:folego/core/theme/app_theme.dart';
import 'package:folego/data/models/budget_overview_item.dart';
import 'package:folego/data/models/financial_goal.dart';
import 'package:folego/features/goals/goals_widgets.dart';
import 'package:folego/features/plan/monthly_category_donut.dart';
import 'package:intl/date_symbol_data_local.dart';

FinancialGoal _goal() => FinancialGoal(
  id: 'compact-goal',
  spaceId: 's',
  name: 'Notebook novo',
  target: 5000,
  targetDate: DateTime(2027, 2, 1),
  icon: GoalIcon.deviceLaptop,
  status: GoalStatus.active,
  currentAmount: 1200,
  createdAt: DateTime(2026, 11, 1),
  updatedAt: DateTime(2026, 11, 1),
);

BudgetOverviewItem _category() => BudgetOverviewItem(
  categoryId: 'mercado',
  categoryName: 'mercado',
  parentId: null,
  parentName: null,
  essential: true,
  plannedAmount: 800,
  actualAmount: 275,
  remainingAmount: 525,
  warningThreshold: .7,
  criticalThreshold: .9,
  usageRatio: 275 / 800,
  status: 'ok',
  budgetSource: 'month',
);

void main() {
  setUpAll(() async => initializeDateFormatting('pt_BR'));
  setUp(() => FinancialPrivacy.hidden.value = false);
  tearDown(() => FinancialPrivacy.hidden.value = false);

  for (final width in [320.0, 390.0]) {
    for (final mode in [Brightness.light, Brightness.dark]) {
      testWidgets('Signature goal card fits iPhone $width $mode and retains tap',
          (tester) async {
        tester.view.physicalSize = Size(width, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var taps = 0;
        await tester.pumpWidget(MaterialApp(
          theme: mode == Brightness.dark ? AppTheme.dark() : AppTheme.light(),
          home: Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  height: 190,
                  child: GoalCard(goal: _goal(), onTap: () => taps++),
                ),
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        expect(find.text('Notebook novo'), findsOneWidget);
        expect(find.text('ACUMULADO / OBJETIVO'), findsOneWidget);
        expect(find.byType(GoalProgressBar), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Notebook novo'));
        expect(taps, 1);
      });

      testWidgets('Signature category chart fits iPhone $width $mode',
          (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(MaterialApp(
          theme: mode == Brightness.dark ? AppTheme.dark() : AppTheme.light(),
          home: Scaffold(
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: MonthlyCategoryDonut(
                  items: [_category()],
                  onCategory: (_) {},
                ),
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        expect(find.text('seu mês por categoria'), findsOneWidget);
        expect(find.byKey(const ValueKey('category-donut-paint')), findsOneWidget);
        expect(find.byKey(const ValueKey('category-share-progress-mercado')), findsOneWidget);
        expect(tester.takeException(), isNull);

        FinancialPrivacy.hidden.value = true;
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('category-donut-paint')), findsNothing);
        expect(find.byKey(const ValueKey('category-donut-hidden')), findsOneWidget);
        expect(tester.takeException(), isNull);
        FinancialPrivacy.hidden.value = false;
      });
    }
  }

  test('real screen cards retain values, navigation and privacy contracts', () {
    final wallet = File('lib/features/wallet/wallet_screen_base.dart')
        .readAsStringSync();
    final movements = File('lib/features/transactions/transactions_screen_base.dart')
        .readAsStringSync();
    final plan = File('lib/features/plan/plan_screen_web2.dart')
        .readAsStringSync();
    final donut = File('lib/features/plan/monthly_category_donut.dart')
        .readAsStringSync();
    expect(wallet, contains("ValueKey('wallet-summary-available')"));
    expect(wallet, contains('Formatters.money(metric.value)'));
    expect(wallet, contains('FinancialPrivacy.hidden'));
    expect(wallet, contains('tokens.marca.withValues(alpha: .18)'));
    expect(movements, contains('onTap: onOpen'));
    expect(movements, contains("ValueKey('transaction-row-amount')"));
    expect(movements, contains('transactionAmountNeedsOwnLine('));
    expect(plan, contains('summary.usageRatio.clamp(0.0, 1.0)'));
    expect(plan, contains("ValueKey('plan-summary-featured-amount')"));
    expect(donut, contains('monthlyCategorySlices(widget.items)'));
    expect(donut, contains('FinancialPrivacy.hidden'));
    expect(donut, contains('monthlyCategoryHit('));
  });
}
