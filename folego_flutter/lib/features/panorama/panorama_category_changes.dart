import '../../data/models/budget_overview_item.dart';

/// A change in RECORDED category spending between the two last complete
/// calendar months. Read-only and informational, never a spending verdict.
class PanoramaCategoryChange {
  const PanoramaCategoryChange({
    required this.categoryId,
    required this.categoryName,
    required this.earlierAmount,
    required this.laterAmount,
  });

  final String categoryId;
  final String categoryName;
  final double earlierAmount;
  final double laterAmount;

  double get difference => laterAmount - earlierAmount;
  bool get increased => difference > 0;
}

/// Compares only the SAME stable parent-category ID in BOTH returned periods.
/// An unknown source cannot masquerade as zero, and a newly added/deleted or
/// recategorized category is not compared against a fake empty prior month.
/// Parent amounts already include their children: never sum children again.
class PanoramaCategoryChanges {
  const PanoramaCategoryChanges._({
    required this.earlierMonth,
    required this.laterMonth,
    required this.commonCategories,
    required this.changes,
  });

  final DateTime earlierMonth;
  final DateTime laterMonth;
  final int commonCategories;
  final List<PanoramaCategoryChange> changes;

  /// Null = one/both historical queries failed. Non-null with zero matches
  /// means both queries succeeded but no stable category intersection exists.
  static PanoramaCategoryChanges? compare({
    required List<BudgetOverviewItem>? earlier,
    required List<BudgetOverviewItem>? later,
    required DateTime referenceDate,
    int maxItems = 3,
  }) {
    if (earlier == null || later == null) return null;
    final earlierMap = _uniqueParents(earlier);
    final laterMap = _uniqueParents(later);
    final common = earlierMap.keys
        .where(laterMap.containsKey)
        .toList(growable: false);
    final differences = <PanoramaCategoryChange>[];
    for (final id in common) {
      final from = earlierMap[id]!;
      final to = laterMap[id]!;
      if (from.actualAmount == to.actualAmount) continue;
      differences.add(PanoramaCategoryChange(
        categoryId: id,
        // Use current/later name for an explicitly renamed category ID.
        categoryName: to.categoryName,
        earlierAmount: from.actualAmount,
        laterAmount: to.actualAmount,
      ));
    }
    // Largest absolute recorded changes first; do not attach an opinionated
    // "good"/"bad" label to an increase or decrease.
    differences.sort((a, b) {
      final magnitude = b.difference.abs().compareTo(a.difference.abs());
      return magnitude != 0
          ? magnitude
          : a.categoryName.compareTo(b.categoryName);
    });
    return PanoramaCategoryChanges._(
      earlierMonth: DateTime(referenceDate.year, referenceDate.month - 2),
      laterMonth: DateTime(referenceDate.year, referenceDate.month - 1),
      commonCategories: common.length,
      changes: differences.take(maxItems < 0 ? 0 : maxItems).toList(
        growable: false,
      ),
    );
  }

  static Map<String, BudgetOverviewItem> _uniqueParents(
    List<BudgetOverviewItem> rows,
  ) {
    final result = <String, BudgetOverviewItem>{};
    final duplicates = <String>{};
    for (final item in rows) {
      if (!item.isParent ||
          item.categoryId.trim().isEmpty ||
          item.categoryName.trim().isEmpty ||
          !item.actualAmount.isFinite ||
          item.actualAmount < 0) {
        continue;
      }
      final id = item.categoryId;
      if (result.containsKey(id)) {
        result.remove(id);
        duplicates.add(id);
      } else if (!duplicates.contains(id)) {
        result[id] = item;
      }
    }
    return result;
  }
}
