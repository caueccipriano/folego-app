class ProjectionCategory {
  const ProjectionCategory({required this.name, required this.amount});

  final String name;
  final double amount;

  factory ProjectionCategory.fromJson(Map<String, dynamic> json) {
    return ProjectionCategory(
      name: (json['name'] as String? ?? 'Planejamento').trim(),
      amount: _projectionNumber(json['amount']),
    );
  }
}

class ProjectionVariableIncome {
  const ProjectionVariableIncome({
    required this.key,
    required this.name,
    required this.amount,
    required this.enabled,
  });

  final String key;
  final String name;
  final double amount;
  final bool enabled;

  factory ProjectionVariableIncome.fromJson(Map<String, dynamic> json) {
    return ProjectionVariableIncome(
      key: json['key'] as String,
      name: json['name'] as String,
      amount: _projectionNumber(json['amount']),
      enabled: json['enabled'] as bool? ?? true,
    );
  }
}

class ProjectionMonth {
  const ProjectionMonth({
    required this.month,
    required this.openingBalance,
    required this.guaranteedIncome,
    required this.variableIncome,
    required this.income,
    required this.directExpenses,
    required this.recurringExpenses,
    required this.cardInstallments,
    required this.debts,
    required this.reserveTransfers,
    required this.investments,
    required this.otherInflows,
    required this.otherOutflows,
    required this.plannedMovements,
    required this.benefitExpenses,
    required this.netChange,
    required this.closingBalance,
    required this.closingProjected,
    required this.categories,
    this.realizedToDate,
    this.stillExpected,
  });

  final DateTime month;
  final double openingBalance;
  final double guaranteedIncome;
  final double variableIncome;
  final double income;
  final double directExpenses;
  final double recurringExpenses;
  final double cardInstallments;
  final double debts;
  final double reserveTransfers;
  final double investments;
  final double otherInflows;
  final double otherOutflows;
  final double plannedMovements;
  final double benefitExpenses;
  final double netChange;
  final double closingBalance;
  final double closingProjected;
  final double? realizedToDate;
  final double? stillExpected;
  final List<ProjectionCategory> categories;

  bool get isCritical => closingBalance < 0;

  factory ProjectionMonth.fromJson(Map<String, dynamic> json) {
    final rawCategories = json['categories'];
    final categories = rawCategories is List
        ? rawCategories
              .whereType<Map>()
              .map(
                (item) => ProjectionCategory.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
        : const <ProjectionCategory>[];

    return ProjectionMonth(
      month: DateTime.parse(json['month'] as String),
      openingBalance: _projectionNumber(json['opening_balance']),
      guaranteedIncome: _projectionNumber(json['guaranteed_income']),
      variableIncome: _projectionNumber(json['variable_income']),
      income: _projectionNumber(json['income']),
      directExpenses: _projectionNumber(json['direct_expenses']),
      recurringExpenses: _projectionNumber(json['recurring_expenses']),
      cardInstallments: _projectionNumber(json['card_installments']),
      debts: _projectionNumber(json['debts']),
      reserveTransfers: _projectionNumber(json['reserve_transfers']),
      investments: _projectionNumber(json['investments']),
      otherInflows: _projectionNumber(json['other_inflows']),
      otherOutflows: _projectionNumber(json['other_outflows']),
      plannedMovements: _projectionNumber(json['planned_movements']),
      benefitExpenses: _projectionNumber(json['benefit_expenses']),
      netChange: _projectionNumber(json['net_change']),
      closingBalance: _projectionNumber(json['closing_balance']),
      closingProjected: _projectionNumber(json['closing_projected']),
      realizedToDate: _projectionNullableNumber(json['realized_to_date']),
      stillExpected: _projectionNullableNumber(json['still_expected']),
      categories: categories,
    );
  }
}

class ProjectionSummary {
  const ProjectionSummary({
    required this.endingBalance,
    required this.minimumBalance,
    required this.maximumBalance,
    required this.projectedSavings,
    this.criticalMonth,
  });

  final double endingBalance;
  final double minimumBalance;
  final double maximumBalance;
  final double projectedSavings;
  final DateTime? criticalMonth;

  factory ProjectionSummary.fromJson(Map<String, dynamic> json) {
    return ProjectionSummary(
      endingBalance: _projectionNumber(json['ending_balance']),
      minimumBalance: _projectionNumber(json['minimum_balance']),
      maximumBalance: _projectionNumber(json['maximum_balance']),
      projectedSavings: _projectionNumber(json['projected_savings']),
      criticalMonth: json['critical_month'] == null
          ? null
          : DateTime.tryParse(json['critical_month'].toString()),
    );
  }
}

class ProjectionResult {
  const ProjectionResult({
    required this.scenario,
    required this.horizonMonths,
    required this.asOfDate,
    required this.openingBalance,
    required this.hasProjectionInputs,
    required this.summary,
    required this.months,
    required this.variableIncomes,
  });

  final String scenario;
  final int horizonMonths;
  final DateTime asOfDate;
  final double openingBalance;
  final bool hasProjectionInputs;
  final ProjectionSummary summary;
  final List<ProjectionMonth> months;
  final List<ProjectionVariableIncome> variableIncomes;

  factory ProjectionResult.fromJson(Map<String, dynamic> json) {
    final rawSummary = Map<String, dynamic>.from(
      (json['summary'] as Map?) ?? const {},
    );
    final rawMonths = json['months'];
    final rawVariable = json['variable_incomes'];

    return ProjectionResult(
      scenario: json['scenario'] as String? ?? 'current',
      horizonMonths: (json['horizon_months'] as num? ?? 12).toInt(),
      asOfDate: DateTime.parse(json['as_of_date'] as String),
      openingBalance: _projectionNumber(json['opening_balance']),
      hasProjectionInputs: json['has_projection_inputs'] as bool? ?? false,
      summary: ProjectionSummary.fromJson(rawSummary),
      months: rawMonths is List
          ? rawMonths
                .whereType<Map>()
                .map(
                  (item) => ProjectionMonth.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList(growable: false)
          : const <ProjectionMonth>[],
      variableIncomes: rawVariable is List
          ? rawVariable
                .whereType<Map>()
                .map(
                  (item) => ProjectionVariableIncome.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList(growable: false)
          : const <ProjectionVariableIncome>[],
    );
  }
}

class ProjectionAdjustment {
  const ProjectionAdjustment({
    required this.id,
    required this.name,
    required this.component,
    required this.amountDelta,
    required this.frequency,
    required this.startsOn,
    this.endsOn,
    this.categoryName,
    this.categoryId,
    this.variableIncome = false,
    this.source = 'simulation',
  });

  final String id;
  final String name;
  final String component;
  final double amountDelta;
  final String frequency;
  final DateTime startsOn;
  final DateTime? endsOn;
  final String? categoryName;
  final String? categoryId;
  final bool variableIncome;
  final String source;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'component': component,
    'amount_delta': amountDelta,
    'frequency': frequency,
    'starts_on': _projectionDate(startsOn),
    'ends_on': endsOn == null ? null : _projectionDate(endsOn!),
    'category_name': categoryName,
    'category_id': categoryId,
    'variable_income': variableIncome,
    'source': source,
  };
}

double _projectionNumber(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

double? _projectionNullableNumber(dynamic value) {
  if (value == null) return null;
  return _projectionNumber(value);
}

String _projectionDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}
