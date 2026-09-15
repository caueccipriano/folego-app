import 'transaction_item.dart';

const Set<String> homeExpenseEventTypes = {
  'expense',
  'card_purchase',
  'benefit_expense',
  'debt_payment',
};

bool isHomeExpenseEventType(String eventType) {
  return homeExpenseEventTypes.contains(eventType);
}

class HomeCategoryExpense {
  const HomeCategoryExpense({
    required this.category,
    required this.amount,
    required this.share,
  });

  final String category;
  final double amount;
  final double share;

  int get percentage => (share * 100).round();
}

class HomeExpenseBreakdown {
  const HomeExpenseBreakdown({
    required this.total,
    required this.categories,
  });

  final double total;
  final List<HomeCategoryExpense> categories;

  bool get isEmpty => total <= 0 || categories.isEmpty;
}

HomeExpenseBreakdown buildHomeExpenseBreakdown(
  Iterable<TransactionItem> transactions, {
  required String Function(TransactionItem transaction) categoryFor,
  int maxSegments = 4,
}) {
  if (maxSegments < 2) {
    throw ArgumentError.value(
      maxSegments,
      'maxSegments',
      'Deve permitir pelo menos duas categorias.',
    );
  }

  final totals = <String, double>{};

  for (final transaction in transactions) {
    if (!isHomeExpenseEventType(transaction.eventType)) {
      continue;
    }

    final amount = transaction.amount.abs();
    if (amount <= 0) {
      continue;
    }

    final rawCategory = categoryFor(transaction).trim();
    final category = rawCategory.isEmpty ? 'A classificar' : rawCategory;

    totals[category] = (totals[category] ?? 0) + amount;
  }

  if (totals.isEmpty) {
    return const HomeExpenseBreakdown(total: 0, categories: []);
  }

  final otherKey = totals.keys.cast<String?>().firstWhere(
    (key) => key?.toLowerCase() == 'outros',
    orElse: () => null,
  );
  final existingOther = otherKey == null ? 0.0 : totals.remove(otherKey) ?? 0.0;

  final sorted = totals.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  final visible = <MapEntry<String, double>>[];
  final categoryCount = sorted.length + (existingOther > 0 ? 1 : 0);

  if (categoryCount > maxSegments) {
    final keepCount = maxSegments - 1;
    visible.addAll(sorted.take(keepCount));

    final groupedOther = existingOther +
        sorted.skip(keepCount).fold<double>(
          0,
          (total, entry) => total + entry.value,
        );

    if (groupedOther > 0) {
      visible.add(MapEntry('Outros', groupedOther));
    }
  } else {
    visible.addAll(sorted);
    if (existingOther > 0) {
      visible.add(MapEntry('Outros', existingOther));
    }
    visible.sort((a, b) => b.value.compareTo(a.value));
  }

  final total = visible.fold<double>(
    0,
    (sum, entry) => sum + entry.value,
  );

  if (total <= 0) {
    return const HomeExpenseBreakdown(total: 0, categories: []);
  }

  return HomeExpenseBreakdown(
    total: total,
    categories: visible
        .map(
          (entry) => HomeCategoryExpense(
            category: entry.key,
            amount: entry.value,
            share: entry.value / total,
          ),
        )
        .toList(growable: false),
  );
}

String homeDisplayDescription(String description) {
  return description
      .replaceFirst(
        RegExp(r'\s*\[extrato\s+\d+\]\s*$', caseSensitive: false),
        '',
      )
      .trim();
}
