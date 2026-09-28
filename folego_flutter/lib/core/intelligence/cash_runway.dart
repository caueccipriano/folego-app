/// Day-level cash runway built only from explicitly dated cash events.
/// Callers must exclude credit-card purchases already represented by a bill
/// and internal transfers to avoid counting the same money twice.
class DatedCashEvent {
  const DatedCashEvent({
    required this.date,
    required this.amount,
    required this.label,
  });
  final DateTime date;
  final double amount; // positive = incoming, negative = outgoing
  final String label;
}

class CashRunwayDay {
  const CashRunwayDay({required this.date, required this.closingBalance,
    required this.events});
  final DateTime date;
  final double closingBalance;
  final List<DatedCashEvent> events;
}

class CashRunway {
  const CashRunway({required this.days, required this.firstNegativeDay,
    required this.balanceAtPayday, required this.discretionaryDailyReference});
  final List<CashRunwayDay> days;
  final DateTime? firstNegativeDay;
  final double balanceAtPayday;
  final double discretionaryDailyReference;

  static CashRunway calculate({
    required DateTime asOf,
    required DateTime nextPayday,
    required double verifiedOpeningBalance,
    required List<DatedCashEvent> confirmedEvents,
    double protectedReserve = 0,
  }) {
    if (!verifiedOpeningBalance.isFinite || !protectedReserve.isFinite ||
        protectedReserve < 0) {
      throw ArgumentError('Invalid verified balance or reserve');
    }
    final start = DateTime(asOf.year, asOf.month, asOf.day);
    final end = DateTime(nextPayday.year, nextPayday.month, nextPayday.day);
    if (end.isBefore(start) || end.difference(start).inDays > 62) {
      throw ArgumentError('Next payday must be within the next 62 days');
    }
    final events = confirmedEvents.where((event) {
      if (!event.amount.isFinite) {
        throw ArgumentError('Invalid cash event amount');
      }
      final day = DateTime(event.date.year, event.date.month, event.date.day);
      // The opening balance already includes all transactions before today.
      return !day.isBefore(start) && day.isBefore(end);
    }).toList();
    final days = <CashRunwayDay>[];
    var balance = verifiedOpeningBalance;
    DateTime? firstNegative;
    for (var date = start; date.isBefore(end);
        date = DateTime(date.year, date.month, date.day + 1)) {
      final todayEvents = events.where((event) =>
        event.date.year == date.year &&
        event.date.month == date.month &&
        event.date.day == date.day).toList();
      for (final event in todayEvents) {
        balance += event.amount;
      }
      if (balance < 0) firstNegative ??= date;
      days.add(CashRunwayDay(date: date, closingBalance: balance,
        events: List.unmodifiable(todayEvents)));
    }
    final available = balance - protectedReserve;
    return CashRunway(
      days: List.unmodifiable(days),
      firstNegativeDay: firstNegative,
      balanceAtPayday: balance,
      discretionaryDailyReference: days.isNotEmpty && available > 0
          ? available / days.length : 0,
    );
  }
}
