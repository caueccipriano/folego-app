import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/transaction_filters.dart';
import 'package:folego/data/models/transaction_item.dart';
import 'package:folego/data/models/transaction_page.dart';

void main() {
  test('transaction filters are immutable and count every active filter group', () {
    final originalTypes = <String>{'expense', 'card_purchase'};
    final filters = TransactionFilters(
      startDate: DateTime(2026, 9, 1),
      endDate: DateTime(2026, 9, 30),
      eventTypes: originalTypes,
      categoryId: 'category-1',
      accountId: 'account-1',
      cardId: 'card-1',
      benefitAccountId: 'benefit-1',
      search: '  Uber  ',
    );

    originalTypes.clear();

    expect(filters.eventTypes, {'expense', 'card_purchase'});
    expect(filters.startDate, DateTime(2026, 9, 1));
    expect(filters.endDate, DateTime(2026, 9, 30));
    expect(filters.categoryId, 'category-1');
    expect(filters.accountId, 'account-1');
    expect(filters.cardId, 'card-1');
    expect(filters.benefitAccountId, 'benefit-1');
    expect(filters.normalizedSearch, 'Uber');
    expect(filters.activeFilterCount, 6);
    expect(filters.hasQuery, isTrue);
    expect(() => filters.eventTypes.add('income'), throwsUnsupportedError);
  });

  test('copyWith clears nullable filters without changing unrelated query state', () {
    final filters = TransactionFilters(
      startDate: DateTime(2026, 9, 1),
      endDate: DateTime(2026, 9, 30),
      eventTypes: const {'expense'},
      categoryId: 'category-1',
      accountId: 'account-1',
      cardId: 'card-1',
      benefitAccountId: 'benefit-1',
      search: 'uber',
    );

    final next = filters.copyWith(
      startDate: null,
      endDate: null,
      categoryId: null,
      accountId: null,
      cardId: null,
      benefitAccountId: null,
      eventTypes: const <String>{},
    );

    expect(next.hasFilters, isFalse);
    expect(next.search, 'uber');
    expect(next.hasQuery, isTrue);
  });

  test('value equality compares filter content rather than set identity', () {
    final first = TransactionFilters(
      startDate: DateTime(2026, 9, 1, 8),
      endDate: DateTime(2026, 9, 30, 22),
      eventTypes: const {'income', 'expense'},
      search: 'uber',
    );
    final second = TransactionFilters(
      startDate: DateTime(2026, 9, 1),
      endDate: DateTime(2026, 9, 30),
      eventTypes: const {'expense', 'income'},
      search: 'uber',
    );

    expect(first, second);
    expect(first.hashCode, second.hashCode);
  });

  test('default transaction page size remains 50 with compound cursor', () {
    expect(transactionPageSize, 50);

    final fetched = List<TransactionItem>.generate(
      51,
      (index) => TransactionItem(
        id: 'id-${(51 - index).toString().padLeft(2, '0')}',
        eventType: 'expense',
        description: 'item $index',
        amount: 10,
        occurredAt: DateTime.utc(2026, 9, 15, 12).subtract(
          Duration(minutes: index),
        ),
        status: 'confirmed',
        source: 'test',
      ),
    );

    final page = TransactionPage.fromFetched(fetched);

    expect(page.items, hasLength(50));
    expect(page.hasMore, isTrue);
    expect(page.nextCursor?.id, fetched[49].id);
    expect(page.nextCursor?.occurredAt, fetched[49].occurredAt);
  });
}
