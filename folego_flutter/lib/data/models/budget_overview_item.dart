/// One confirmed economic posting contributing to the month's Plan.
/// A card purchase from a previous month may have an installment in this one.
/// A read-only snapshot of what the Plan knows about money and anomalies.
class PlanInsights {
  const PlanInsights({
    required this.economicSpending,
    required this.debtPayments,
    required this.budgetTracked,
    required this.cashOutflows,
    required this.cashInflows,
    required this.estimatedAvailableNow,
    required this.issues,
    required this.suggestions,
  });

  final double economicSpending;
  final double debtPayments;
  final double budgetTracked;
  final double cashOutflows;
  final double cashInflows;
  /// Estimated using recorded transactions, NOT directly verified by a bank.
  final double estimatedAvailableNow;
  final List<PlanIssue> issues;
  final List<PlanSuggestion> suggestions;

  factory PlanInsights.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> array(String key) =>
        (json[key] as List<dynamic>? ?? const [])
            .map((v) => Map<String, dynamic>.from(v as Map))
            .toList();
    return PlanInsights(
      economicSpending: _budgetDouble(json['economic_spending']),
      debtPayments: _budgetDouble(json['debt_payments']),
      budgetTracked: _budgetDouble(json['budget_tracked']),
      cashOutflows: _budgetDouble(json['cash_outflows']),
      cashInflows: _budgetDouble(json['cash_inflows']),
      estimatedAvailableNow: _budgetDouble(json['estimated_available_now']),
      issues: array('issues').map(PlanIssue.fromJson).toList(),
      suggestions: array('suggestions').map(PlanSuggestion.fromJson).toList(),
    );
  }
}

class PlanIssue {
  const PlanIssue({
    required this.code,
    required this.title,
    required this.description,
    required this.count,
    required this.amount,
  });

  final String code;
  final String title;
  final String description;
  final int count;
  final double amount;

  factory PlanIssue.fromJson(Map<String, dynamic> json) => PlanIssue(
    code: json['code'] as String? ?? '',
    title: json['title'] as String? ?? 'Revisar lançamento',
    description: json['description'] as String? ?? '',
    count: (json['count'] as num?)?.toInt() ?? 0,
    amount: _budgetDouble(json['amount']),
  );
}

class PlanSuggestion {
  const PlanSuggestion({
    required this.categoryId,
    required this.categoryName,
    required this.historicalAverage,
    required this.suggestedLimit,
    required this.sampleMonths,
  });

  final String categoryId;
  final String categoryName;
  final double historicalAverage;
  final double suggestedLimit;
  final int sampleMonths;

  factory PlanSuggestion.fromJson(Map<String, dynamic> json) => PlanSuggestion(
    categoryId: json['category_id'] as String? ?? '',
    categoryName: json['category_name'] as String? ?? '',
    historicalAverage: _budgetDouble(json['historical_average']),
    suggestedLimit: _budgetDouble(json['suggested_limit']),
    sampleMonths: (json['sample_months'] as num?)?.toInt() ?? 0,
  );
}

class BudgetImpactDetail {
  const BudgetImpactDetail({
    required this.impactId,
    required this.description,
    required this.categoryName,
    required this.eventType,
    required this.effectiveDate,
    required this.budgetAmount,
    this.purchaseDate,
    this.installmentNumber,
    this.totalInstallments,
  });

  final String impactId;
  final String description;
  final String categoryName;
  final String eventType;
  final DateTime effectiveDate;
  final DateTime? purchaseDate;
  final double budgetAmount;
  final int? installmentNumber;
  final int? totalInstallments;

  bool get comesFromEarlierMonth =>
      eventType == 'card_purchase' && purchaseDate != null &&
      (purchaseDate!.month != effectiveDate.month ||
        purchaseDate!.year != effectiveDate.year);

  factory BudgetImpactDetail.fromJson(Map<String, dynamic> json) =>
      BudgetImpactDetail(
        impactId: json['impact_id'] as String,
        description: json['description'] as String? ?? 'Lançamento',
        categoryName: json['category_name'] as String? ?? 'Sem categoria',
        eventType: json['event_type'] as String? ?? 'expense',
        effectiveDate: DateTime.parse(json['effective_date'] as String),
        purchaseDate: json['purchase_date'] == null
            ? null : DateTime.parse(json['purchase_date'] as String),
        budgetAmount: _budgetDouble(json['budget_amount']),
        installmentNumber: (json['installment_number'] as num?)?.toInt(),
        totalInstallments: (json['total_installments'] as num?)?.toInt(),
      );
}

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

