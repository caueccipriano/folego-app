import '../../data/models/monthly_money_summary.dart';

/// Compares TWO COMPLETE calendar months only. Comparing the current
/// incomplete month against a completed month would suggest false trends.
/// Values are the canonical economic income/competence expenses: card invoice
/// payments, internal transfers and contributions are NOT counted twice.
class PanoramaClosedMonthTrend {
  const PanoramaClosedMonthTrend._({
    required this.earlier,
    required this.later,
  });

  final MonthlyMoneySummary earlier;
  final MonthlyMoneySummary later;

  static PanoramaClosedMonthTrend? tryFrom({
    required MonthlyMoneySummary? earlier,
    required MonthlyMoneySummary? later,
    required DateTime referenceDate,
  }) {
    if (earlier == null || later == null) return null;
    // Both periods must be exactly the last two completed months relative
    // to the selected clock; guard against stale/misrouted server responses.
    final expectedLater = DateTime(referenceDate.year, referenceDate.month - 1);
    final expectedEarlier =
        DateTime(referenceDate.year, referenceDate.month - 2);
    if (!_sameMonth(later.periodMonth, expectedLater) ||
        !_sameMonth(earlier.periodMonth, expectedEarlier)) {
      return null;
    }
    return PanoramaClosedMonthTrend._(earlier: earlier, later: later);
  }

  double get earlierIncome => earlier.realIncome;
  double get laterIncome => later.realIncome;

  double get earlierExpenses => earlier.competenceExpenses;
  double get laterExpenses => later.competenceExpenses;

  double get earlierResult => earlier.economicResult;
  double get laterResult => later.economicResult;

  /// A positive expense delta means more expenses were REGISTERED in the
  /// later closed month. It is not an inferred overspending verdict.
  double get expenseChange => laterExpenses - earlierExpenses;
  double get incomeChange => laterIncome - earlierIncome;
  double get economicResultChange => laterResult - earlierResult;

  bool get bothMonthsWithoutRecordedMovements =>
      earlierIncome == 0 &&
      laterIncome == 0 &&
      earlierExpenses == 0 &&
      laterExpenses == 0;

  static bool _sameMonth(DateTime left, DateTime right) =>
      left.year == right.year && left.month == right.month;
}
