import 'transaction_item.dart';

const int transactionPageSize = 50;

class TransactionCursor {
  const TransactionCursor({required this.occurredAt, required this.id});

  final DateTime occurredAt;
  final String id;
}

class TransactionPage {
  const TransactionPage({
    required this.items,
    required this.hasMore,
    required this.nextCursor,
  });

  final List<TransactionItem> items;
  final bool hasMore;
  final TransactionCursor? nextCursor;

  factory TransactionPage.fromFetched(
    List<TransactionItem> fetched, {
    int pageSize = transactionPageSize,
  }) {
    if (pageSize <= 0) {
      throw ArgumentError.value(pageSize, 'pageSize', 'Deve ser maior que zero.');
    }

    final hasMore = fetched.length > pageSize;
    final items = List<TransactionItem>.unmodifiable(fetched.take(pageSize));
    final last = items.isEmpty ? null : items.last;

    return TransactionPage(
      items: items,
      hasMore: hasMore,
      nextCursor: last == null
          ? null
          : TransactionCursor(occurredAt: last.occurredAt, id: last.id),
    );
  }
}

int compareTransactionsDescending(TransactionItem a, TransactionItem b) {
  final byOccurredAt = b.occurredAt.compareTo(a.occurredAt);

  if (byOccurredAt != 0) {
    return byOccurredAt;
  }

  return b.id.compareTo(a.id);
}

List<TransactionItem> mergeTransactionPages({
  required Iterable<TransactionItem> existing,
  required Iterable<TransactionItem> incoming,
  Set<String> hiddenIds = const <String>{},
}) {
  final byId = <String, TransactionItem>{};

  for (final transaction in existing) {
    if (!hiddenIds.contains(transaction.id)) {
      byId[transaction.id] = transaction;
    }
  }

  for (final transaction in incoming) {
    if (!hiddenIds.contains(transaction.id)) {
      byId[transaction.id] = transaction;
    }
  }

  final merged = byId.values.toList()..sort(compareTransactionsDescending);

  return merged;
}
