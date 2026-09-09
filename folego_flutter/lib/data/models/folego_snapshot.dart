class FolegoSnapshot {
  const FolegoSnapshot({
    required this.asOfDate,
    required this.nextIncomeDate,
    required this.nextIncomeAmount,
    required this.daysUntilIncome,
    required this.liquidBalance,
    required this.protectedBalance,
    required this.mandatoryOutflowsUntilIncome,
    required this.cashHeadroom,
    required this.monthlyBudgetPlanned,
    required this.monthlyBudgetUsed,
    required this.economicHeadroom,
    required this.spendablePool,
    required this.dailyFolego,
    required this.shortfall,
    required this.limitingFactor,
    required this.status,
    required this.budgetConfigured,
    required this.needsIncomeSetup,
  });

  final DateTime asOfDate;
  final DateTime? nextIncomeDate;
  final num nextIncomeAmount;
  final int? daysUntilIncome;
  final num liquidBalance;
  final num protectedBalance;
  final num mandatoryOutflowsUntilIncome;
  final num cashHeadroom;
  final num monthlyBudgetPlanned;
  final num monthlyBudgetUsed;
  final num economicHeadroom;
  final num spendablePool;
  final num? dailyFolego;
  final num shortfall;
  final String limitingFactor;
  final String status;
  final bool budgetConfigured;
  final bool needsIncomeSetup;

  factory FolegoSnapshot.fromJson(Map<String, dynamic> json) {
    return FolegoSnapshot(
      asOfDate: DateTime.parse(json['as_of_date'] as String),
      nextIncomeDate: json['next_income_date'] == null
          ? null
          : DateTime.parse(json['next_income_date'] as String),
      nextIncomeAmount: json['next_income_amount'] as num? ?? 0,
      daysUntilIncome: (json['days_until_income'] as num?)?.toInt(),
      liquidBalance: json['liquid_balance'] as num? ?? 0,
      protectedBalance: json['protected_balance'] as num? ?? 0,
      mandatoryOutflowsUntilIncome:
          json['mandatory_outflows_until_income'] as num? ?? 0,
      cashHeadroom: json['cash_headroom'] as num? ?? 0,
      monthlyBudgetPlanned: json['monthly_budget_planned'] as num? ?? 0,
      monthlyBudgetUsed: json['monthly_budget_used'] as num? ?? 0,
      economicHeadroom: json['economic_headroom'] as num? ?? 0,
      spendablePool: json['spendable_pool'] as num? ?? 0,
      dailyFolego: json['daily_folego'] as num?,
      shortfall: json['shortfall'] as num? ?? 0,
      limitingFactor: json['limiting_factor'] as String? ?? 'cash',
      status: json['status'] as String? ?? 'atencao',
      budgetConfigured: json['budget_configured'] as bool? ?? false,
      needsIncomeSetup: json['needs_income_setup'] as bool? ?? false,
    );
  }
}
