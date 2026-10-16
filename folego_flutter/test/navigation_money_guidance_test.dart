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
