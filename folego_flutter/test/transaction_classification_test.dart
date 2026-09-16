import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/repositories/folego_repository_transaction_classification.dart';

void main() {
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
