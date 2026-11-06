import 'package:flutter_test/flutter_test.dart';

import 'package:folego/data/models/transaction_item.dart';
import 'package:folego/data/models/category_item.dart';
import 'package:folego/features/transactions/transaction_classification_inbox.dart';

TransactionItem item({
  String id = 'pending-1',
  String name = 'PIX enviada - Santander',
  String type = 'expense',
  String source = 'sheet-sync',
  String? categoryId,
  bool needsClassification = false,
}) => TransactionItem(
      id: id,
      eventType: type,
      description: name,
      amount: 49,
      occurredAt: DateTime(2026, 9, 18, 17, 9),
      status: 'confirmed',
      source: source,
      categoryId: categoryId,
      needsClassification: needsClassification,
      accountId: 'bank-one',
    );

void main() {
  test('generic debit PIX tells the reviewer to check counterparty, not guess', () {
    final hint = classificationEvidenceHint(item());
    expect(hint, isNotNull);
    expect(hint, contains('não identifica'));
    expect(hint, contains('extrato'));
  });

  test('generic credit PIX receives the same caution', () {
    expect(classificationEvidenceHint(item(
      name: 'PIX recebida - Santander', type: 'income',
    )), contains('extrato'));
  });

  test('a cryptic card purchase explicitly requires statement context', () {
    final hint = classificationEvidenceHint(item(
      name: 'PauloHenrique',
      type: 'card_purchase',
    ));
    expect(hint, contains('fatura'));
    expect(hint, isNot(contains('Alimentação')));
  });

  test('a specific recognized merchant does not get a generic alert', () {
    expect(classificationEvidenceHint(item(
      name: 'MERCADOLIVRE*ME',
      source: 'sheet-sync',
    )), isNull);
  });

  test('classification hints never assign category, amount or account', () {
    final original = item();
    classificationEvidenceHint(original);
    expect(original.categoryId, isNull);
    expect(original.amount, 49);
    expect(original.accountId, 'bank-one');
  });
  test('review-pending history cannot become trusted batch evidence', () {
    final categories = [
      const CategoryItem(
        id: 'groceries',
        name: 'Mercado',
        essential: false,
        categoryRole: 'economic',
        kind: 'expense',
      ),
    ];
    final history = [
      item(
        id: 'historic-a',
        name: 'Mercado do bairro',
        categoryId: 'groceries',
        needsClassification: true,
      ),
      item(
        id: 'historic-b',
        name: 'Mercado do bairro',
        categoryId: 'groceries',
        needsClassification: true,
      ),
    ];
    final pending = [
      item(id: 'pending', name: 'Mercado do bairro'),
    ];
    expect(historicalCategorySuggestions(
      pending: pending,
      history: history,
      categories: categories,
    ), isEmpty);
    expect(safeAutopilotRuleProposals(
      history: [...history, item(
        id: 'historic-c',
        name: 'Mercado do bairro',
        categoryId: 'groceries',
        needsClassification: true,
      )],
      categories: categories,
      existingRules: const [],
    ), isEmpty);

    final approvedHistory = [
      for (final id in ['a', 'b', 'c'])
        item(id: id, name: 'Mercado do bairro', categoryId: 'groceries'),
    ];
    expect(historicalCategorySuggestions(
      pending: pending,
      history: approvedHistory,
      categories: categories,
    )['pending'], 'groceries');
    expect(safeAutopilotRuleProposals(
      history: approvedHistory,
      categories: categories,
      existingRules: const [],
    ), hasLength(1));
  });

  test('generic bank PIX cannot become a remembered category rule', () {
    expect(canRememberClassificationRule(item()), isFalse);
    expect(canRememberClassificationRule(item(
      name: 'PIX recebido - Santander',
      type: 'income',
    )), isFalse);
    expect(canRememberClassificationRule(item(
      name: 'PIX enviado',
    )), isFalse);
  });

  test('only meaningful account entries may offer remembered categories', () {
    expect(canRememberClassificationRule(item(
      name: 'MERCADO DO BAIRRO',
    )), isTrue);
    expect(canRememberClassificationRule(item(
      name: 'SALARIO MENSAL',
      type: 'income',
    )), isTrue);
    expect(canRememberClassificationRule(item(
      name: 'MERCADO DO BAIRRO',
      type: 'card_purchase',
    )), isFalse);
    expect(canRememberClassificationRule(TransactionItem(
      id: 'unknown-source',
      eventType: 'expense',
      description: 'MERCADO DO BAIRRO',
      amount: 35,
      occurredAt: DateTime(2026, 11, 6),
      status: 'confirmed',
      source: 'sheet-sync',
    )), isFalse);
  });

}
