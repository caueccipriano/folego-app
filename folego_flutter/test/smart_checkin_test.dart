import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:folego/core/privacy/financial_privacy.dart';
import 'package:folego/data/models/category_item.dart';
import 'package:folego/data/models/transaction_item.dart';
import 'package:folego/data/models/wallet_overview.dart';
import 'package:folego/data/repositories/folego_repository.dart';
import 'package:folego/features/home/smart_checkin_card.dart';
import 'package:folego/features/transactions/transaction_classification_inbox.dart';

class _NoNetworkRepository implements FolegoRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

TransactionItem transaction(
  String id, {
  String description = 'Padaria da Esquina',
  String? categoryId,
  String? accountId = 'bank-one',
  String source = 'manual',
  String type = 'expense',
}) => TransactionItem(
  id: id,
  eventType: type,
  description: description,
  amount: 21,
  occurredAt: DateTime(2026, 10, 12),
  status: 'confirmed',
  source: source,
  accountId: accountId,
  categoryId: categoryId,
);

const category = CategoryItem(
  id: 'food',
  name: 'alimentação',
  essential: true,
  categoryRole: 'economic',
  kind: 'expense',
);

void main() {
  tearDown(() => FinancialPrivacy.hidden.value = false);

  test('suggests only two matching previous categories in same bank account', () {
    final result = historicalCategorySuggestions(
      pending: [transaction('pending')],
      history: [
        transaction('a', categoryId: 'food'),
        transaction('b', categoryId: 'food'),
      ],
      categories: [category],
    );
    expect(result, {'pending': 'food'});
  });

  test('rejects category disagreement, one example, wrong bank or wrong type', () {
    const other = CategoryItem(
      id: 'shopping', name: 'compras', essential: false,
      categoryRole: 'economic', kind: 'expense',
    );
    final mixed = historicalCategorySuggestions(
      pending: [transaction('pending')],
      history: [
        transaction('a', categoryId: 'food'),
        transaction('b', categoryId: 'shopping'),
      ],
      categories: [category, other],
    );
    expect(mixed, isEmpty);

    final one = historicalCategorySuggestions(
      pending: [transaction('pending')],
      history: [transaction('a', categoryId: 'food')],
      categories: [category],
    );
    expect(one, isEmpty);

    final differentAccount = historicalCategorySuggestions(
      pending: [transaction('pending')],
      history: [
        transaction('a', categoryId: 'food', accountId: 'bank-two'),
        transaction('b', categoryId: 'food', accountId: 'bank-two'),
      ],
      categories: [category],
    );
    expect(differentAccount, isEmpty);

    final differentType = historicalCategorySuggestions(
      pending: [transaction('pending', type: 'expense')],
      history: [
        transaction('a', categoryId: 'food', type: 'income'),
        transaction('b', categoryId: 'food', type: 'income'),
      ],
      categories: [category],
    );
    expect(differentType, isEmpty);
  });

  test('never infers a card/benefit category from ambiguous account impacts', () {
    final suggestions = historicalCategorySuggestions(
      pending: [transaction('pending', type: 'card_purchase')],
      history: [
        transaction('a', categoryId: 'food'),
        transaction('b', categoryId: 'food'),
      ],
      categories: [category],
    );
    expect(suggestions, isEmpty);
  });

  test('rejects inactive or non-economic categories', () {
    const hidden = CategoryItem(
      id: 'food', name: 'alimentação', essential: true,
      categoryRole: 'transfer', kind: 'expense',
    );
    final suggestions = historicalCategorySuggestions(
      pending: [transaction('pending')],
      history: [
        transaction('a', categoryId: 'food'),
        transaction('b', categoryId: 'food'),
      ],
      categories: [hidden],
    );
    expect(suggestions, isEmpty);
  });

  testWidgets('automatic preflight labels the ledger without claiming bank sync', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SmartCheckinCard(
          spaceId: 'test-space',
          repository: _NoNetworkRepository(),
          loadReview: (_) async => {'pending_count': 16},
          loadWallet: (_) async => const WalletOverview(
            summary: WalletSummary(
              totalCash: 360,
              availableCash: 360,
              totalCardInvoice: 280,
              totalDebtRemaining: 0,
            ),
            accounts: [
              WalletAccount(
                id: 'account', name: 'Conta Teste',
                type: 'checking', balance: 360,
                availableForSpending: true,
              ),
            ],
            cards: [],
            debts: [],
            installments: [],
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('16 lançamentos'), findsOneWidget);
    expect(find.textContaining('360,00'), findsOneWidget);
    expect(find.textContaining('saldo bancário real'), findsOneWidget);
    expect(find.byKey(const ValueKey('smart-checkin-categorize')),
        findsOneWidget);

    FinancialPrivacy.hidden.value = true;
    await tester.pump();
    expect(find.textContaining('360,00'), findsNothing);
    expect(find.textContaining('••••'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed preflight does not show fictitious balances', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SmartCheckinCard(
          spaceId: 'test-space',
          repository: _NoNetworkRepository(),
          loadReview: (_) async => throw Exception('offline'),
          loadWallet: (_) async => throw Exception('offline'),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Não foi possível verificar'), findsOneWidget);
    expect(find.textContaining('Tudo classificado'), findsNothing);
    expect(find.byKey(const ValueKey('smart-checkin-categorize')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
