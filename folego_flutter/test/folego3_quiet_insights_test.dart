import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/notifications/notification_models.dart';
import 'package:folego/core/privacy/financial_privacy.dart';
import 'package:folego/data/models/budget_overview_item.dart';
import 'package:folego/features/plan/plan_insights_section.dart';
import 'package:folego/features/profile/notification_essentials.dart';

PlanInsights _plan({bool issues = true, bool suggestions = true}) =>
    PlanInsights.fromJson({
      'economic_spending': 100,
      'debt_payments': 15,
      'budget_tracked': 115,
      'cash_outflows': 120,
      'cash_inflows': 220,
      'estimated_available_now': 90,
      'issues': issues
          ? [
              {
                'code': 'needs_classification',
                'title': 'conferir classificação',
                'description': 'despesa sem categoria',
                'count': 2,
                'amount': 32,
              },
            ]
          : [],
      'suggestions': suggestions
          ? [
              {
                'category_id': 'food',
                'category_name': 'Alimentação',
                'historical_average': 290,
                'suggested_limit': 320,
                'sample_months': 2,
              },
            ]
          : [],
    });

Widget _host(PlanInsightsSection section) => MaterialApp(
      home: Scaffold(
        body: ListView(children: [section]),
      ),
    );

void main() {
  tearDown(() => FinancialPrivacy.hidden.value = false);

  test('reduce notifications only with explicit opt-in, not all due-date alerts',
      () {
    const prefs = NotificationPreferences(
      spaceId: 'wallet-1',
      financialRemindersEnabled: true,
      dailySummaryEnabled: true,
      weeklyReviewEnabled: true,
      commitmentEnabled: true,
      transactionActivityEnabled: true,
      invoicesEnabled: true,
      debtsEnabled: true,
      overdueEnabled: true,
      planThresholdsEnabled: true,
      cardLimitThresholdsEnabled: true,
      largeExpensesEnabled: true,
    );
    expect(essentialNotificationsOnly(prefs), isFalse);
    final quiet = reduceNotificationNoise(prefs);
    expect(essentialNotificationsOnly(quiet), isTrue);
    expect(quiet.spaceId, prefs.spaceId);
    expect(quiet.financialRemindersEnabled, isTrue);
    expect(quiet.invoicesEnabled, isTrue);
    expect(quiet.debtsEnabled, isTrue);
    expect(quiet.overdueEnabled, isTrue);
    expect(quiet.planThresholdsEnabled, isTrue);
    expect(quiet.cardLimitThresholdsEnabled, isTrue);
    expect(quiet.largeExpensesEnabled, isTrue);
    expect(reduceNotificationNoise(quiet).toUpsertJson('user'),
        quiet.toUpsertJson('user'));
  });

  test('quiet mode is user-triggered and advanced notification choices survive',
      () {
    final screen = File('lib/features/profile/notification_settings_screen.dart')
        .readAsStringSync();
    expect(screen, contains("ValueKey('notifications-essentials-action')"));
    expect(screen, contains('reduceNotificationNoise(prefs)'));
    expect(screen, contains('_dailySummarySection(prefs)'));
    expect(screen, contains('_toneSection(prefs)'));
    expect(screen, contains("ValueKey('notification-advanced-options')"));
    expect(screen, contains('_typesSection(prefs)'));
    expect(screen, contains('_realtimeSection(prefs)'));
    expect(screen, contains('_quietHoursSection(prefs)'));
  });

  testWidgets('one prioritized issue expands its actual audit', (tester) async {
    await tester.pumpWidget(_host(PlanInsightsSection(
      insights: Future.value(_plan()),
      onReviewSuggestion: (_) {},
    )));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('plan-one-next-step')), findsOneWidget);
    expect(find.text('conferir classificação'), findsOneWidget);
    expect(find.text('uma sugestão para seu orçamento'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('plan-next-step-action')));
    await tester.pumpAndSettle();
    expect(find.textContaining('checagem de lançamentos sem categoria'), findsOneWidget);
  });

  testWidgets('with no issue, the single suggestion only opens review',
      (tester) async {
    PlanSuggestion? pending;
    await tester.pumpWidget(_host(PlanInsightsSection(
      insights: Future.value(_plan(issues: false)),
      onReviewSuggestion: (value) => pending = value,
    )));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('plan-one-next-step')), findsOneWidget);
    expect(pending, isNull);
    await tester.tap(find.byKey(const ValueKey('plan-next-step-action')));
    expect(pending?.categoryId, 'food');
    expect(pending?.suggestedLimit, 320);
  });

  testWidgets('no tasks means no extra insight card', (tester) async {
    await tester.pumpWidget(_host(PlanInsightsSection(
      insights: Future.value(_plan(issues: false, suggestions: false)),
    )));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('plan-one-next-step')), findsNothing);
  });

  testWidgets('private values remain masked in prioritized suggestion',
      (tester) async {
    FinancialPrivacy.hidden.value = true;
    await tester.pumpWidget(_host(PlanInsightsSection(
      insights: Future.value(_plan(issues: false)),
      onReviewSuggestion: (_) {},
    )));
    await tester.pumpAndSettle();
    expect(find.textContaining('R\$ ••••'), findsWidgets);
    expect(find.textContaining('320,00'), findsNothing);
  });
}
