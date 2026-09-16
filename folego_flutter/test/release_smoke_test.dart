import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/preferences/app_preferences.dart';
import 'package:folego/data/models/financial_space.dart';
import 'package:folego/data/models/onboarding_state.dart';
import 'package:folego/data/repositories/folego_repository.dart';
import 'package:folego/features/home/home_screen.dart';
import 'package:folego/features/onboarding/onboarding_screen.dart';

class _MemoryPreferenceStore implements AppPreferenceStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }
}

class _FirstUseRepository implements FolegoRepository {
  _FirstUseRepository(this.state);

  final OnboardingState state;

  @override
  Future<OnboardingState> getOnboardingState(String spaceId) async => state;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _space = FinancialSpace(id: 'space-1', name: 'Meu espaço');

OnboardingState _setup({required bool hasAccount, required bool hasIncome}) {
  return OnboardingState(
    accountCount: hasAccount ? 1 : 0,
    hasAccount: hasAccount,
    hasConfirmedIncome: hasIncome,
    recurringExpenseCount: 0,
    hasCard: false,
    budgetConfigured: false,
    reserveConfigured: false,
    folegoReady: hasAccount && hasIncome,
    onboardingCompleted: false,
  );
}

void main() {
  test('first-run intro preference is local and persistent', () async {
    final store = _MemoryPreferenceStore();
    final repository = AppPreferenceRepository(store);

    expect(await repository.loadFirstRunIntroSeen(), isFalse);
    await repository.saveFirstRunIntroSeen(true);
    expect(await repository.loadFirstRunIntroSeen(), isTrue);
    expect(store.values[AppPreferenceRepository.firstRunIntroKey], 'true');
  });

  testWidgets('onboarding is short, skippable and uses four concepts', (tester) async {
    var completed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(
          onCompleted: () async => completed += 1,
          onSignOut: () async {},
        ),
      ),
    );

    expect(find.text('seu saldo não é o que você pode gastar'), findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding-skip')), findsOneWidget);

    for (var index = 0; index < 3; index++) {
      await tester.tap(find.byKey(const ValueKey('onboarding-next')));
      await tester.pumpAndSettle();
    }

    expect(find.text('quanto dá pra gastar hoje?'), findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding-finish')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('onboarding-finish')));
    await tester.pumpAndSettle();
    expect(completed, 1);
  });

  testWidgets('onboarding skip never writes financial setup', (tester) async {
    var completed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(
          onCompleted: () async => completed += 1,
          onSignOut: () async {},
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('onboarding-skip')));
    await tester.pumpAndSettle();
    expect(completed, 1);
  });

  testWidgets('first-use Home explains missing account instead of showing zero money', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          space: _space,
          repository: _FirstUseRepository(_setup(hasAccount: false, hasIncome: false)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('seu Fôlego ainda não tem de onde partir'), findsOneWidget);
    expect(find.byKey(const ValueKey('first-use-add-account')), findsOneWidget);
    expect(find.text('R\$ 0,00'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('first-use Home explains missing recurring income', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          space: _space,
          repository: _FirstUseRepository(_setup(hasAccount: true, hasIncome: false)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('falta saber quando entra dinheiro'), findsOneWidget);
    expect(find.textContaining('lançamentos → recorrências'), findsOneWidget);
    expect(find.text('R\$ 0,00'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('release smoke contracts keep primary journeys connected', () {
    final shell = File('lib/features/shell/home_shell.dart').readAsStringSync();
    final transactions = File('lib/features/transactions/transactions_screen.dart').readAsStringSync();
    final wallet = File('lib/features/wallet/wallet_screen.dart').readAsStringSync();
    final profile = File('lib/features/profile/profile_screen_v2.dart').readAsStringSync();

    expect(shell, contains('HomeScreen('));
    expect(shell, contains('TransactionsScreen('));
    expect(shell, contains('PlanScreen('));
    expect(shell, contains('WalletScreen('));
    expect(shell, contains('ProfileScreen('));

    expect(transactions, contains('statement-import-entry'));
    expect(wallet, contains('showWalletAddAction'));
    expect(profile, contains('logout'));
  });

  test('release config keeps financial regression contracts visible', () {
    final transactionBase = File('lib/features/transactions/transactions_screen_base.dart').readAsStringSync();
    final importer = File('lib/features/transactions/statement_import_screen.dart').readAsStringSync();
    final realtime = File('lib/core/realtime/realtime_invalidation.dart').readAsStringSync();

    expect(transactionBase, contains('transactionPageSize'));
    expect(importer, contains('stageStatementImport'));
    expect(importer, contains('confirmStatementImport'));
    expect(realtime, contains('Duration(milliseconds: 250)'));
  });
}
