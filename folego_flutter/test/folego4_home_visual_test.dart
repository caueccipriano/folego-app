import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/features/home/home_fixed_dashboard.dart')
      .readAsStringSync();

  test('Fôlego 4 keeps the daily amount as the principal hero value', () {
    expect(source, contains('Formatters.money('));
    expect(source, contains('snapshot.dailyFolego'));
    expect(source, contains("home-fixed-daily-folego"));
    expect(source, contains('Formatters.money(snapshot.spendablePool)'));
    expect(source, contains("ValueKey('home-fixed-spendable')"));
    expect(source, contains('FinancialPrivacy.maskMoney()'));
  });

  test('Monthly progress only appears for configured, visible budgets', () {
    expect(source, contains('!hidden &&'));
    expect(source, contains('snapshot.budgetConfigured &&'));
    expect(source, contains('snapshot.monthlyBudgetPlanned > 0'));
    expect(source, contains('budgetPercent > 100'));
    expect(source, contains('acima do planejado'));
    expect(source, contains('minHeight: 6'));
  });

  test('Premium visual retains tappable actions and accessible rhythm label', () {
    expect(source, contains("ValueKey('home-fixed-viewport')"));
    expect(source, contains("home-fixed-rhythm-badge"));
    expect(source, contains('final paceLabel = switch (snapshot.status)'));
    expect(source, contains('Positioned.fill('));
    expect(source, contains("ValueKey('home-fixed-spendable-tap')"));
    expect(source, contains("ValueKey('home-open-full-details')"));
    expect(source, contains('onTap: onDetails'));
    expect(source, contains('onTap: onExpense'));
    expect(source, contains('onTap: onIncome'));
    expect(source, isNot(contains('SingleChildScrollView(')));
    expect(source, isNot(contains('ListView(')));
  });
}
