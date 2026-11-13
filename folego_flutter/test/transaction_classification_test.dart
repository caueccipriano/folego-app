import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/repositories/folego_repository_transaction_classification.dart';
import 'package:folego/data/models/category_item.dart';
import 'package:folego/data/models/transaction_item.dart';
import 'package:folego/features/transactions/transaction_classification_inbox.dart';

void main() {
  group('reviewableCurrentCategory', () {
    TransactionItem event({String? categoryId = 'transport', String type = 'card_purchase'}) {
      return TransactionItem(
        id: 'buson-2026-11-13',
        eventType: type,
        description: '62Buson~Viagens',
        amount: 26.16,
        occurredAt: DateTime.utc(2026, 11, 13),
        status: 'confirmed',
        source: 'sheet-sync',
        categoryId: categoryId,
        categoryName: 'Transporte público',
      );
    }

    const transport = CategoryItem(
      id: 'transport',
      name: 'Transporte público',
      kind: 'expense',
      essential: false,
      categoryRole: 'economic',
    );

    test('resolves already-assigned category to offer explicit confirmation', () {
      expect(
        reviewableCurrentCategory(item: event(), categories: [transport])?.id,
        'transport',
      );
    });

    test('never claims a category not present in the catalog', () {
      expect(reviewableCurrentCategory(item: event(), categories: const []), isNull);
      expect(
        reviewableCurrentCategory(item: event(categoryId: null), categories: [transport]),
        isNull,
      );
    });

    test('refuses disabled and wrong-kind categories', () {
      final inactive = CategoryItem(
        id: transport.id,
        name: transport.name,
        kind: transport.kind,
        essential: false,
        categoryRole: 'economic',
        active: false,
      );
      expect(reviewableCurrentCategory(item: event(), categories: [inactive]), isNull);
      expect(
        reviewableCurrentCategory(item: event(type: 'income'), categories: [transport]),
        isNull,
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
