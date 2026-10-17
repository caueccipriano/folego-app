import 'package:flutter_test/flutter_test.dart';

import 'package:folego/data/models/transaction_item.dart';
import 'package:folego/features/transactions/transaction_classification_inbox.dart';

TransactionItem item({
  String id = 'pending-1',
  String name = 'PIX enviada - Santander',
  String type = 'expense',
  String source = 'sheet-sync',
}) => TransactionItem(
      id: id,
      eventType: type,
      description: name,
      amount: 49,
      occurredAt: DateTime(2026, 9, 18, 17, 9),
      status: 'confirmed',
      source: source,
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
}
