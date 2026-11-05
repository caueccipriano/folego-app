import '../../data/models/budget_overview_item.dart';
import '../../data/models/monthly_money_summary.dart';

/// Months are always closed: no comparison with a partially completed month.
List<DateTime> recentClosedMonths(DateTime today, {int count = 6}) {
  if (count < 1 || count > 24) {
    throw RangeError.range(count, 1, 24, 'count');
  }
  return List<DateTime>.generate(
    count,
    (index) => DateTime(today.year, today.month - count + index, 1),
    growable: false,
  );
}

String analyticsMonthLabel(DateTime month) {
  const labels = [
    'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
    'jul', 'ago', 'set', 'out', 'nov', 'dez',
  ];
  return '${labels[month.month - 1]}/${month.year.toString().substring(2)}';
}

/// The bank's movement totals, purchase-date spending, and budget competence
/// are deliberately never mixed. Each getter retains the backend's definition.
class FinancialAnalyticsSeries {
  const FinancialAnalyticsSeries(this.months);

  final List<MonthlyMoneySummary> months;

  double get maximumActivity {
    var maximum = 0.0;
    for (final month in months) {
      if (month.realIncome > maximum) maximum = month.realIncome;
      if (month.spendingMade > maximum) maximum = month.spendingMade;
    }
    return maximum;
  }

  double get totalIncome => months.fold<double>(
    0, (sum, month) => sum + month.realIncome,
  );

  double get totalSpending => months.fold<double>(
    0, (sum, month) => sum + month.spendingMade,
  );

  /// Uses competence-based expenses, unlike spendingMade.
  double get totalEconomicResult => months.fold<double>(
    0, (sum, month) => sum + month.economicResult,
  );

  double? spendingChange(MonthlyMoneySummary selected) {
    final index = months.indexWhere((month) =>
      month.periodMonth.year == selected.periodMonth.year &&
      month.periodMonth.month == selected.periodMonth.month);
    if (index <= 0) return null;
    final previous = months[index - 1].spendingMade;
    return selected.spendingMade - previous;
  }

  /// Parents already include subcategories. Child rows must never be summed
  /// again, otherwise the category share and budget are doubled.
  static List<BudgetOverviewItem> parentCategories(
      Iterable<BudgetOverviewItem> items) {
    final result = items
        .where((item) => item.isParent && item.actualAmount > 0)
        .toList(growable: false);
    result.sort((a, b) => b.actualAmount.compareTo(a.actualAmount));
    return result;
  }

  static double parentTotal(Iterable<BudgetOverviewItem> items) =>
      parentCategories(items).fold<double>(
        0, (sum, item) => sum + item.actualAmount,
      );
}
