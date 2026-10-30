import '../../data/models/budget_overview_item.dart';

/// Read-only guidance based solely on returned Plan budget totals.
enum PlanReviewReason { uncategorized, overLimit, noLimit, approachingLimit }

class PlanReviewTarget {
  const PlanReviewTarget({
    required this.category,
    required this.reason,
  });

  final BudgetOverviewItem category;
  final PlanReviewReason reason;
}

/// The backend supplies parent totals that already include subcategories.
/// Never add children here: that would count the same purchase twice.
List<PlanReviewTarget> spendingReviewTargets(
  Iterable<BudgetOverviewItem> items, {
  int limit = 3,
}) {
  final targets = <PlanReviewTarget>[];
  for (final item in items.where((item) => item.isParent && item.hasActivity)) {
    final PlanReviewReason? reason;
    if (item.isPending) {
      reason = PlanReviewReason.uncategorized;
    } else if (item.hasBudget && item.remainingAmount < 0) {
      reason = PlanReviewReason.overLimit;
    } else if (!item.hasBudget) {
      reason = PlanReviewReason.noLimit;
    } else if (item.progressState == BudgetProgressState.attention) {
      reason = PlanReviewReason.approachingLimit;
    } else {
      reason = null;
    }
    if (reason != null) {
      targets.add(PlanReviewTarget(category: item, reason: reason));
    }
  }
  int priority(PlanReviewReason reason) => switch (reason) {
    PlanReviewReason.uncategorized => 0,
    PlanReviewReason.overLimit => 1,
    PlanReviewReason.noLimit => 2,
    PlanReviewReason.approachingLimit => 3,
  };
  targets.sort((a, b) {
    final byPriority = priority(a.reason).compareTo(priority(b.reason));
    if (byPriority != 0) return byPriority;
    final aImpact = a.reason == PlanReviewReason.overLimit
        ? -a.category.remainingAmount : a.category.actualAmount;
    final bImpact = b.reason == PlanReviewReason.overLimit
        ? -b.category.remainingAmount : b.category.actualAmount;
    final byImpact = bImpact.compareTo(aImpact);
    if (byImpact != 0) return byImpact;
    return a.category.categoryName.compareTo(b.category.categoryName);
  });
  return targets.take(limit < 0 ? 0 : limit).toList(growable: false);
}

/// Suggest only the next *category to review*. Never save a limit automatically.
BudgetOverviewItem? nextPlanCategory(Iterable<BudgetOverviewItem> items) {
  final children = items
      .where((item) =>
          item.isSubcategory && !item.isPending &&
          (!item.hasBudget || item.isOverBudget))
      .toList();
  if (children.isEmpty) return null;
  children.sort((a, b) {
    int priority(BudgetOverviewItem item) {
      if (!item.hasBudget && item.hasActivity) return 0;
      if (item.isOverBudget) return 1;
      if (!item.hasBudget) return 2;
      return 3;
    }
    final byPriority = priority(a).compareTo(priority(b));
    if (byPriority != 0) return byPriority;
    final byAmount = b.actualAmount.compareTo(a.actualAmount);
    if (byAmount != 0) return byAmount;
    return a.categoryName.compareTo(b.categoryName);
  });
  return children.first;
}


/// Parent-level spending includes its children, so only recommend a specific
/// editable child. A technical pending bucket and direct unallocated postings
/// must not be mistaken for categories that can receive a limit.
BudgetOverviewItem? editableChildForReview(
  BudgetOverviewItem parent,
  Iterable<BudgetOverviewItem> items,
) {
  if (!parent.isParent || parent.isPending) return null;
  final children = items.where(
    (item) => item.parentId == parent.categoryId &&
        !item.isPending && !item.hasBudget,
  ).toList();
  children.sort((a, b) {
    final spending = b.actualAmount.compareTo(a.actualAmount);
    if (spending != 0) return spending;
    return a.categoryName.compareTo(b.categoryName);
  });
  return children.isEmpty ? null : children.first;
}
