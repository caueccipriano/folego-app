import '../../data/models/upcoming_financial_event.dart';

/// Calendar dates and totals come exclusively from confirmed agenda items.
/// This is not a projection of bank balance or guaranteed future income.
abstract final class AgendaCalendarMonth {
  static DateTime normalized(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime firstDay(DateTime month) =>
      DateTime(month.year, month.month, 1);

  static DateTime lastDay(DateTime month) =>
      DateTime(month.year, month.month + 1, 0);

  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static List<DateTime?> cells(DateTime month) {
    final first = firstDay(month);
    final leading = first.weekday - 1; // Monday-first layout.
    final length = lastDay(month).day;
    final count = ((leading + length + 6) ~/ 7) * 7;
    return List<DateTime?>.generate(count, (index) {
      final day = index - leading + 1;
      return day < 1 || day > length
          ? null : DateTime(first.year, first.month, day);
    });
  }

  static List<UpcomingFinancialEvent> eventsForDay(
    Iterable<UpcomingFinancialEvent> source,
    DateTime day, {
    AgendaFilter filter = AgendaFilter.all,
  }) => source
      .where((event) =>
          sameDay(event.dueDate, day) && event.matches(filter))
      .toList(growable: false);

  static double incomeForDay(Iterable<UpcomingFinancialEvent> events) =>
      events.where((e) => e.isIncome)
          .fold(0, (double sum, e) => sum + e.amount);

  /// Avoid showing informational events as a cash obligation.
  static double outflowForDay(Iterable<UpcomingFinancialEvent> events) =>
      events.where((e) => e.isOutflow && e.cashObligation)
          .fold(0, (double sum, e) => sum + e.amount);
}
