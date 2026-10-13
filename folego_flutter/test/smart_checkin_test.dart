import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:folego/core/privacy/financial_privacy.dart';
import 'package:folego/data/models/category_item.dart';
import 'package:folego/data/models/automation_rule.dart';
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

  test('pending technical category is not mistaken for a final category', () {
    final suggestions = historicalCategorySuggestions(
      pending: [
        transaction('pending', categoryId: 'technical_pending'),
      ],
      history: [
        transaction('first', categoryId: 'food'),
        transaction('second', categoryId: 'food'),
      ],
      categories: [category],
    );
    expect(suggestions, {'pending': 'food'});
  });

  test('generic bank PIX text must NEVER auto-suggest a category', () {
    final suggestions = historicalCategorySuggestions(
      pending: [
        transaction('pending',
          description: 'PIX enviada - Santander'),
      ],
      history: [
        transaction('a', description: 'PIX enviada - Santander',
            categoryId: 'food'),
        transaction('b', description: 'PIX enviada - Santander',
            categoryId: 'food'),
        transaction('c', description: 'PIX enviada - Santander',
            categoryId: 'food'),
      ],
      categories: [category],
    );
    expect(suggestions, isEmpty);
    final grouped = matchingClassificationCandidates(
      transaction('pending', description: 'PIX enviada - Santander'),
      [transaction('second', description: 'PIX enviada - Santander')],
    );
    expect(grouped, isEmpty);
  });

  test('Autopilot offers only 3+ unanimous, exact, source-scoped cases', () {
    const description = 'PIX enviado - Doacao Centro';
    final history = [
      transaction('a', description: description,
          categoryId: 'food', source: 'sheet-sync'),
      transaction('b', description: description,
          categoryId: 'food', source: 'sheet-sync'),
      transaction('c', description: description,
          categoryId: 'food', source: 'sheet-sync'),
    ];
    final proposed = safeAutopilotRuleProposals(
      history: history,
      categories: [category],
      existingRules: const [],
    );
    expect(proposed, hasLength(1));
    expect(proposed.single.accountId, 'bank-one');
    expect(proposed.single.sampleCount, 3);
    expect(proposed.single.categoryId, 'food');

    const other = CategoryItem(
      id: 'other', name: 'outras', essential: false,
      categoryRole: 'economic', kind: 'expense',
    );
    final mixed = safeAutopilotRuleProposals(
      history: [
        ...history,
        transaction('different', description: description,
            categoryId: 'other', source: 'sheet-sync'),
      ],
      categories: [category, other],
      existingRules: const [],
    );
    expect(mixed, isEmpty);
  });

  test('existing exact account-scoped rule is not offered twice', () {
    const description = 'PIX enviado - Centro Cultural';
    final history = [
      for (var i=0; i<3; i++)
        transaction('id-$i', description: description,
            categoryId: 'food', source: 'sheet-sync'),
    ];
    final existing = AutomationRule(
      id: 'rule', spaceId: 'space', name: 'revisada',
      active: true, matchField: AutomationMatchField.description,
      matchType: AutomationMatchType.equals, matchValue: description,
      sourceScope: AutomationSourceScope.account,
      sourceAccountId: 'bank-one',
      direction: AutomationDirection.debit,
      actionType: AutomationActionType.reviewCategory,
      executionMode: AutomationExecutionMode.review,
      priority: 0, categoryId: 'food',
    );
    expect(safeAutopilotRuleProposals(
      history: history, categories: [category], existingRules: [existing],
    ), isEmpty);
  });

  testWidgets('approved rules execute before refreshing the read-only review',
      (tester) async {
    final order = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SmartCheckinCard(
          spaceId: 'space-a',
          repository: _NoNetworkRepository(),
          applyApprovedRules: (_) async {
            order.add('autopilot');
            return {'applied': 2};
          },
          loadReview: (_) async {
            order.add('review');
            return {'pending_count': 1};
          },
          loadWallet: (_) async {
            order.add('wallet');
            return const WalletOverview(
              summary: WalletSummary(
                totalCash: 300, availableCash: 300,
                totalCardInvoice: 0, totalDebtRemaining: 0,
              ),
              accounts: [], cards: [], debts: [], installments: [],
            );
          },
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(order.first, 'autopilot');
    expect(find.textContaining('2 lançamentos'), findsOneWidget);
    expect(find.textContaining('1 lançamento'), findsOneWidget);
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
