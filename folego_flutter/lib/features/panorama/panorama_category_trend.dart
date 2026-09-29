import '../../data/models/budget_overview_item.dart';

/// Each source must be the result of its own successful, authenticated,
/// financial-space-scoped historical budget query. Null means unavailable,
/// whereas an empty list means the scoped query succeeded.
class PanoramaCategoryMonth {
  const PanoramaCategoryMonth({
    required this.periodMonth,
    required this.categories,
  });

  final DateTime periodMonth;
  final List<BudgetOverviewItem> categories;
}

class PanoramaCategoryChange {
  const PanoramaCategoryChange({
    required this.categoryId,
    required this.currentName,
    required this.earlierAmount,
    required this.laterAmount,
  });

  final String categoryId;
  final String currentName;
  final double earlierAmount;
  final double laterAmount;

  double get delta => laterAmount - earlierAmount;
}

/// Change in RECORDED economic spending, never a complete external-bank
/// reconciliation or judgment. Use stable parent category IDs, not names.
class PanoramaCategoryTrend {
  const PanoramaCategoryTrend._({
    required this.earlierPeriod,
    required this.laterPeriod,
    required this.allComparableCount,
    required this.largestChanges,
  });

  final DateTime earlierPeriod;
  final DateTime laterPeriod;
  final int allComparableCount;
  final List<PanoramaCategoryChange> largestChanges;

  static PanoramaCategoryTrend? tryFrom({
    required PanoramaCategoryMonth? earlier,
    required PanoramaCategoryMonth? later,
    required DateTime referenceDate,
    int maxItems = 3,
  }) {
    if (earlier == null || later == null) return null;
    if (!_sameMonth(
          earlier.periodMonth, DateTime(referenceDate.year, referenceDate.month - 2),
        ) ||
        !_sameMonth(
          later.periodMonth, DateTime(referenceDate.year, referenceDate.month - 1),
        )) {
      return null;
    }

    // Multiple parent rows with the same ID are an invalid server response.
    // Skip duplicates rather than computing a false before/after number.
    Map<String, BudgetOverviewItem> uniqueParents(
      List<BudgetOverviewItem> items,
    ) {
      final first = <String, BudgetOverviewItem>{};
      final duplicates = <String>{};
      for (final item in items) {
        if (!item.isParent ||
            item.categoryId.trim().isEmpty ||
            !item.actualAmount.isFinite) {
          continue;
        }
        if (first.containsKey(item.categoryId)) {
          duplicates.add(item.categoryId);
        } else {
          first[item.categoryId] = item;
        }
      }
      for (final id in duplicates) {
        first.remove(id);
      }
      return first;
    }

    final past = uniqueParents(earlier.categories);
    final recent = uniqueParents(later.categories);
    final matched = <PanoramaCategoryChange>[];
    for (final id in past.keys) {
      final current = recent[id];
      if (current == null) {
        // An absent category may have been renamed with a NEW identifier,
        // archived, or reparented. Never interpret absence as zero spending.
        continue;
      }
      final old = past[id]!;
      matched.add(PanoramaCategoryChange(
        categoryId: id,
        currentName: current.categoryName,
        earlierAmount: old.actualAmount,
        laterAmount: current.actualAmount,
      ));
    }

    final changes = matched.where((entry) => entry.delta != 0).toList()
      ..sort((a, b) {
        final largest = b.delta.abs().compareTo(a.delta.abs());
        if (largest != 0) return largest;
        return a.categoryId.compareTo(b.categoryId);
      });

    return PanoramaCategoryTrend._(
      earlierPeriod: earlier.periodMonth,
      laterPeriod: later.periodMonth,
      allComparableCount: matched.length,
      largestChanges: maxItems <= 0
          ? const <PanoramaCategoryChange>[]
          : changes.take(maxItems).toList(growable: false),
    );
  }

  static bool _sameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;
}
