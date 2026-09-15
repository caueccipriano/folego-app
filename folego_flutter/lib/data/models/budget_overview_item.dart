enum BudgetLimitScope {
  month,
  fromMonth,
  cancelFromMonth,
}

extension BudgetLimitScopeRpc on BudgetLimitScope {
  String get rpcValue {
    switch (this) {
      case BudgetLimitScope.month:
        return 'month';
      case BudgetLimitScope.fromMonth:
        return 'from_month';
      case BudgetLimitScope.cancelFromMonth:
        return 'cancel_from_month';
    }
  }
}

enum BudgetProgressState {
  noLimit,
  comfortable,
  attention,
  exceeded,
}

class BudgetMonthSummary {
  const BudgetMonthSummary({
    required this.plannedAmount,
    required this.actualAmount,
  });

  final double plannedAmount;
  final double actualAmount;

  double get remainingAmount => plannedAmount - actualAmount;

  double get usageRatio => plannedAmount > 0 ? actualAmount / plannedAmount : 0;

  BudgetProgressState get progressState {
    if (plannedAmount <= 0) return BudgetProgressState.noLimit;
    if (usageRatio > 1) return BudgetProgressState.exceeded;
    if (usageRatio >= .70) return BudgetProgressState.attention;
    return BudgetProgressState.comfortable;
  }

  factory BudgetMonthSummary.fromItems(List<BudgetOverviewItem> items) {
    final parents = items.where((item) => item.isParent);
    return BudgetMonthSummary(
      plannedAmount: parents.fold<double>(
        0.0,
        (total, item) => total + item.plannedAmount,
      ),
      actualAmount: parents.fold<double>(
        0.0,
        (total, item) => total + item.actualAmount,
      ),
    );
  }
}

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
    this.parentId,
    this.parentName,
    this.budgetSource = 'none',
    this.isRecurring = false,
  });

  final String categoryId;
  final String categoryName;

  /// Null = categoria principal.
  /// Preenchido = subcategoria.
  final String? parentId;

  /// Nome da categoria principal quando este item for subcategoria.
  final String? parentName;

  final String? colorHex;
  final bool essential;

  final double plannedAmount;
  final double actualAmount;
  final double remainingAmount;

  final double warningThreshold;
  final double criticalThreshold;
  final double usageRatio;

  final String status;

  /// Fonte efetiva do limite devolvida pelo backend.
  ///
  /// `month`: limite pontual; `recurring`: regra mensal; `override`: ajuste
  /// apenas deste mês sobre uma regra recorrente; `aggregate`: parent.
  final String budgetSource;
  final bool isRecurring;

  bool get isParent => parentId == null;

  bool get isSubcategory => parentId != null;

  bool get hasBudget => plannedAmount > 0;

  bool get hasActivity => actualAmount > 0;

  bool get isOverBudget => hasBudget && actualAmount > plannedAmount;

  bool get isMonthlyOverride => budgetSource == 'override';

  String get recurringLabel {
    if (!isRecurring) return '';
    return isMonthlyOverride ? 'todo mês · ajuste do mês' : 'todo mês';
  }

  BudgetProgressState get progressState {
    if (!hasBudget) return BudgetProgressState.noLimit;
    if (usageRatio > 1 || status == 'exceeded') {
      return BudgetProgressState.exceeded;
    }
    if (usageRatio >= .70 || status == 'warning') {
      return BudgetProgressState.attention;
    }
    return BudgetProgressState.comfortable;
  }

  double get progress {
    if (!hasBudget) return 0;
    return usageRatio.clamp(0.0, 1.0);
  }

  factory BudgetOverviewItem.fromJson(Map<String, dynamic> json) {
    return BudgetOverviewItem(
      categoryId: json['category_id'] as String,
      categoryName: json['category_name'] as String,
      parentId: json['parent_id'] as String?,
      parentName: json['parent_name'] as String?,
      colorHex: json['color_hex'] as String?,
      essential: json['essential'] as bool? ?? false,
      plannedAmount: _asDouble(json['planned_amount']),
      actualAmount: _asDouble(json['actual_amount']),
      remainingAmount: _asDouble(json['remaining_amount']),
      warningThreshold: _asDouble(json['warning_threshold']),
      criticalThreshold: _asDouble(json['critical_threshold']),
      usageRatio: _asDouble(json['usage_ratio']),
      status: json['status'] as String? ?? 'none',
      budgetSource: json['budget_source'] as String? ?? 'none',
      isRecurring: json['is_recurring'] as bool? ?? false,
    );
  }

  static double _asDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}