class FlexibleBudgetOverview {
  const FlexibleBudgetOverview({
    required this.periodMonth,
    required this.configured,
    required this.explicitLimit,
    required this.limitAmount,
    required this.usedAmount,
    required this.remainingAmount,
    required this.exceededAmount,
    required this.categoryLimitsTotal,
  });

  final DateTime periodMonth;
  final bool configured;

  /// True when the user has set a global flexible-spending ceiling for this
  /// month. False means the backend is using the legacy category-limit sum as
  /// a backwards-compatible fallback.
  final bool explicitLimit;
  final double limitAmount;
  final double usedAmount;
  final double remainingAmount;
  final double exceededAmount;
  final double categoryLimitsTotal;

  bool get isExceeded => exceededAmount > 0;
  bool get hasRemaining => remainingAmount > 0;
  double get usageRatio => limitAmount > 0 ? usedAmount / limitAmount : 0;

  BudgetProgressState get progressState {
    if (!configured) return BudgetProgressState.noLimit;
    if (isExceeded || usageRatio > 1) return BudgetProgressState.exceeded;
    if (usageRatio >= .70) return BudgetProgressState.attention;
    return BudgetProgressState.comfortable;
  }

  factory FlexibleBudgetOverview.fromJson(Map<String, dynamic> json) {
    return FlexibleBudgetOverview(
      periodMonth: DateTime.parse(json['period_month'] as String),
      configured: json['configured'] as bool? ?? false,
      explicitLimit: json['explicit_limit'] as bool? ?? false,
      limitAmount: _budgetDouble(json['limit_amount']),
      usedAmount: _budgetDouble(json['used_amount']),
      remainingAmount: _budgetDouble(json['remaining_amount']),
      exceededAmount: _budgetDouble(json['exceeded_amount']),
      categoryLimitsTotal: _budgetDouble(json['category_limits_total']),
    );
  }
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

/// Explains why some categories exceed their limits even when the month
/// as a whole is close to budget. Only parent totals count, never children
/// again. Expenses without a limit are still real expenses.
class BudgetMonthDiagnostics {
  const BudgetMonthDiagnostics({
    required this.exceededInLimitedCategories,
    required this.remainingInLimitedCategories,
    required this.spendingWithoutLimit,
    required this.pendingClassification,
    required this.categoriesOverLimit,
  });

  final double exceededInLimitedCategories;
  final double remainingInLimitedCategories;
  final double spendingWithoutLimit;
  final double pendingClassification;
  final int categoriesOverLimit;

  /// Must reconcile to "planned minus actual" in BudgetMonthSummary.
  double get netRemaining =>
      remainingInLimitedCategories - exceededInLimitedCategories
        - spendingWithoutLimit;

  factory BudgetMonthDiagnostics.fromItems(
    Iterable<BudgetOverviewItem> items,
  ) {
    double exceeded = 0;
    double remaining = 0;
    double withoutLimit = 0;
    double pending = 0;
    int exceededCategories = 0;
    for (final item in items) {
      if (!item.isParent) continue;
      if (item.isPending) pending += item.actualAmount;
      if (!item.hasBudget) {
        withoutLimit += item.actualAmount;
      } else if (item.remainingAmount < 0) {
        exceeded -= item.remainingAmount;
        exceededCategories++;
      } else {
        remaining += item.remainingAmount;
      }
    }
    return BudgetMonthDiagnostics(
      exceededInLimitedCategories: exceeded,
      remainingInLimitedCategories: remaining,
      spendingWithoutLimit: withoutLimit,
      pendingClassification: pending,
      categoriesOverLimit: exceededCategories,
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

  /// Confirmed spending waiting for an economic category. Count it in the
  /// monthly total, but never offer a budget limit for this technical bucket.
  bool get isPending => budgetSource == 'pending';

  bool get isSubcategory => parentId != null;

  /// Direct charges recorded on a parent category without a subcategory.
  /// Child figures must not be counted twice in the family total.
  double withoutSubcategory(Iterable<BudgetOverviewItem> children) {
    final inChildren = children.fold<double>(
      0.0, (sum, child) => sum + child.actualAmount,
    );
    return (actualAmount - inChildren).clamp(0.0, double.infinity).toDouble();
  }

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

  static double _asDouble(dynamic value) => _budgetDouble(value);
}

double _budgetDouble(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}
