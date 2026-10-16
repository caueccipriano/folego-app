import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:folego/core/privacy/financial_privacy.dart';
import 'package:folego/data/models/budget_overview_item.dart';
import 'package:folego/data/models/folego_snapshot.dart';
import 'package:folego/data/repositories/folego_repository.dart';
import 'package:folego/features/home/folego_change_explanation.dart';
import 'package:folego/features/home/monthly_closing_review.dart';
import 'package:folego/data/models/monthly_money_summary.dart';
import 'package:folego/features/plan/category_period_comparison.dart';
import 'package:folego/features/plan/flexible_budget_screen.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));
  tearDown(() => FinancialPrivacy.hidden.value = false);
  test('fair windows handle February, leap years and early months', () {
    expect(comparableMonthDays(DateTime(2026, 3, 31)), 28);
    expect(comparableMonthDays(DateTime(2024, 3, 31)), 29);
    expect(comparableMonthDays(DateTime(2026, 10, 16)), 16);
    expect(comparableMonthDays(DateTime(2026, 1, 1)), 1);
  });
  test(
    'cutoff uses budget dates, deduplicates impacts and preserves credits',
    () {
      BudgetImpactDetail row(
        String id,
        int day,
        double value, {
        int month = 10,
      }) => BudgetImpactDetail(
        impactId: id,
        description: id,
        categoryName: 'lazer',
        eventType: 'expense',
        effectiveDate: DateTime(2026, month, day),
        budgetAmount: value,
      );
      final a = row('a', 1, 100);
      expect(
        budgetThroughDay(
          [
            a,
            a,
            row('refund', 3, -20),
            row('future', 17, 500),
            row('old', 1, 300, month: 9),
          ],
          DateTime(2026, 10),
          16,
        ),
        80,
      );
    },
  );
  for (final mode in Brightness.values) {
    for (final width in [320.0, 768.0, 1440.0]) {
      testWidgets(
        'back stays visible and works during a pending request $mode $width',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final pending = Completer<FlexibleBudgetOverview>();
          final repo = FolegoRepository(
            SupabaseClient('https://example.supabase.co', 'public-test-key'),
          );
          bool? returned;
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(brightness: mode),
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      returned = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => FlexibleBudgetScreen(
                            repository: repo,
                            spaceId: 'synthetic',
                            overviewLoader: (_) => pending.future,
                            itemsLoader: (_) async => [],
                          ),
                        ),
                      );
                    },
                    child: const Text('abrir'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('abrir'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          final back = find.byKey(const ValueKey('flex-budget-back'));
          expect(tester.getCenter(back).dy, lessThan(100));
          await tester.tap(back);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(returned, false);
          expect(find.text('abrir'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets(
    'closing review stays dismissible during pending category navigation',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final pending = Completer<void>();
      var opened = false;
      final summary = MonthlyMoneySummary.fromJson({
        'period_month': '2026-10-01',
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('revisar'),
                onPressed: () => showMonthlyClosingReview(
                  context,
                  summary: summary,
                  onReviewCategories: (sheetContext) async {
                    await pending.future;
                    if (sheetContext.mounted) opened = true;
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('revisar'));
      await tester.pumpAndSettle();
      final action = find.text('2 · resolver categorias pendentes');
      await tester.scrollUntilVisible(
        action,
        250,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('monthly-close-scroll')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.ensureVisible(action);
      await tester.pumpAndSettle();
      await tester.tap(action);
      await tester.pump();
      final close = find.byKey(const ValueKey('monthly-close-dismiss'));
      expect(tester.getCenter(close).dy, lessThan(220));
      await tester.tap(close);
      await tester.pumpAndSettle();
      pending.complete();
      await tester.pumpAndSettle();
      expect(opened, isFalse);
      expect(find.text('revisar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  test('session readings never cross repositories or financial spaces', () {
    final firstSession = Object();
    final secondSession = Object();
    final reading = FolegoSnapshot.fromJson({
      'as_of_date': '2026-10-16',
      'spendable_pool': 100,
    });
    expect(previousFolegoReading(firstSession, 'a', reading), isNull);
    expect(previousFolegoReading(firstSession, 'b', reading), isNull);
    expect(previousFolegoReading(secondSession, 'a', reading), isNull);
    expect(previousFolegoReading(firstSession, 'a', reading), isNull);
    final changed = FolegoSnapshot.fromJson({
      'as_of_date': '2026-10-16',
      'spendable_pool': 200,
    });
    expect(previousFolegoReading(firstSession, 'a', changed), same(reading));
    expect(previousFolegoReading(firstSession, 'a', changed), same(reading));
  });
  for (final mode in Brightness.values) {
    testWidgets('back remains at the top after long budget scrolling $mode', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = FolegoRepository(
        SupabaseClient('https://example.supabase.co', 'public-test-key'),
      );
      final overview = FlexibleBudgetOverview.fromJson({
        'period_month': '2026-10-01',
        'configured': true,
        'limit_amount': 1000,
        'used_amount': 400,
      });
      final items = List.generate(
        20,
        (i) => BudgetOverviewItem.fromJson({
          'category_id': '$i',
          'category_name': 'categoria $i',
          'parent_id': 'parent',
          'actual_amount': 20,
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: mode),
          home: FlexibleBudgetScreen(
            repository: repo,
            spaceId: 'synthetic',
            overviewLoader: (_) async => overview,
            itemsLoader: (_) async => items,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final back = find.byKey(const ValueKey('flex-budget-back'));
      final before = tester.getCenter(back);
      await tester.fling(
        find.byType(ListView).first,
        const Offset(0, -1800),
        1500,
      );
      await tester.pumpAndSettle();
      expect(tester.getCenter(back), before);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('component explanation responds immediately to privacy', (
    tester,
  ) async {
    FolegoSnapshot snapshot(int amount) => FolegoSnapshot.fromJson({
      'as_of_date': '2026-10-16',
      'spendable_pool': amount,
      'liquid_balance': amount + 100,
      'mandatory_outflows_until_income': 100,
      'cash_headroom': amount,
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FolegoChangeExplanation(
              current: snapshot(321),
              previous: snapshot(421),
            ),
          ),
        ),
      ),
    );
    expect(find.textContaining('variação:'), findsOneWidget);
    FinancialPrivacy.hidden.value = true;
    await tester.pump();
    expect(find.textContaining('321'), findsNothing);
    expect(find.textContaining('421'), findsNothing);
    expect(find.text('variação oculta'), findsOneWidget);
  });
}
