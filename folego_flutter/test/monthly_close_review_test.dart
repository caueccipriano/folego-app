import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:folego/data/models/monthly_money_summary.dart';
import 'package:folego/features/home/monthly_closing_review.dart';

void main() {
  setUpAll(() async => initializeDateFormatting('pt_BR'));

  final example = MonthlyMoneySummary.fromJson({
    'period_month': '2026-10-01',
    'income_amount': 3000,
    'spending_net': 1700,
    'competence_net': 1250,
    'movement_card_payments': 200,
  });

  testWidgets('month review starts unchecked and never auto-closes a period',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: MonthlyClosingReview(summary: example))),
    );
    await tester.pumpAndSettle();
    final done = find.byKey(const ValueKey('monthly-close-done'));
    expect(done, findsOneWidget);
    expect(tester.widget<FilledButton>(done).onPressed, isNull);
    expect(find.text('receitas reais'), findsOneWidget);
    expect(find.text('despesas por competência'), findsOneWidget);
    expect(find.textContaining('essas confirmações valem somente nesta tela'),
        findsOneWidget);

    for (var index = 0; index < 3; index++) {
      final check = find.byKey(ValueKey('monthly-close-check-$index'));
      await tester.ensureVisible(check);
      await tester.pumpAndSettle();
      await tester.tap(check);
      await tester.pumpAndSettle();
    }
    expect(tester.widget<FilledButton>(done).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  test('review can only be entered through a loaded Home month summary', () {
    final card = File('lib/features/home/home_monthly_money_card.dart')
        .readAsStringSync();
    final home = File('lib/features/home/home_screen_base.dart')
        .readAsStringSync();
    expect(card, contains("ValueKey('monthly-money-review')"));
    expect(card, contains('if (onOpenClosing != null)'));
    expect(home, contains('_monthlyMoney == null ? null'));
    expect(home, contains('showMonthlyClosingReview('));
  });
}
