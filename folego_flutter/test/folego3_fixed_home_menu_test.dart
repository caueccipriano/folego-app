import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Home compacta tem viewport fixo e detalhes independentes', () {
    final home = File('lib/features/home/home_screen_base.dart')
      .readAsStringSync();
    final fixed = File('lib/features/home/home_fixed_dashboard.dart')
      .readAsStringSync();
    final active = home.indexOf('return HomeFixedDashboard(');
    final scroll = home.indexOf('return ColoredBox(', active);
    expect(active, greaterThanOrEqualTo(0));
    expect(scroll, greaterThan(active));
    expect(fixed, contains("ValueKey('home-fixed-viewport')"));
    expect(fixed, isNot(contains('ListView(')));
    expect(fixed, isNot(contains('SingleChildScrollView(')));
    expect(fixed, contains("ValueKey('home-open-full-details')"));
    expect(home, contains('Future<void> _openFixedDetails('));
    expect(home, contains('home-fixed-spending-comparison'));
  });

  test('Home fixa mostra o valor do snapshot e respeita privacidade', () {
    final fixed = File('lib/features/home/home_fixed_dashboard.dart')
      .readAsStringSync();
    expect(fixed, contains('Formatters.money(snapshot.spendablePool)'));
    expect(fixed, contains('FinancialPrivacy.maskMoney()'));
    expect(fixed, contains("ValueKey('home-fixed-spendable')"));
    expect(fixed, contains('homeIncomeTimingLabel(snapshot)'));
    final home = File('lib/features/home/home_screen_base.dart')
      .readAsStringSync();
    expect(home, contains('if (!FinancialPrivacy.hidden.value)'));
  });

  test('Dock tem abas diárias e área Mais igualmente clicável', () {
    final nav = File('lib/shared/widgets/liquid_glass_navigation_bar.dart')
      .readAsStringSync();
    expect(nav, contains("label: 'hoje'"));
    expect(nav, contains("label: 'movimentos'"));
    expect(nav, contains("label: 'futuro'"));
    expect(nav, contains("ValueKey('mobile-tools-button')"));
    expect(nav, contains("Text('mais'"));
    expect(nav, contains('selected: selectedIndex >= 3'));
    expect(nav, isNot(contains('gradient: LinearGradient(')));
    expect(nav, isNot(contains('BackdropFilter(')));
  });

  test('Compras pagas continuam com edicao so de rotulos', () {
    final sheet = File('lib/features/transactions/transaction_action_sheets.dart')
      .readAsStringSync();
    final actions = File('lib/data/repositories/folego_repository_transaction_actions.dart')
      .readAsStringSync();
    expect(sheet, contains('updateCardPurchaseLabels('));
    expect(sheet, contains('enabled: _financialEditable'));
    expect(actions, contains("'update_card_purchase_labels'"));
  });
}
