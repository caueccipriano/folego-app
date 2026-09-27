import '../../data/models/transaction_item.dart';
import 'financial_intelligence.dart';

class WeeklyFinanceReport {
  const WeeklyFinanceReport({
    required this.start,
    required this.endExclusive,
    required this.income,
    required this.expenses,
    required this.patterns,
    required this.comparedWithPreviousWeek,
  });
  final DateTime start;
  final DateTime endExclusive;
  final double income;
  final double expenses;
  final List<SpendingPattern> patterns;
  final bool comparedWithPreviousWeek;
  double get result => income - expenses;
}

/// Relatório semanal baseado em movimentações econômicas, sem contar
/// transferências e pagamentos de faturas como novas despesas.
class WeeklyReportBuilder {
  static WeeklyFinanceReport build({
    required List<TransactionItem> transactions,
    required DateTime weekStart,
    required DateTime asOf,
  }) {
    final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final end = start.add(const Duration(days: 7));
    final previousStart = start.subtract(const Duration(days: 7));
    if (asOf.isBefore(end)) {
      // Comparar uma semana incompleta com uma semana inteira distorce tendências.
      return _build(transactions, start, end, previousStart, false, asOf);
    }
    return _build(transactions, start, end, previousStart, true, asOf);
  }

  static WeeklyFinanceReport _build(
    List<TransactionItem> transactions,
    DateTime start,
    DateTime end,
    DateTime previousStart,
    bool compare,
    DateTime asOf,
  ) {
    var income = 0.0;
    var expenses = 0.0;
    final entries = <FinanceEntry>[];
    for (final item in transactions) {
      if (item.status == 'ignored' || item.status == 'cancelled') continue;
      final date = item.occurredAt;
      if (date.isBefore(previousStart) || !date.isBefore(end) || date.isAfter(asOf)) continue;
      if (item.isIncome) {
        if (!date.isBefore(start)) income += item.amount.abs();
      } else if (_economicExpenseTypes.contains(item.eventType)) {
        final amount = item.amount.abs();
        entries.add(FinanceEntry(
          date: date,
          amount: -amount,
          category: item.categoryName?.trim().isNotEmpty == true
              ? item.categoryName!.trim()
              : 'Sem categoria',
        ));
        if (!date.isBefore(start)) expenses += amount;
      }
    }
    return WeeklyFinanceReport(
      start: start,
      endExclusive: end,
      income: income,
      expenses: expenses,
      comparedWithPreviousWeek: compare,
      patterns: compare
          ? FinancialIntelligence.compareExpenses(
              entries: entries,
              previousStart: previousStart,
              currentStart: start,
              currentEnd: end,
            )
          : const [],
    );
  }

  static const _economicExpenseTypes = {
    'expense',
    'card_purchase',
    'benefit_expense',
  };
}
