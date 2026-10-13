import '../../data/models/transaction_item.dart';

/// Read-only breakdown of records already marked for manual review.
/// A pre-existing category is not evidence that review has been completed.
final class ClassificationReviewOverview {
  const ClassificationReviewOverview({
    required this.needsCategory,
    required this.hasCategoryToReview,
  });

  final int needsCategory;
  final int hasCategoryToReview;

  int get total => needsCategory + hasCategoryToReview;

  String get description {
    if (total == 0) return 'tudo em dia por aqui';
    if (needsCategory == 0) {
      return '$hasCategoryToReview com categoria para conferir';
    }
    if (hasCategoryToReview == 0) {
      return '$needsCategory sem categoria';
    }
    return '$needsCategory sem categoria • '
        '$hasCategoryToReview com categoria para conferir';
  }

  static ClassificationReviewOverview fromItems(
    Iterable<TransactionItem> items,
  ) {
    var missing = 0;
    var selected = 0;
    for (final item in items) {
      if (item.categoryId == null || item.categoryId!.trim().isEmpty) {
        missing++;
      } else {
        selected++;
      }
    }
    return ClassificationReviewOverview(
      needsCategory: missing,
      hasCategoryToReview: selected,
    );
  }
}

/// Never display a green/complete state after a failed review query.
String pendingClassificationTooltip({
  required bool loading,
  required bool unavailable,
  required int pendingCount,
}) {
  if (loading) return 'consultando pendências';
  if (unavailable) return 'pendências indisponíveis • tentar novamente';
  if (pendingCount > 0) return 'conferir $pendingCount lançamentos pendentes';
  return 'nenhuma classificação pendente';
}
