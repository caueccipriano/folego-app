/// A read-only comparison between calendar progress and budget already used.
/// It is NOT a prediction, spending allowance, or a financial warning.
class BudgetPaceContext {
  const BudgetPaceContext({
    required this.elapsedDays,
    required this.daysInMonth,
    required this.plannedAmount,
    required this.usedAmount,
  });

  final int elapsedDays;
  final int daysInMonth;
  final double plannedAmount;
  final double usedAmount;

  int get elapsedPercent => (100 * elapsedDays / daysInMonth).round();
  int get usedPercent => (100 * usedAmount / plannedAmount).round();
}

/// Only compute for the current calendar month with a valid positive budget.
/// Never invent future actuals or extend the comparison to past/future months.
BudgetPaceContext? currentMonthBudgetPace({
  required DateTime periodMonth,
  required DateTime today,
  required double plannedAmount,
  required double usedAmount,
}) {
  if (periodMonth.year != today.year || periodMonth.month != today.month ||
      !plannedAmount.isFinite || plannedAmount <= 0 ||
      !usedAmount.isFinite) {
    return null;
  }

  final daysInMonth = DateTime(today.year, today.month + 1, 0).day;
  return BudgetPaceContext(
    elapsedDays: today.day.clamp(1, daysInMonth),
    daysInMonth: daysInMonth,
    plannedAmount: plannedAmount,
    usedAmount: usedAmount < 0 ? 0 : usedAmount,
  );
}
