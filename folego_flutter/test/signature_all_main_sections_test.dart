import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/shared/widgets/folego_glass_surface.dart';
import 'package:folego/shared/widgets/signature_section_intro.dart';

void main() {
  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets('Signature secondary destination works in $brightness',
        (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(12),
            child: SignatureSectionIntro(
              eyebrow: 'Seu patrimônio',
              caption: 'Contas, cartões e compromissos sob controle',
              icon: Icons.account_balance_wallet_outlined,
            ),
          ),
        ),
      ));
      expect(find.text('SEU PATRIMÔNIO'), findsOneWidget);
      expect(find.byType(FolegoGlassSurface), findsOneWidget);
      expect(find.byIcon(Icons.account_balance_wallet_outlined),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  test('all secondary destinations share Signature editorial surface', () {
    const targets = {
      'wallet/wallet_screen_base.dart': 'Seu patrimônio',
      'goals/goals_screen_base.dart': 'Seus objetivos',
      'diary/diary_screen_base.dart': 'Consciência financeira',
      'profile/profile_screen_v2.dart': 'Seu espaço',
    };
    for (final entry in targets.entries) {
      final source = File('lib/features/${entry.key}').readAsStringSync();
      expect(source, contains('SignatureSectionIntro('),
          reason: entry.key);
      expect(source, contains('FolegoAmbientBackdrop('),
          reason: entry.key);
      expect(source, contains(entry.value), reason: entry.key);
    }
  });

  test('Signature leaves financial flows, private mode and actions intact', () {
    final wallet = File('lib/features/wallet/wallet_screen_base.dart')
        .readAsStringSync();
    final goals = File('lib/features/goals/goals_screen_base.dart')
        .readAsStringSync();
    final diary = File('lib/features/diary/diary_screen_base.dart')
        .readAsStringSync();
    final profile = File('lib/features/profile/profile_screen_v2.dart')
        .readAsStringSync();
    expect(wallet, contains('FinancialPrivacy.hidden'));
    expect(wallet, contains("ValueKey('wallet-privacy-toggle')"));
    expect(wallet, contains('_buildSelectedSection()'));
    expect(goals, contains('GoalEmptyState(onCreate: _createGoal)'));
    expect(goals, contains('_GoalGrid('));
    expect(diary, contains('_openTransactions'));
    expect(diary, contains('FinancialPrivacy.hidden'));
    expect(profile, contains('_deleteAccount'));
    expect(profile, contains('_preferencesSection()'));
  });
}
