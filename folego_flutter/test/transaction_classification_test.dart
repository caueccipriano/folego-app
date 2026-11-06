import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/repositories/folego_repository_transaction_classification.dart';

void main() {

  group('unclassified economic review', () {
    Map<String, dynamic> entry({
      String? categoryId,
      String eventType = 'card_purchase',
      String status = 'confirmed',
      Map<String, dynamic>? metadata,
    }) => {
      'event_type': eventType,
      'status': status,
      'category_id': categoryId,
      'metadata': metadata,
    };

    test('unclassified category enters review even without metadata flag', () {
      expect(
        isVisiblePendingClassificationRow(
          entry(categoryId: 'unclassified', metadata: {}),
          unclassifiedId: 'unclassified',
        ),
        isTrue,
      );
      expect(
        isVisiblePendingClassificationRow(
          entry(categoryId: null, metadata: {}),
          unclassifiedId: 'unclassified',
        ),
        isTrue,
      );
    });

    test('review disappears on categorization', () {
      expect(
        isVisiblePendingClassificationRow(
          entry(categoryId: 'groceries', metadata: {'needs_classification': false}),
          unclassifiedId: 'unclassified',
        ),
        isFalse,
      );
    });

    test('does not surface transfers, settled entries or hidden imports', () {
      expect(
        isVisiblePendingClassificationRow(
          entry(eventType: 'card_payment'),
          unclassifiedId: 'unclassified',
        ),
        isFalse,
      );
      expect(
        isVisiblePendingClassificationRow(
          entry(eventType: 'transfer'),
          unclassifiedId: 'unclassified',
        ),
        isFalse,
      );
      expect(
        isVisiblePendingClassificationRow(
          entry(status: 'ignored'),
          unclassifiedId: 'unclassified',
        ),
        isFalse,
      );
      expect(
        isVisiblePendingClassificationRow(
          entry(metadata: {'hidden': true, 'needs_classification': true}),
          unclassifiedId: 'unclassified',
        ),
        isFalse,
      );
    });

    test('legacy flagged categories still request review', () {
      expect(
        isVisiblePendingClassificationRow(
          entry(categoryId: 'mapped', metadata: {'needs_classification': true}),
          unclassifiedId: 'unclassified',
        ),
        isTrue,
      );
    });
  });

  group('transactionClassificationKind', () {
    test('uses income categories for income-like events', () {
      expect(transactionClassificationKind('income'), 'income');
      expect(transactionClassificationKind('benefit_credit'), 'income');
      expect(transactionClassificationKind('reimbursement'), 'income');
    });

    test('uses expense categories for expense-like events', () {
      expect(transactionClassificationKind('expense'), 'expense');
      expect(transactionClassificationKind('card_purchase'), 'expense');
      expect(transactionClassificationKind('benefit_expense'), 'expense');
      expect(transactionClassificationKind('refund'), 'expense');
      expect(transactionClassificationKind('debt_payment'), 'expense');
    });

    test('rejects non-economic event types', () {
      expect(transactionClassificationKind('transfer'), isNull);
      expect(transactionClassificationKind('card_payment'), isNull);
      expect(transactionClassificationKind('reserve_transfer'), isNull);
    });
  });
}
