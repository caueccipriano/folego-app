import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
void main() {
  test('Home fixed viewport keeps scroll only in details sheet', () {
    final s = File('lib/features/home/home_screen_base.dart').readAsStringSync();
    final main = s.split('Widget _buildFixedMobileHome({').last
      .split('Future<void> _openFixedMobileDetails({').first;
    expect(main, contains("ValueKey('home-fixed-mobile')"));
    expect(main, contains("ValueKey('home-fixed-amount')"));
    expect(main, contains("ValueKey('home-fixed-resolver')"));
    expect(main, contains("ValueKey('home-fixed-details')"));
    expect(main, contains('snapshot.spendablePool'));
    expect(main, contains('FinancialPrivacy.maskMoney()'));
    expect(main, isNot(contains('ListView(')));
    expect(main, isNot(contains('SingleChildScrollView(')));
    expect(s, contains("ValueKey('home-monthly-details-scroll')"));
    expect(s, contains('MediaQuery.textScalerOf(context)'));
  });
  test('navigation has three direct choices plus labeled Mais', () {
    final bar = File('lib/shared/widgets/liquid_glass_navigation_bar.dart')
      .readAsStringSync();
    expect(bar, contains("Text('mais'"));
    expect(bar, contains("ValueKey('mobile-tools-button')"));
    expect(bar, isNot(contains('BackdropFilter(')));
  });
}
