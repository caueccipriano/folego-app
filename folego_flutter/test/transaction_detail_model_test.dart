import 'package:flutter_test/flutter_test.dart';
import 'package:folego_flutter/data/models/transaction_detail.dart';

TransactionDetail detail({
  required String type,
  bool legacy = false,
  bool cardPurchaseReversible = false,
  bool cardPaymentReversible = false,
  List<TransactionDetailAccountImpact> impacts = const [],
}) {
  return TransactionDetail(
    id: 'event',
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
    cardPaymentReversible: cardPaymentReversible,
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
        TransactionDetailAccountImpact(dimension: 'cash', amount: -10, accountId: 'a'),
        TransactionDetailAccountImpact(dimension: 'cash', amount: 10, accountId: 'b'),
      ],
    );
    expect(item.isCanonicalTransfer, isTrue);
    expect(item.canEdit, isTrue);
    expect(item.canReverse, isTrue);
  });

  test('card purchase edit is type-specific and reversal follows safety flag', () {
    final locked = detail(type: 'card_purchase');
    final safe = detail(type: 'card_purchase', cardPurchaseReversible: true);
    expect(locked.canEdit, isTrue);
    expect(locked.canReverse, isFalse);
    expect(safe.canReverse, isTrue);
  });

  test('card payment never exposes generic edit', () {
    final payment = detail(type: 'card_payment', cardPaymentReversible: true);
    expect(payment.canEdit, isFalse);
    expect(payment.canReverse, isTrue);
  });

  test('opening balance is read only', () {
    final opening = detail(type: 'opening_balance');
    expect(opening.canEdit, isFalse);
    expect(opening.canReverse, isFalse);
  });
}
