import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final home = File('lib/features/home/home_screen_base.dart')
      .readAsStringSync();
  final begin = home.indexOf('Widget _buildFixedMobileHome({');
  final end = home.indexOf('Future<void> _openFixedMobileDetails({', begin);
  final active = home.substring(begin, end);

  test('ordinary iPhone sizes render the Home that Aurora actually styles', () {
    expect(home, contains('MediaQuery.sizeOf(context).height >= 540'));
    expect(home, contains('return _buildFixedMobileHome('));
    expect(active, contains('FolegoAmbientBackdrop('));
    expect(active, contains('color: tokens.superficie'));
    expect(active, contains('color: tokens.marca'));
    expect(active, contains('border: Border.all(color: tokens.borda)'));
    expect(active, contains("ValueKey('home-fixed-spendable')"));
    expect(active, contains("ValueKey('home-fixed-amount')"));
  });

  test('banking-grade visual system is on the active Home', () {
    expect(home, contains('FÔLEGO  /  HOJE'));
    expect(active, contains('disponível até receber'));
    expect(active, contains('seu fôlego por dia'));
    expect(active, contains('próxima entrada'));
    expect(active, contains('color: tokens.marca'));
    expect(active, contains("ValueKey('home-fixed-amount')"));
    expect(active, contains("ValueKey('home-fixed-daily')"));
    final summary = File('lib/features/home/home_mobile_summary_strip.dart')
        .readAsStringSync();
    expect(summary, contains("ValueKey('home-mobile-budget-value')"));
    expect(summary, contains('budgetExceeded'));
    expect(summary, contains('FolegoColorTokens.of(context)'));
    final nav = File('lib/shared/widgets/liquid_glass_navigation_bar.dart')
        .readAsStringSync();
    expect(nav, contains('prominent: false'));
    expect(nav, contains("ValueKey('mobile-liquid-nav')"));
  });

  test('financial facts and navigation stay intact on the active Home', () {
    expect(active, contains('Formatters.money(snapshot.spendablePool)'));
    expect(active, contains('Formatters.money(snapshot.dailyFolego)'));
    expect(active, contains('FinancialPrivacy.maskMoney()'));
    expect(active, contains('RefreshIndicator('));
    expect(active, contains('ListView('));
    expect(active, contains("ValueKey('home-flow-month-heading')"));
    expect(active, contains("ValueKey('home-flow-month-overview')"));
    expect(active, contains('showTiles: true'));
    expect(active, isNot(contains('const Spacer()')));
    expect(active, contains('HomeMobileSummaryStrip('));
    expect(active, contains('snapshot: snapshot'));
    expect(active, contains('onBudget: () {'));
    expect(active, contains('onUpcoming: _openUpcomingEvents'));
    expect(active, contains("ValueKey('home-fixed-explain')"));
    expect(active, contains("ValueKey('home-fixed-resolver')"));
    expect(active, contains("ValueKey('home-fixed-details')"));
    expect(active, isNot(contains('BackdropFilter(')));
  });
}
