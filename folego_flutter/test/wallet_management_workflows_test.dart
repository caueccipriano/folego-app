import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/layout/app_breakpoints.dart';
import 'package:folego/core/realtime/realtime_invalidation.dart';
import 'package:folego/data/models/account_item.dart';
import 'package:folego/data/models/wallet_overview.dart';
import 'package:folego/data/repositories/folego_repository.dart';
import 'package:folego/features/wallet/wallet_instrument_management.dart';

void main() {
  group('Wallet 3.0 financial contracts', () {
    test('account model keeps reserve investment and benefit in canonical account types', () {
      expect(
        walletManagedAccountTypes,
        containsAll(<String>['checking', 'savings', 'cash', 'reserve', 'investment', 'other']),
      );
      expect(walletAccountTypeIsProtected('reserve'), isTrue);
      expect(walletAccountTypeIsProtected('investment'), isTrue);
      expect(walletAccountTypeIsProtected('benefit'), isTrue);
      expect(walletAccountTypeIsProtected('checking'), isFalse);
    });

    test('migration preserves opening balance and archive semantics', () {
      final sql = File(
        '../supabase/migrations/20260916152940_complete_wallet_instrument_management.sql',
      ).readAsStringSync();

      expect(sql, contains("'opening_balance'"));
      expect(sql, contains("p_type = 'benefit' then 'benefit' else 'cash'"));
      expect(sql, isNot(contains('register_income')));
      expect(sql, isNot(contains("dimension,'economic'")));
      expect(sql, isNot(contains("dimension,'budget'")));
      expect(sql, contains("a.active and a.type<>'benefit'"));
      expect(sql, contains('update public.accounts set active=false'));
      expect(sql, contains('update public.credit_cards set active=false'));
      expect(sql, isNot(contains('delete from public.accounts')));
      expect(sql, isNot(contains('delete from public.credit_cards')));
      expect(sql, contains('account_has_balance'));
      expect(sql, contains('account_has_active_recurring'));
      expect(sql, contains('account_is_card_payment_account'));
      expect(sql, contains('card_has_active_recurring'));
      expect(sql, contains('card_has_open_invoice'));
      expect(sql, contains('card_has_future_installments'));
      expect(sql, contains('auth.uid() is null'));
      expect(sql, contains('private.can_write_space(p_space_id)'));
      expect(sql, contains('revoke all on function public.create_wallet_account'));
      expect(sql, contains('grant execute on function public.create_wallet_account'));
    });

    test('payment-account helper excludes benefit instruments', () {
      const checking = AccountItem(id: 'cash', name: 'Santander', type: 'checking');
      const benefit = AccountItem(id: 'benefit', name: 'Flash', type: 'benefit');
      const reserve = AccountItem(id: 'reserve', name: 'Dindin', type: 'reserve');

      final eligible = [checking, benefit, reserve]
          .where((item) => item.isPaymentAccount)
          .map((item) => item.id)
          .toList();

      expect(eligible, ['cash', 'reserve']);
      expect(benefit.isPaymentAccount, isFalse);
    });

    test('Quick Register instrument refresh preserves the draft contract', () {
      final source = File('lib/features/home/quick_register_sheet_v3.dart').readAsStringSync();
      final start = source.indexOf('Future<void> _refreshPaymentInstruments()');
      final end = source.indexOf('Future<void> _load()', start);
      expect(start, greaterThanOrEqualTo(0));
      expect(end, greaterThan(start));
      final body = source.substring(start, end);

      expect(source, contains('AppRealtimeDomain.paymentInstruments'));
      expect(body, contains('listPaymentAccounts'));
      expect(body, contains('listBenefitAccounts'));
      expect(body, contains('listActiveCreditCards'));
      expect(body, isNot(contains('_load();')));
      expect(body, isNot(contains('_amount.clear()')));
      expect(body, isNot(contains('_description.clear()')));
      expect(body, isNot(contains('_merchant.clear()')));
      expect(body, isNot(contains('_reflectionNote.clear()')));
      expect(body, isNot(contains('_categoryId =')));
    });

    test('detail surfaces expose edit/archive without direct balance mutation', () {
      final source = File(
        'lib/features/wallet/wallet_instrument_detail_screen.dart',
      ).readAsStringSync();

      expect(source, contains('class WalletAccountDetailScreen'));
      expect(source, contains('class WalletBenefitDetailScreen'));
      expect(source, contains('class WalletCardDetailScreen'));
      expect(source, contains('onEdit: _edit'));
      expect(source, contains('onArchive: _archive'));
      expect(source, contains('derivado do ledger · nunca editado diretamente'));
      expect(source, contains('dimensão benefit · fora de cash'));
    });
  });

  group('Wallet 3.0 UI', () {
    testWidgets('+ adicionar exposes account card benefit and Debt 2.0 on mobile', (
      tester,
    ) async {
      _setViewport(tester, const Size(390, 844));
      await tester.pumpWidget(_addMenuHost());

      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byKey(const ValueKey('wallet-add-account')), findsOneWidget);
      expect(find.byKey(const ValueKey('wallet-add-card')), findsOneWidget);
      expect(find.byKey(const ValueKey('wallet-add-benefit')), findsOneWidget);
      expect(find.byKey(const ValueKey('wallet-add-debt')), findsOneWidget);
      expect(find.text('usa o fluxo Debt 2.0 já existente'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('+ adicionar uses compact dialog on desktop', (tester) async {
      _setViewport(tester, const Size(1366, 900));
      await tester.pumpWidget(_addMenuHost());

      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byKey(const ValueKey('wallet-add-account')), findsOneWidget);
      expect(find.byKey(const ValueKey('wallet-add-card')), findsOneWidget);
      expect(find.byKey(const ValueKey('wallet-add-benefit')), findsOneWidget);
      expect(find.byKey(const ValueKey('wallet-add-debt')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('create account captures opening balance without exposing current-balance edit', (
      tester,
    ) async {
      _setViewport(tester, const Size(390, 844));
      String? savedName;
      String? savedType;
      double? opening;
      bool? available;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WalletAccountEditor(
              repository: _Repository(),
              spaceId: 'space',
              saveOverride: ({
                required name,
                required institution,
                required type,
                required openingBalance,
                required availableForSpending,
              }) async {
                savedName = name;
                savedType = type;
                opening = openingBalance;
                available = availableForSpending;
              },
            ),
          ),
        ),
      );

      await tester.enterText(find.byKey(const ValueKey('wallet-account-name')), 'Nubank');
      await tester.enterText(find.byKey(const ValueKey('wallet-opening-balance')), '150,50');
      await tester.tap(find.byKey(const ValueKey('wallet-account-save')));
      await tester.pump();

      expect(savedName, 'Nubank');
      expect(savedType, 'checking');
      expect(opening, 150.50);
      expect(available, isTrue);
    });

    testWidgets('edit account never exposes direct balance overwrite', (tester) async {
      const account = WalletAccount(
        id: 'account',
        name: 'Santander',
        institution: 'Santander',
        type: 'checking',
        availableForSpending: true,
        balance: 1234.56,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WalletAccountEditor(
              repository: _Repository(),
              spaceId: 'space',
              account: account,
              saveOverride: ({
                required name,
                required institution,
                required type,
                required openingBalance,
                required availableForSpending,
              }) async {},
            ),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('wallet-opening-balance')), findsNothing);
      expect(find.textContaining('o saldo não é editável aqui'), findsOneWidget);
      expect(find.textContaining('ajuste/reconciliação'), findsOneWidget);
    });

    testWidgets('benefit creation stays benefit and protected from available cash', (
      tester,
    ) async {
      String? savedType;
      bool? available;
      double? opening;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WalletAccountEditor(
              repository: _Repository(),
              spaceId: 'space',
              benefitMode: true,
              saveOverride: ({
                required name,
                required institution,
                required type,
                required openingBalance,
                required availableForSpending,
              }) async {
                savedType = type;
                available = availableForSpending;
                opening = openingBalance;
              },
            ),
          ),
        ),
      );

      await tester.enterText(find.byKey(const ValueKey('wallet-account-name')), 'Flash');
      await tester.enterText(find.byKey(const ValueKey('wallet-opening-balance')), '80');
      await tester.tap(find.byKey(const ValueKey('wallet-account-save')));
      await tester.pump();

      expect(savedType, 'benefit');
      expect(available, isFalse);
      expect(opening, 80);
    });

    testWidgets('card editor uses canonical payment-account loader and saves future metadata', (
      tester,
    ) async {
      String? paymentAccount;
      int? closingDay;
      int? dueDay;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WalletCardEditor(
              repository: _Repository(),
              spaceId: 'space',
              accountsLoader: () async => const [
                AccountItem(id: 'checking', name: 'Santander', type: 'checking'),
              ],
              saveOverride: ({
                required name,
                required issuer,
                required brand,
                required lastFour,
                required personalLimit,
                required closingDay: closing,
                required dueDay: due,
                required paymentAccountId,
              }) async {
                paymentAccount = paymentAccountId;
                closingDay = closing;
                dueDay = due;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('wallet-card-name')), 'Cartão teste');
      await tester.tap(find.byKey(const ValueKey('wallet-card-save')));
      await tester.pump();

      expect(paymentAccount, 'checking');
      expect(closingDay, 5);
      expect(dueDay, 10);
    });
  });

  group('Wallet 3.0 realtime and responsive integration', () {
    testWidgets('accounts and cards share central 250ms payment-instrument invalidation', (
      tester,
    ) async {
      final accountDomains = domainsForRealtimeTable('accounts');
      final cardDomains = domainsForRealtimeTable('credit_cards');

      for (final domains in [accountDomains, cardDomains]) {
        expect(domains, contains(AppRealtimeDomain.wallet));
        expect(domains, contains(AppRealtimeDomain.home));
        expect(domains, contains(AppRealtimeDomain.paymentInstruments));
      }

      final coordinator = RealtimeInvalidationCoordinator();
      expect(coordinator.debounce, const Duration(milliseconds: 250));
      var refreshes = 0;
      final binding = coordinator.bind(
        domain: AppRealtimeDomain.paymentInstruments,
        onRefresh: () async => refreshes += 1,
      );

      coordinator.invalidateDomains(accountDomains);
      coordinator.invalidateDomains(cardDomains);
      coordinator.invalidateDomains(accountDomains);
      await tester.pump(const Duration(milliseconds: 249));
      expect(refreshes, 0);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(refreshes, 1);

      binding.dispose();
      coordinator.dispose();
    });

    test('target widths remain mapped to the shared Web 2.0 breakpoints', () {
      expect(AppBreakpoints.fromWidth(375), AppLayoutSize.compact);
      expect(AppBreakpoints.fromWidth(390), AppLayoutSize.compact);
      expect(AppBreakpoints.fromWidth(430), AppLayoutSize.compact);
      expect(AppBreakpoints.fromWidth(768), AppLayoutSize.medium);
      expect(AppBreakpoints.fromWidth(1024), AppLayoutSize.expanded);
      expect(AppBreakpoints.fromWidth(1366), AppLayoutSize.expanded);
      expect(AppBreakpoints.fromWidth(1440), AppLayoutSize.expanded);
      expect(AppBreakpoints.fromWidth(1920), AppLayoutSize.wide);
    });
  });
}

Widget _addMenuHost() {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: FilledButton(
            onPressed: () => showWalletAddAction(context),
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  );
}

void _setViewport(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

class _Repository implements FolegoRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
