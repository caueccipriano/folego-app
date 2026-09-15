import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/transaction_detail.dart';

TransactionDetail detail({
  required String type,
  bool legacy = false,
  bool cardPurchaseReversible = false,
  bool cardPaymentReversible = false,
  String? cardPurchaseId,
  String? cardId,
  DateTime? cardPurchaseAt,
  String? cardPurchaseStatus,
  String? cardPaymentId,
  String? cardPaymentInvoiceId,
  String? cardPaymentAccountId,
  String? cardPaymentStatus,
  List<TransactionDetailAccountImpact> impacts = const [],
}) {
  return TransactionDetail(
    id: 'event-id',
    spaceId: 'space',
    eventType: type,
    description: 'teste',
    amount: 10,
    occurredAt: DateTime(2026, 9, 15),
    status: 'confirmed',
    source: 'app',
    impacts: impacts,
    legacyException: legacy,
    legacyKind: legacy ? 'one_sided_transfer' : null,
    cardPurchaseReversible: cardPurchaseReversible,
    cardPurchaseId: cardPurchaseId,
    cardId: cardId,
    cardPurchaseAt: cardPurchaseAt,
    cardPurchaseStatus: cardPurchaseStatus,
    cardPaymentReversible: cardPaymentReversible,
    cardPaymentId: cardPaymentId,
    cardPaymentInvoiceId: cardPaymentInvoiceId,
    cardPaymentAccountId: cardPaymentAccountId,
    cardPaymentStatus: cardPaymentStatus,
  );
}

void main() {
  test('legacy exception is always read only', () {
    final item = detail(
      type: 'transfer',
      legacy: true,
      impacts: const [
        TransactionDetailAccountImpact(
          dimension: 'cash',
          amount: 10,
          accountId: 'destination',
          accountName: 'Bradesco',
        ),
      ],
    );
    expect(item.canEdit, isFalse);
    expect(item.canReverse, isFalse);
  });

  test('canonical two-leg transfer exposes edit and reversal', () {
    final item = detail(
      type: 'transfer',
      impacts: const [
        TransactionDetailAccountImpact(
          dimension: 'cash',
          amount: -10,
          accountId: 'a',
        ),
        TransactionDetailAccountImpact(
          dimension: 'cash',
          amount: 10,
          accountId: 'b',
        ),
      ],
    );
    expect(item.isCanonicalTransfer, isTrue);
    expect(item.canEdit, isTrue);
    expect(item.canReverse, isTrue);
  });

  test('malformed or non zero-sum transfer stays read only', () {
    final malformed = detail(
      type: 'transfer',
      impacts: const [
        TransactionDetailAccountImpact(
          dimension: 'cash',
          amount: -10,
          accountId: 'a',
        ),
        TransactionDetailAccountImpact(
          dimension: 'cash',
          amount: 9,
          accountId: 'b',
        ),
      ],
    );
    expect(malformed.isCanonicalTransfer, isFalse);
    expect(malformed.canEdit, isFalse);
    expect(malformed.canReverse, isFalse);
  });

  test('card purchase requires backing before edit is exposed', () {
    final incomplete = detail(type: 'card_purchase');
    final safe = detail(
      type: 'card_purchase',
      cardPurchaseId: 'purchase',
      cardId: 'card',
      cardPurchaseAt: DateTime(2026, 9, 15),
      cardPurchaseStatus: 'confirmed',
      cardPurchaseReversible: true,
    );
    expect(incomplete.canEdit, isFalse);
    expect(incomplete.canReverse, isFalse);
    expect(safe.canEdit, isTrue);
    expect(safe.canReverse, isTrue);
  });

  test('benefit needs benefit backing and remains a type-specific action', () {
    final incomplete = detail(type: 'benefit_expense');
    final safe = detail(
      type: 'benefit_expense',
      impacts: const [
        TransactionDetailAccountImpact(
          dimension: 'benefit',
          amount: -10,
          accountId: 'benefit',
        ),
        TransactionDetailAccountImpact(dimension: 'economic', amount: -10),
        TransactionDetailAccountImpact(dimension: 'budget', amount: -10),
      ],
    );
    expect(incomplete.canEdit, isFalse);
    expect(incomplete.canReverse, isFalse);
    expect(safe.canEdit, isTrue);
    expect(safe.canReverse, isTrue);
  });

  test('card payment never exposes generic edit and needs complete backing', () {
    final incomplete = detail(type: 'card_payment', cardPaymentReversible: true);
    final safe = detail(
      type: 'card_payment',
      cardPaymentReversible: true,
      cardPaymentId: 'payment',
      cardPaymentInvoiceId: 'invoice',
      cardPaymentAccountId: 'account',
      cardPaymentStatus: 'confirmed',
    );
    expect(incomplete.canEdit, isFalse);
    expect(incomplete.canReverse, isFalse);
    expect(safe.canEdit, isFalse);
    expect(safe.canReverse, isTrue);
  });

  test('opening balance, debt, refund and adjustment are read only', () {
    for (final type in ['opening_balance', 'debt_payment', 'refund', 'adjustment']) {
      final item = detail(type: type);
      expect(item.canEdit, isFalse, reason: type);
      expect(item.canReverse, isFalse, reason: type);
    }
  });
}
