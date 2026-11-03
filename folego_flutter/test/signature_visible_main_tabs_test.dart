import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/shared/widgets/signature_feature_hero.dart';

void main() {
  for (final width in [320.0, 390.0]) {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      testWidgets('signature navigation hero fits $width $brightness',
          (tester) async {
        tester.view.physicalSize = Size(width, 667);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SignatureFeatureHero(
                  title: 'carteira',
                  eyebrow: 'Seu dinheiro, com clareza',
                  subtitle: 'Contas, cartões, benefícios e dívidas em um só lugar',
                  icon: Icons.account_balance_wallet_outlined,
                  compact: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        key: const ValueKey('sample-privacy'),
                        tooltip: 'ocultar valores',
                        onPressed: () {},
                        icon: const Icon(Icons.visibility_outlined),
                      ),
                      IconButton(
                        key: const ValueKey('sample-add'),
                        tooltip: 'adicionar',
                        onPressed: () {},
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ));
        await tester.pump();
        expect(find.byKey(const ValueKey('signature-feature-hero')), findsOneWidget);
        expect(find.text('carteira'), findsOneWidget);
        expect(find.text('SEU DINHEIRO, COM CLAREZA'), findsOneWidget);
        expect(find.byKey(const ValueKey('sample-privacy')), findsOneWidget);
        expect(find.byKey(const ValueKey('sample-add')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  test('the actual shell destinations use the visible Signature hero', () {
    final shell = File('lib/features/shell/home_shell.dart').readAsStringSync();
    for (final route in [
      'TransactionsScreen(',
      'PlanScreen(',
      'WalletScreen(',
      'ProfileScreen(',
    ]) {
      expect(shell, contains(route), reason: 'Navigation: $route');
    }
    final pages = [
      'transactions/transactions_screen_base.dart',
      'plan/plan_screen_web2.dart',
      'wallet/wallet_screen_base.dart',
      'profile/profile_screen_v2.dart',
      'goals/goals_screen_base.dart',
      'diary/diary_screen_base.dart',
    ];
    for (final path in pages) {
      final contents = File('lib/features/$path').readAsStringSync();
      expect(contents, contains('SignatureFeatureHero('), reason: path);
    }
  });

  test('the new hero preserves critical financial navigation actions', () {
    final wallet = File('lib/features/wallet/wallet_screen_base.dart')
        .readAsStringSync();
    final transactions = File('lib/features/transactions/transactions_screen_base.dart')
        .readAsStringSync();
    final plan = File('lib/features/plan/plan_screen_web2.dart')
        .readAsStringSync();
    expect(wallet, contains("ValueKey('wallet-privacy-toggle')"));
    expect(wallet, contains("ValueKey('wallet-add-action')"));
    expect(transactions, contains('statement-import-entry'));
    expect(transactions, contains('onPressed: widget.onImportRequested'));
    expect(transactions, contains('transaction-classification-inbox'));
    expect(transactions, contains('onPressed: widget.onClassificationRequested'));
    expect(transactions, contains('_tabController'));
    expect(plan, contains('_changeMonth('));
    expect(plan, contains('_PlanModeToggle('));
  });
}
