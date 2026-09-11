class BudgetOverviewItem {
  const BudgetOverviewItem({
    required this.categoryId,
    required this.categoryName,
    required this.essential,
    required this.plannedAmount,
    required this.actualAmount,
    required this.remainingAmount,
    required this.warningThreshold,
    required this.criticalThreshold,
    required this.usageRatio,
    required this.status,
    this.colorHex,
  });

  final String categoryId;
  final String categoryName;
  final String? colorHex;
  final bool essential;

  final double plannedAmount;
  final double actualAmount;
  final double remainingAmount;

  final double warningThreshold;
  final double criticalThreshold;
  final double usageRatio;

  final String status;

  bool get hasBudget => plannedAmount > 0;

  bool get hasActivity => actualAmount > 0;

  bool get isOverBudget => plannedAmount > 0 && actualAmount > plannedAmount;

  double get progress {
    if (plannedAmount <= 0) {
      return 0;
    }

    return usageRatio.clamp(0.0, 1.0);
  }

  factory BudgetOverviewItem.fromJson(Map<String, dynamic> json) {
    return BudgetOverviewItem(
      categoryId: json['category_id'] as String,
      categoryName: json['category_name'] as String,
      colorHex: json['color_hex'] as String?,
      essential: json['essential'] as bool? ?? false,
      plannedAmount: _asDouble(json['planned_amount']),
      actualAmount: _asDouble(json['actual_amount']),
      remainingAmount: _asDouble(json['remaining_amount']),
      warningThreshold: _asDouble(json['warning_threshold']),
      criticalThreshold: _asDouble(json['critical_threshold']),
      usageRatio: _asDouble(json['usage_ratio']),
      status: json['status'] as String? ?? 'none',
    );
  }

  static double _asDouble(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0;
  }
}
