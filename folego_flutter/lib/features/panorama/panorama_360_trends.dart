import '../../data/models/monthly_money_summary.dart';

/// Canonical monthly economic totals, never raw cash movement sums.
class PanoramaMonthPoint {
  const PanoramaMonthPoint({
    required this.periodMonth,
    required this.summary,
  });

  final DateTime periodMonth;
  final MonthlyMoneySummary? summary;

  bool get available => summary != null;
  double? get income => summary?.realIncome;
  double? get expenses => summary?.competenceExpenses;
  double? get economicResult => summary?.economicResult;

  String get monthLabel {
    const months = <String>[
      'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
      'jul', 'ago', 'set', 'out', 'nov', 'dez',
    ];
    return '${months[periodMonth.month - 1]}/${periodMonth.year}';
  }
}

/// Three consecutive months (oldest first). Missing/failed RPC calls remain
/// unknown; zero appears only if that month's canonical backend really
/// returned zero. Ratios from a zero baseline are intentionally unavailable.
class Panorama360Trend {
  Panorama360Trend({
    required DateTime currentMonth,
    required MonthlyMoneySummary? current,
    required List<MonthlyMoneySummary?>? previous,
  }) : months = List<PanoramaMonthPoint>.unmodifiable([
         PanoramaMonthPoint(
           periodMonth: DateTime(currentMonth.year, currentMonth.month - 2),
           summary: _match(
             previous != null && previous.length > 1 ? previous[1] : null,
             DateTime(currentMonth.year, currentMonth.month - 2),
           ),
         ),
         PanoramaMonthPoint(
           periodMonth: DateTime(currentMonth.year, currentMonth.month - 1),
           summary: _match(
             previous != null && previous.isNotEmpty ? previous[0] : null,
             DateTime(currentMonth.year, currentMonth.month - 1),
           ),
         ),
         PanoramaMonthPoint(
           periodMonth: DateTime(currentMonth.year, currentMonth.month),
           summary: _match(
             current,
             DateTime(currentMonth.year, currentMonth.month),
           ),
         ),
       ]);

  final List<PanoramaMonthPoint> months;

  static MonthlyMoneySummary? _match(
    MonthlyMoneySummary? summary,
    DateTime periodMonth,
  ) {
    if (summary == null ||
        summary.periodMonth.year != periodMonth.year ||
        summary.periodMonth.month != periodMonth.month) {
      return null;
    }
    return summary;
  }

  bool get hasAnyVerifiedMonth => months.any((month) => month.available);
  bool get complete => months.every((month) => month.available);
  int get verifiedCount => months.where((month) => month.available).length;

  /// Current month versus immediately previous month, only if BOTH exist.
  /// A monthly decrease in expense is not proof of improved cash liquidity.
  double? get expenseChange {
    final current = months[2].expenses;
    final previous = months[1].expenses;
    if (current == null || previous == null) return null;
    return current - previous;
  }

  double? get resultChange {
    final current = months[2].economicResult;
    final previous = months[1].economicResult;
    if (current == null || previous == null) return null;
    return current - previous;
  }
}
