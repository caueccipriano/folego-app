import 'wallet_overview.dart';

/// Read-only insights: do not alter balances, budget or forecast.
class WalletUpcomingInvoiceSummary {
  const WalletUpcomingInvoiceSummary({
    required this.count,
    required this.total,
    required this.overdueCount,
  });

  final int count;
  final double total;
  final int overdueCount;
}

WalletUpcomingInvoiceSummary summarizeDueCardInvoices(
  Iterable<WalletCard> cards,
  DateTime today, {
  int horizonDays = 30,
}) {
  final start = DateTime.utc(today.year, today.month, today.day);
  final end = start.add(Duration(days: horizonDays));
  var total = 0.0;
  var count = 0;
  var overdue = 0;
  for (final card in cards) {
    final due = card.invoiceDueDate;
    if (due == null || card.invoiceBalance <= 0 || !card.canPayInvoice) {
      continue;
    }
    final day = DateTime.utc(due.year, due.month, due.day);
    if (day.isBefore(start)) {
      overdue++;
    } else if (!day.isAfter(end)) {
      count++;
      total += card.invoiceBalance;
    }
  }
  return WalletUpcomingInvoiceSummary(
    count: count, total: total, overdueCount: overdue,
  );
}

class WalletEndingInstallmentsSummary {
  const WalletEndingInstallmentsSummary({
    required this.count,
    required this.lastInstallmentTotal,
  });

  final int count;
  final double lastInstallmentTotal;
}

/// Only installments with known last due dates in the calendar month qualify.
/// The sum is NOT newly available cash or card limit.
WalletEndingInstallmentsSummary summarizeEndingInstallments(
  Iterable<WalletInstallment> installments,
  DateTime month,
) {
  var count = 0;
  var total = 0.0;
  for (final item in installments) {
    final due = item.nextDueDate;
    final amount = item.installmentAmount;
    if (item.remainingInstallments != 1 || due == null ||
        amount == null || amount <= 0 ||
        due.year != month.year || due.month != month.month) {
      continue;
    }
    count++;
    total += amount;
  }
  return WalletEndingInstallmentsSummary(
    count: count, lastInstallmentTotal: total,
  );
}
