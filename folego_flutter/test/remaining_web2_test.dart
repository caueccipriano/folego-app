import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/financial_space.dart';
import 'package:folego/data/models/recurring_item.dart';
import 'package:folego/data/models/transaction_filters.dart';
import 'package:folego/data/models/transaction_item.dart';
import 'package:folego/data/models/transaction_page.dart';
import 'package:folego/data/models/wallet_overview.dart';
import 'package:folego/data/repositories/folego_repository.dart';
import 'package:folego/features/transactions/transactions_screen_base.dart';
import 'package:folego/features/wallet/wallet_screen.dart';

void main() {
  testWidgets('Transactions desktop keeps search and filters visible without overflow', (
    tester,
  ) async {
    _setViewport(tester, const Size(1366, 900));
    await tester.pumpWidget(
      MaterialApp(
        home: TransactionsScreenV3(
          repository: _FakeTransactionsRepository(),
          space: const FinancialSpace(id: 'space', name: 'Pessoal'),
          pageLoader: ({
            required spaceId,
            required filters,
            required cursor,
            required pageSize,
          }) async => const TransactionPage(
            items: <TransactionItem>[],
            hasMore: false,
            nextCursor: null,
          ),
          optionsLoader: (_) async => TransactionFilterOptions.empty(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('lançamentos'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'buscar lançamento'), findsOneWidget);
    expect(find.byKey(const ValueKey('transaction-filter-button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Wallet desktop renders responsive grid without overflow', (
    tester,
  ) async {
    _setViewport(tester, const Size(1366, 900));
    await tester.pumpWidget(
      MaterialApp(
        home: WalletScreen(
          repository: _FakeWalletRepository(),
          spaceId: 'space',
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('wallet-desktop-layout')), findsOneWidget);
    expect(find.text('carteira'), findsOneWidget);
    expect(find.text('Conta 1'), findsOneWidget);
    expect(find.text('Conta 4'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('Agenda Web2 remains a responsive wrapper over canonical source', () {
    final wrapper = File(
      'lib/features/home/upcoming_events_screen_web2.dart',
    ).readAsStringSync();
    final route = File(
      'lib/features/home/upcoming_events_screen.dart',
    ).readAsStringSync();

    expect(wrapper, contains("import 'upcoming_events_screen_base.dart' as base;"));
    expect(wrapper, contains('base.UpcomingEventsScreen('));
    expect(wrapper, contains("ValueKey('agenda-desktop-layout')"));
    expect(wrapper, contains('VisualDensity.compact'));
    expect(route, contains('UpcomingEventsScreenWeb2('));
    expect(route, isNot(contains('getFinancialAgenda(')));
  });

  test('Profile desktop keeps two columns and consolidated organization action', () {
    final source = File(
      'lib/features/profile/profile_screen_v2.dart',
    ).readAsStringSync();

    expect(source, contains("ValueKey('profile-desktop-layout')"));
    expect(source, contains("ValueKey('profile-identity-column')"));
    expect(source, contains("ValueKey('profile-settings-column')"));
    expect(source, contains('_appearanceSection()'));
    expect(source, contains('_languageSection()'));
    expect(source, contains('_privacySection()'));
    expect(source, contains('_aboutSection()'));
    expect(source, contains('_logoutSection()'));
    expect(source, contains('_openFinancialOrganization'));
    expect(source, isNot(contains('_openCategories')));
  });

  test('Transaction detail remains adaptive through canonical v2 implementation', () {
    final route = File(
      'lib/features/transactions/transaction_detail_sheet.dart',
    ).readAsStringSync();
    final source = File(
      'lib/features/transactions/transaction_detail_sheet_v2.dart',
    ).readAsStringSync();

    expect(route, contains("export 'transaction_detail_sheet_v2.dart';"));
    expect(source, contains('AppBreakpoints.of(context) == AppLayoutSize.compact'));
    expect(source, contains('showModalBottomSheet<bool>'));
    expect(source, contains('showDialog<bool>'));
    expect(source, contains('maxWidth: 780'));
    expect(source, contains('height * .86'));
  });

  test('Transactions wrapper preserves concurrent classification inbox and desktop shell', () {
    final source = File(
      'lib/features/transactions/transactions_screen.dart',
    ).readAsStringSync();

    expect(source, contains('TransactionClassificationInbox'));
    expect(source, contains('impl.TransactionsScreenV3('));
    expect(source, contains("ValueKey('transactions-desktop-layout')"));
    expect(source, contains('VisualDensity.compact'));
  });

  test('Quick Register category realtime preserves in-progress form state', () {
    final source = File(
      'lib/features/home/quick_register_sheet_v3.dart',
    ).readAsStringSync();

    expect(source, contains('domain: AppRealtimeDomain.categories'));
    expect(source, contains('onRefresh: _refreshCategories'));
    final start = source.indexOf('Future<void> _refreshCategories()');
    final end = source.indexOf('Future<void> _load()', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));

    final refresh = source.substring(start, end);
    expect(refresh, contains('_categories = selectable'));
    expect(refresh, contains('_categoryId = nextId'));
    expect(refresh, isNot(contains('_load()')));
    expect(refresh, isNot(contains('_description.clear()')));
    expect(refresh, isNot(contains('_amount.clear()')));
    expect(refresh, isNot(contains('_merchant.clear()')));
    expect(refresh, isNot(contains('_reflectionNote.clear()')));
  });

  test('category migration version in repo matches applied Dev contract', () {
    final migration = File(
      '../supabase/migrations/20260916142941_add_category_icon_keys_and_realtime.sql',
    );
    expect(migration.existsSync(), isTrue);
    final source = migration.readAsStringSync();

    expect(source, contains('add column if not exists icon_key text'));
    expect(source, contains('categories_icon_key_valid'));
    expect(source, contains('icon_key text,'));
    expect(source, contains('c.icon_key'));
    expect(source, contains('alter publication supabase_realtime add table public.categories'));
    expect(source, isNot(contains('create function public.create_custom_category')));
  });
}

void _setViewport(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

class _FakeTransactionsRepository implements FolegoRepository {
  @override
  Future<List<RecurringItem>> listRecurringItems(String spaceId) async =>
      const <RecurringItem>[];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeWalletRepository implements FolegoRepository {
  @override
  Future<WalletOverview> getWalletOverview({required String spaceId}) async {
    return const WalletOverview(
      summary: WalletSummary(
        totalCash: 1000,
        availableCash: 900,
        totalBenefit: 100,
        totalCardInvoice: 250,
        totalDebtRemaining: 500,
      ),
      accounts: [
        WalletAccount(
          id: 'a1',
          name: 'Conta 1',
          type: 'checking',
          availableForSpending: true,
          balance: 250,
        ),
        WalletAccount(
          id: 'a2',
          name: 'Conta 2',
          type: 'checking',
          availableForSpending: true,
          balance: 250,
        ),
        WalletAccount(
          id: 'a3',
          name: 'Conta 3',
          type: 'checking',
          availableForSpending: true,
          balance: 250,
        ),
        WalletAccount(
          id: 'a4',
          name: 'Conta 4',
          type: 'checking',
          availableForSpending: true,
          balance: 250,
        ),
      ],
      cards: <WalletCard>[],
      debts: <WalletDebt>[],
      installments: <WalletInstallment>[],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
