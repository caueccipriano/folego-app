import '../../core/utils/financial_display_text.dart';
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
    this.categoryId,
    this.groupedCategories = const <HomeCategoryExpense>[],
  });

  final String category;
  final double amount;
  final double share;
  final String? categoryId;
  final List<HomeCategoryExpense> groupedCategories;

  int get percentage => (share * 100).round();
  bool get isOther => groupedCategories.isNotEmpty;
}

class HomeExpenseBreakdown {
  const HomeExpenseBreakdown({required this.total, required this.categories});

  final double total;
  final List<HomeCategoryExpense> categories;

  bool get isEmpty => total <= 0 || categories.isEmpty;
}

HomeExpenseBreakdown buildHomeExpenseBreakdown(
  Iterable<TransactionItem> transactions, {
  required String Function(TransactionItem transaction) categoryFor,
  String? Function(TransactionItem transaction)? categoryIdFor,
  int maxSegments = 6,
}) {
  if (maxSegments < 2) {
    throw ArgumentError.value(
      maxSegments,
      'maxSegments',
      'Deve permitir pelo menos duas categorias.',
    );
  }

  final totals = <String, _HomeExpenseBucket>{};
  for (final transaction in transactions) {
    if (!isHomeExpenseEventType(transaction.eventType)) continue;
    final amount = transaction.amount.abs();
    if (amount <= 0) continue;

    final rawCategory = categoryFor(transaction).trim();
    final category = rawCategory.isEmpty ? 'A classificar' : rawCategory;
    final categoryId = categoryIdFor?.call(transaction) ??
        transaction.categoryParentId ??
        transaction.categoryId;
    final key = categoryId ?? 'label:${category.toLowerCase()}';
    final existing = totals[key];
    totals[key] = _HomeExpenseBucket(
      category: existing?.category ?? category,
      categoryId: existing?.categoryId ?? categoryId,
      amount: (existing?.amount ?? 0) + amount,
    );
  }

  if (totals.isEmpty) {
    return const HomeExpenseBreakdown(total: 0, categories: []);
  }

  final sorted = totals.values.toList()
    ..sort((a, b) => b.amount.compareTo(a.amount));
  final total = sorted.fold<double>(0, (sum, item) => sum + item.amount);
  if (total <= 0) {
    return const HomeExpenseBreakdown(total: 0, categories: []);
  }

  final visible = <HomeCategoryExpense>[];
  if (sorted.length > maxSegments) {
    final keepCount = maxSegments - 1;
    for (final item in sorted.take(keepCount)) {
      visible.add(item.toExpense(total));
    }

    final grouped = sorted
        .skip(keepCount)
        .map((item) => item.toExpense(total))
        .toList(growable: false);
    final groupedAmount = grouped.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );
    visible.add(
      HomeCategoryExpense(
        category: 'Outros',
        amount: groupedAmount,
        share: groupedAmount / total,
        groupedCategories: grouped,
      ),
    );
  } else {
    visible.addAll(sorted.map((item) => item.toExpense(total)));
  }

  return HomeExpenseBreakdown(total: total, categories: visible);
}

class _HomeExpenseBucket {
  const _HomeExpenseBucket({
    required this.category,
    required this.categoryId,
    required this.amount,
  });

  final String category;
  final String? categoryId;
  final double amount;

  HomeCategoryExpense toExpense(double total) {
    return HomeCategoryExpense(
      category: category,
      categoryId: categoryId,
      amount: amount,
      share: amount / total,
    );
  }
}

String homeDisplayDescription(String description) =>
    financialDisplayDescription(description);
