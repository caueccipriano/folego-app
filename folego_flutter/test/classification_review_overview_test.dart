import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/transaction_item.dart';
import 'package:folego/data/repositories/folego_repository_transaction_classification.dart';
import 'package:folego/features/transactions/classification_review_overview.dart';

TransactionItem _event(String id, String? categoryId) => TransactionItem(
  id: id,
  description: 'Transação sintética $id',
  eventType: 'expense',
  amount: 15,
  occurredAt: DateTime.utc(2026, 10, 13),
  status: 'confirmed',
  source: 'sheet-sync',
  categoryId: categoryId,
);

void main() {
  test('metadata filter excludes hidden, unflagged and malformed rows', () {
    expect(isVisiblePendingClassificationMetadata({
      'needs_classification': true,
      'hidden': false,
    }), isTrue);
    expect(isVisiblePendingClassificationMetadata({
      'needs_classification': 'true',
    }), isTrue);
    expect(isVisiblePendingClassificationMetadata({
      'needs_classification': true,
      'hidden': true,
    }), isFalse);
    expect(isVisiblePendingClassificationMetadata({
      'needs_classification': 'true',
      'hidden': 'true',
    }), isFalse);
    expect(isVisiblePendingClassificationMetadata({
      'needs_classification': false,
    }), isFalse);
    expect(isVisiblePendingClassificationMetadata(null), isFalse);
  });

  test('breakdown distinguishes missing categories from review flags', () {
    final summary = ClassificationReviewOverview.fromItems([
      _event('a', null),
      _event('b', ''),
      _event('c', 'category-1'),
    ]);
    expect(summary.total, 3);
    expect(summary.needsCategory, 2);
    expect(summary.hasCategoryToReview, 1);
    expect(summary.description,
        '2 sem categoria • 1 com categoria para conferir');
  });

  test('review query failures never appear as completed classifications', () {
    expect(pendingClassificationTooltip(
      loading: false, unavailable: true, pendingCount: 0,
    ), contains('indisponíveis'));
    expect(pendingClassificationTooltip(
      loading: true, unavailable: false, pendingCount: 0,
    ), 'consultando pendências');
    expect(pendingClassificationTooltip(
      loading: false, unavailable: false, pendingCount: 0,
    ), 'nenhuma classificação pendente');
    expect(pendingClassificationTooltip(
      loading: false, unavailable: false, pendingCount: 16,
    ), 'conferir 16 lançamentos pendentes');
  });
}
