import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Hoje removes the daily review ritual but keeps real exceptions', () {
    final home = File('lib/features/home/home_screen_base.dart')
        .readAsStringSync();
    final profile = File('lib/features/profile/profile_screen_v2.dart')
        .readAsStringSync();

    expect(home, isNot(contains('DailyReviewCard(')));
    expect(home, isNot(contains("ValueKey('home-optional-review')")));
    expect(home, contains('SmartCheckinCard('));
    expect(home, contains('home-monthly-details'));
    expect(home, contains('if (showLatest) ...['));
    expect(profile, contains("title: 'revisar lançamentos'"));
  });

  test('Plan does not duplicate the Tools shortcuts', () {
    final plan = File('lib/features/plan/plan_screen_web2.dart')
        .readAsStringSync();
    final shell = File('lib/features/shell/home_shell.dart')
        .readAsStringSync();

    expect(plan, isNot(contains('plan-more-tools')));
    expect(plan, isNot(contains('_extraPlanningTools')));
    expect(shell, contains("ValueKey('tools-wallet')"));
    expect(shell, contains("ValueKey('tools-goals')"));
    expect(shell, contains("ValueKey('tools-diary')"));
    expect(shell, contains("ValueKey('tools-profile')"));
    expect(plan, contains("ValueKey('plan-can-i-buy')"));
  });

  test('Core values, payments and backend are not modified in UX cleanup', () {
    final home = File('lib/features/home/home_screen_base.dart')
        .readAsStringSync();
    final plan = File('lib/features/plan/plan_screen_web2.dart')
        .readAsStringSync();
    expect(home, contains('HomeDataFreshness('));
    expect(home, contains('HomeMonthlyMoneyCard('));
    expect(plan, contains('MonthlyCategoryDonut('));
    expect(plan, contains('PlanGuidanceCard('));
  });
}
