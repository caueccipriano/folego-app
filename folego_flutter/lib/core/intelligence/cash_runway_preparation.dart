import '../../data/models/upcoming_financial_event.dart';
import '../../data/models/wallet_overview.dart';
import 'cash_runway.dart';

/// Adapter for the official wallet and financial agenda.
class CashRunwayPreparation {
  const CashRunwayPreparation({
    required this.runway,
    required this.nextIncomeDate,
    required this.excludedOverdueCount,
    required this.openingBalance,
    this.agendaMayBeTruncated = false,
  });
  final CashRunway? runway;
  final DateTime? nextIncomeDate;
  final int excludedOverdueCount;
  final double openingBalance;
  final bool agendaMayBeTruncated;
  bool get guidanceNeedsReview => excludedOverdueCount > 0 || agendaMayBeTruncated;

  static CashRunwayPreparation fromOfficialData({
    required WalletOverview wallet,
    required List<UpcomingFinancialEvent> agenda,
    required DateTime asOf,
    double protectedReserve = 0,
    bool agendaMayBeTruncated = false,
  }) {
    final today = DateTime(asOf.year, asOf.month, asOf.day);
    final available = wallet.accounts
        .where((account) => account.isCashAccount && account.availableForSpending)
        .fold<double>(0, (sum, account) => sum + account.balance);
    // Deduplicate first so repeated agenda records cannot inflate warnings.
    final uniqueEvents = <String, UpcomingFinancialEvent>{};
    for (final event in agenda) {
      uniqueEvents.putIfAbsent(event.eventKey, () => event);
    }
    final distinctAgenda = uniqueEvents.values;
    final incomes = distinctAgenda.where((event) =>
      event.isIncome && !event.realized && !event.overdue &&
      !event.dueDate.isBefore(today) && event.amount > 0).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final nextIncome = incomes.isEmpty ? null : incomes.first.dueDate;
    final excludedOverdue = distinctAgenda.where((event) =>
      event.overdue && !event.realized && event.isOutflow &&
      event.cashObligation).length;
    if (nextIncome == null) {
      return CashRunwayPreparation(
        runway: null, nextIncomeDate: null,
        excludedOverdueCount: excludedOverdue, openingBalance: available,
        agendaMayBeTruncated: agendaMayBeTruncated,
      );
    }
    final events = distinctAgenda.where((event) =>
      !event.realized && !event.overdue &&
      event.dueDate.isBefore(nextIncome) &&
      !event.dueDate.isBefore(today) &&
      (event.isIncome || (event.isOutflow && event.cashObligation)))
      .map((event) => DatedCashEvent(
        date: event.dueDate,
        amount: event.isIncome ? event.amount : -event.amount,
        label: event.title,
      )).toList();
    return CashRunwayPreparation(
      runway: CashRunway.calculate(
        asOf: today, nextPayday: nextIncome,
        verifiedOpeningBalance: available,
        confirmedEvents: events,
        protectedReserve: protectedReserve,
      ),
      nextIncomeDate: nextIncome,
      excludedOverdueCount: excludedOverdue,
      openingBalance: available,
      agendaMayBeTruncated: agendaMayBeTruncated,
    );
  }
}
