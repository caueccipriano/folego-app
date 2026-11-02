import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/theme/app_theme.dart';
import 'package:folego/shared/widgets/folego_ambient_backdrop.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets('aurora background preserves taps in ${dark ? 'dark' : 'light'} theme',
        (tester) async {
      var count = 0;
      await tester.pumpWidget(MaterialApp(
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        home: Scaffold(
          body: FolegoAmbientBackdrop(
            child: Center(
              child: FilledButton(
                key: const ValueKey('aurora-action'),
                onPressed: () => count++,
                child: const Text('continuar'),
              ),
            ),
          ),
        ),
      ));
      expect(find.byKey(const ValueKey('folego-ambient-backdrop')),
          findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('aurora-action')));
      expect(count, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('high contrast removes ambient gradients', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: const MediaQuery(
        data: MediaQueryData(highContrast: true),
        child: Scaffold(
          body: FolegoAmbientBackdrop(
            child: Text('saldo protegido'),
          ),
        ),
      ),
    ));
    expect(find.text('saldo protegido'), findsOneWidget);
    expect(find.byKey(const ValueKey('folego-ambient-backdrop')),
        findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('Home keeps a fixed viewport, private values and safe visual overlays', () {
    final source = File('lib/features/home/home_fixed_dashboard.dart')
        .readAsStringSync();
    expect(source, contains('FolegoAmbientBackdrop('));
    expect(source, contains("ValueKey('home-aurora-rim')"));
    expect(source, contains('child: IgnorePointer('));
    expect(source, contains("ValueKey('home-fixed-viewport')"));
    expect(source, contains("'home-fixed-daily-folego'"));
    expect(source, contains('FinancialPrivacy.maskMoney()'));
    expect(source, contains('onTap: onDetails'));
    expect(source, isNot(contains('BackdropFilter(')));
    expect(source, isNot(contains('SingleChildScrollView(')));
  });
}
