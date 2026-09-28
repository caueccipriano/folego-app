/// Transparent, deterministic spending pace; not a balance or cash forecast.
class BudgetPace {
  const BudgetPace({
    required this.used,
    required this.limit,
    required this.elapsedDays,
    required this.daysInMonth,
  });

  final double used;
  final double limit;
  final int elapsedDays;
  final int daysInMonth;

  double get remaining => limit - used;
  double get dailyAverage => elapsedDays > 0 ? used / elapsedDays : 0;
  double get projectedMonthSpending => dailyAverage * daysInMonth;
  double get projectedDifference => projectedMonthSpending - limit;
  bool get projectedOverLimit => limit > 0 && projectedDifference > 0;
  bool get hasEnoughHistory => elapsedDays >= 7;
  bool get canEstimate => limit > 0 && hasEnoughHistory && used >= 0;

  static BudgetPace forDate({
    required double used,
    required double limit,
    required DateTime asOf,
  }) => BudgetPace(
    used: used,
    limit: limit,
    elapsedDays: asOf.day,
    daysInMonth: DateTime(asOf.year, asOf.month + 1, 0).day,
  );
}
