class BudgetItem {
  const BudgetItem({
    required this.categoryId,
    required this.categoryPath,
    required this.plannedAmount,
    required this.warningThreshold,
    required this.criticalThreshold,
  });

  final String categoryId;
  final String categoryPath;
  final num plannedAmount;
  final num warningThreshold;
  final num criticalThreshold;
}
