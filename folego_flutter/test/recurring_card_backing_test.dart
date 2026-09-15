import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:folego/data/models/account_item.dart';
import 'package:folego/data/models/category_item.dart';
import 'package:folego/data/models/financial_space.dart';
import 'package:folego/data/models/recurring_item.dart';
import 'package:folego/data/models/wallet_overview.dart';
import 'package:folego/data/repositories/folego_repository.dart';
import 'package:folego/features/transactions/recurring_form_sheet.dart';

void main() {
  const space = FinancialSpace(id: 'space-1', name: 'Pessoal');

  testWidgets('card-backed recurrence saves cardId without forcing accountId', (
    tester,
  ) async {
    final repository = _FakeFolegoRepository(
      accounts: const [AccountItem(id: 'account-1', name: 'Conta ativa')],
      cards: const [
        WalletCard(
          id: 'card-1',
          name: 'Cartão principal',
          closingDay: 10,
          dueDay: 17,
          invoiceBalance: 0,
        ),
      ],
    );

    final item = _item(
      cardId: 'card-1',
      monthlyDays: const [5, 20],
      monthlyLastDay: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecurringFormSheet(
            space: space,
            repository: repository,
            item: item,
          ),
        ),
      ),
    );
    await _flushUi(tester);

    expect(find.text('Cartão principal'), findsOneWidget);
    expect(find.text('Conta ativa'), findsNothing);

    await tester.ensureVisible(find.text('Salvar recorrência'));
    await tester.tap(find.text('Salvar recorrência'));
    await _flushUi(tester);

    expect(repository.savedAccountId, isNull);
    expect(repository.savedCardId, 'card-1');
    expect(repository.savedMonthlyDays, [5, 20]);
    expect(repository.savedMonthlyLastDay, isTrue);
    expect(repository.savedStartsOn, item.startsOn);
    expect(repository.savedEndsOn, item.endsOn);
  });

  testWidgets('account-backed recurrence keeps accountId and no cardId', (
    tester,
  ) async {
    final repository = _FakeFolegoRepository(
      accounts: const [AccountItem(id: 'account-1', name: 'Conta ativa')],
    );

    final item = _item(accountId: 'account-1');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecurringFormSheet(
            space: space,
            repository: repository,
            item: item,
          ),
        ),
      ),
    );
    await _flushUi(tester);

    expect(find.text('Conta ativa'), findsOneWidget);
    expect(repository.walletOverviewCalls, 0);

    await tester.ensureVisible(find.text('Salvar recorrência'));
    await tester.tap(find.text('Salvar recorrência'));
    await _flushUi(tester);

    expect(repository.savedAccountId, 'account-1');
    expect(repository.savedCardId, isNull);
  });

  testWidgets('card-backed recurrence can switch to another active card', (
    tester,
  ) async {
    final repository = _FakeFolegoRepository(
      accounts: const [AccountItem(id: 'account-1', name: 'Conta ativa')],
      cards: const [
        WalletCard(
          id: 'card-1',
          name: 'Cartão principal',
          closingDay: 10,
          dueDay: 17,
          invoiceBalance: 0,
        ),
        WalletCard(
          id: 'card-2',
          name: 'Cartão secundário',
          closingDay: 5,
          dueDay: 12,
          invoiceBalance: 0,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecurringFormSheet(
            space: space,
            repository: repository,
            item: _item(cardId: 'card-1'),
          ),
        ),
      ),
    );
    await _flushUi(tester);

    await tester.tap(find.text('Cartão principal'));
    await _flushUi(tester);
    await tester.tap(find.text('Cartão secundário').last);
    await _flushUi(tester);

    await tester.ensureVisible(find.text('Salvar recorrência'));
    await tester.tap(find.text('Salvar recorrência'));
    await _flushUi(tester);

    expect(repository.savedAccountId, isNull);
    expect(repository.savedCardId, 'card-2');
  });

  testWidgets('missing active card keeps the existing cardId safely', (
    tester,
  ) async {
    final repository = _FakeFolegoRepository(
      accounts: const [AccountItem(id: 'account-1', name: 'Conta ativa')],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecurringFormSheet(
            space: space,
            repository: repository,
            item: _item(cardId: 'archived-card'),
          ),
        ),
      ),
    );
    await _flushUi(tester);

    expect(
      find.text('Cartão atual (inativo ou indisponível)'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Este cartão não aparece mais entre os cartões ativos. O vínculo atual será preservado.',
      ),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Salvar recorrência'));
    await tester.tap(find.text('Salvar recorrência'));
    await _flushUi(tester);

    expect(repository.savedAccountId, isNull);
    expect(repository.savedCardId, 'archived-card');
  });
}

Future<void> _flushUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 250));
}

RecurringItem _item({
  String? accountId,
  String? cardId,
  List<int> monthlyDays = const [10],
  bool monthlyLastDay = false,
}) {
  return RecurringItem(
    id: 'recurring-1',
    spaceId: 'space-1',
    name: 'Recorrência teste',
    itemType: 'expense',
    amount: 100,
    frequency: 'monthly',
    dayOfMonth: monthlyDays.isEmpty ? null : monthlyDays.first,
    monthlyDays: monthlyDays,
    monthlyLastDay: monthlyLastDay,
    categoryId: 'category-1',
    accountId: accountId,
    cardId: cardId,
    startsOn: DateTime(2026, 1, 5),
    endsOn: DateTime(2026, 12, 31),
    certainty: 'confirmed',
    active: true,
  );
}

class _FakeFolegoRepository implements FolegoRepository {
  _FakeFolegoRepository({
    this.accounts = const [],
    this.cards = const [],
  });

  final List<AccountItem> accounts;
  final List<WalletCard> cards;

  int walletOverviewCalls = 0;

  String? savedAccountId;
  String? savedCardId;
  List<int>? savedMonthlyDays;
  bool? savedMonthlyLastDay;
  DateTime? savedStartsOn;
  DateTime? savedEndsOn;

  @override
  Future<List<AccountItem>> listAccounts(String spaceId) async => accounts;

  @override
  Future<WalletOverview> getWalletOverview({required String spaceId}) async {
    walletOverviewCalls += 1;

    return WalletOverview(
      summary: const WalletSummary(
        totalCash: 0,
        availableCash: 0,
        totalCardInvoice: 0,
        totalDebtRemaining: 0,
      ),
      accounts: const [],
      cards: cards,
      debts: const [],
      installments: const [],
    );
  }

  @override
  Future<List<CategoryItem>> listExpenseCategories(String spaceId) async {
    return const [
      CategoryItem(
        id: 'category-1',
        name: 'Moradia',
        essential: true,
      ),
    ];
  }

  @override
  Future<List<CategoryItem>> listIncomeCategories(String spaceId) async {
    return const [
      CategoryItem(
        id: 'income-category-1',
        name: 'Salário',
        essential: true,
      ),
    ];
  }

  @override
  Future<void> updateRecurringItem({
    required String spaceId,
    required String itemId,
    required String name,
    required String itemType,
    required num amount,
    required String frequency,
    String? accountId,
    String? cardId,
    String? categoryId,
    int? dayOfMonth,
    List<int>? monthlyDays,
    bool monthlyLastDay = false,
    int? weekday,
    int? monthOfYear,
    required DateTime startsOn,
    DateTime? endsOn,
    String certainty = 'confirmed',
    required bool active,
  }) async {
    savedAccountId = accountId;
    savedCardId = cardId;
    savedMonthlyDays = monthlyDays;
    savedMonthlyLastDay = monthlyLastDay;
    savedStartsOn = startsOn;
    savedEndsOn = endsOn;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
