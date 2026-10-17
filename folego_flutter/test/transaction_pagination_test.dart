import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/transaction_item.dart';
import 'package:folego/data/models/transaction_page.dart';

void main() {
  group('TransactionPage', () {
    test('keeps the requested first page and exposes a stable cursor', () {
      final fetched = [
        _transaction('c', DateTime.utc(2026, 9, 14, 12)),
        _transaction('b', DateTime.utc(2026, 9, 14, 11)),
        _transaction('a', DateTime.utc(2026, 9, 14, 10)),
      ];

      final page = TransactionPage.fromFetched(fetched, pageSize: 2);

      expect(page.items.map((item) => item.id), ['c', 'b']);
      expect(page.hasMore, isTrue);
      expect(page.nextCursor?.id, 'b');
      expect(page.nextCursor?.occurredAt, DateTime.utc(2026, 9, 14, 11));
    });

    test('marks the last page when there is no lookahead item', () {
      final page = TransactionPage.fromFetched(
        [_transaction('a', DateTime.utc(2026, 9, 14, 10))],
        pageSize: 2,
      );

      expect(page.hasMore, isFalse);
      expect(page.items.map((item) => item.id), ['a']);
    });
  });

  group('mergeTransactionPages', () {
    test('appends a second page without losing descending order', () {
      final merged = mergeTransactionPages(
        existing: [
          _transaction('d', DateTime.utc(2026, 9, 14, 12)),
          _transaction('c', DateTime.utc(2026, 9, 14, 11)),
        ],
        incoming: [
          _transaction('b', DateTime.utc(2026, 9, 14, 10)),
          _transaction('a', DateTime.utc(2026, 9, 14, 9)),
        ],
      );

      expect(merged.map((item) => item.id), ['d', 'c', 'b', 'a']);
    });

    test('deduplicates overlapping pages by transaction id', () {
      final merged = mergeTransactionPages(
        existing: [
          _transaction('c', DateTime.utc(2026, 9, 14, 12)),
          _transaction('b', DateTime.utc(2026, 9, 14, 11)),
        ],
        incoming: [
          _transaction('b', DateTime.utc(2026, 9, 14, 11)),
          _transaction('a', DateTime.utc(2026, 9, 14, 10)),
        ],
      );

      expect(merged.map((item) => item.id), ['c', 'b', 'a']);
    });

    test('uses id descending as tie breaker for equal occurredAt', () {
      final occurredAt = DateTime.utc(2026, 9, 14, 12);

      final merged = mergeTransactionPages(
        existing: [_transaction('a', occurredAt)],
        incoming: [
          _transaction('c', occurredAt),
          _transaction('b', occurredAt),
        ],
      );

      expect(merged.map((item) => item.id), ['c', 'b', 'a']);
    });

    test('keeps hidden pending deletions out after a page merge', () {
      final merged = mergeTransactionPages(
        existing: [_transaction('b', DateTime.utc(2026, 9, 14, 11))],
        incoming: [
          _transaction('c', DateTime.utc(2026, 9, 14, 12)),
          _transaction('a', DateTime.utc(2026, 9, 14, 10)),
        ],
        hiddenIds: const {'c'},
      );

      expect(merged.map((item) => item.id), ['b', 'a']);
    });

    test('restores an undone paginated item in sorted order without duplicates', () {
      final restored = _transaction('b', DateTime.utc(2026, 9, 14, 11));

      final merged = mergeTransactionPages(
        existing: [
          _transaction('c', DateTime.utc(2026, 9, 14, 12)),
          _transaction('a', DateTime.utc(2026, 9, 14, 10)),
        ],
        incoming: [restored, restored],
      );

      expect(merged.map((item) => item.id), ['c', 'b', 'a']);
    });
  });
}

TransactionItem _transaction(String id, DateTime occurredAt) {
  return TransactionItem(
    id: id,
    eventType: 'expense',
    description: id,
    amount: 10,
    occurredAt: occurredAt,
    status: 'confirmed',
    source: 'app',
  );
}
