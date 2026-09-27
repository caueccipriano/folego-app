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



class RepeatedExpense {
  const RepeatedExpense({
    required this.description,
    required this.category,
    required this.occurrences,
    required this.total,
  });
  final String description;
  final String category;
  final int occurrences;
  final double total;
}

/// Finds repeated purchases in the current month; never assumes that a
/// repeated purchase is a subscription or will recur in the future.
class SpendingDetector {
  static List<RepeatedExpense> currentMonth({
    required List<TransactionItem> transactions,
    required DateTime asOf,
  }) {
    final start = DateTime(asOf.year, asOf.month);
    final grouped = <String, List<TransactionItem>>{};
    for (final item in transactions) {
      if (item.status == 'ignored' || item.status == 'cancelled' ||
          !const {'expense', 'card_purchase', 'benefit_expense'}
              .contains(item.eventType) ||
          item.occurredAt.isBefore(start) || item.occurredAt.isAfter(asOf)) {
        continue;
      }
      final description = item.description.trim();
      if (description.isEmpty) continue;
      final key = '${item.categoryId ?? item.categoryName ?? ''}|${description.toLowerCase()}';
      grouped.putIfAbsent(key, () => []).add(item);
    }
    final repeated = <RepeatedExpense>[];
    for (final items in grouped.values) {
      if (items.length < 2) continue;
      final first = items.first;
      repeated.add(RepeatedExpense(
        description: first.description.trim(),
        category: first.categoryName?.trim() ?? '',
        occurrences: items.length,
        total: items.fold<double>(0, (sum, item) => sum + item.amount.abs()),
      ));
    }
    repeated.sort((a, b) => b.total.compareTo(a.total));
    return repeated;
  }
}

class CurrentProgressReport {
  const CurrentProgressReport({
    required this.weekIncome,
    required this.weekExpenses,
    required this.previousWeekExpenses,
    required this.monthExpenses,
    required this.previousMonthExpenses,
    required this.previousWeekComparable,
    required this.previousMonthComparable,
    required this.categoryChanges,
  });
  final double weekIncome;
  final double weekExpenses;
  final double previousWeekExpenses;
  final double monthExpenses;
  final double previousMonthExpenses;
  final bool previousWeekComparable;
  final bool previousMonthComparable;
  final List<CategoryChange> categoryChanges;
}

class CategoryChange {
  const CategoryChange(this.name, this.current, this.previous);
  final String name;
  final double current;
  final double previous;
  double get difference => current - previous;
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


  /// Compara períodos equivalentes: segunda até agora vs. mesmos dias
  /// da semana anterior; mês até hoje vs. mesmo número de dias anterior.
  static CurrentProgressReport currentProgress({
    required List<TransactionItem> transactions,
    required DateTime asOf,
  }) {
    final today = DateTime(asOf.year, asOf.month, asOf.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final previousWeekStart = weekStart.subtract(const Duration(days: 7));
    final previousWeekCutoff = asOf.subtract(const Duration(days: 7));
    final monthStart = DateTime(today.year, today.month);
    final previousMonthStart = DateTime(today.year, today.month - 1);
    final elapsedDays = today.difference(monthStart).inDays;
    final previousMonthLastDay = DateTime(today.year, today.month, 0).day;
    final comparableMonthDays = elapsedDays + 1 <= previousMonthLastDay;
    final previousMonthCutoff = comparableMonthDays
        ? DateTime(previousMonthStart.year, previousMonthStart.month,
            today.day, asOf.hour, asOf.minute, asOf.second)
        : DateTime(today.year, today.month).subtract(const Duration(microseconds: 1));
    var weekIncome = 0.0;
    var weekExpenses = 0.0;
    var previousWeekExpenses = 0.0;
    var monthExpenses = 0.0;
    var previousMonthExpenses = 0.0;
    final currentCategories = <String, double>{};
    final previousCategories = <String, double>{};
    for (final item in transactions) {
      if (item.status == 'ignored' || item.status == 'cancelled') continue;
      final date = item.occurredAt;
      if (date.isAfter(asOf)) continue;
      final thisWeek = !date.isBefore(weekStart);
      final lastWeek = !date.isBefore(previousWeekStart) &&
          date.isBefore(weekStart) && !date.isAfter(previousWeekCutoff);
      if (item.isIncome) {
        if (thisWeek) weekIncome += item.amount.abs();
        continue;
      }
      if (!_economicExpenseTypes.contains(item.eventType)) continue;
      final amount = item.amount.abs();
      final category = item.categoryName?.trim().isNotEmpty == true
          ? item.categoryName!.trim() : 'Sem categoria';
      if (thisWeek) {
        weekExpenses += amount;
        currentCategories.update(category, (v) => v + amount,
            ifAbsent: () => amount);
      }
      if (lastWeek) {
        previousWeekExpenses += amount;
        previousCategories.update(category, (v) => v + amount,
            ifAbsent: () => amount);
      }
      if (!date.isBefore(monthStart)) monthExpenses += amount;
      if (!date.isBefore(previousMonthStart) && date.isBefore(monthStart) &&
          !date.isAfter(previousMonthCutoff)) {
        previousMonthExpenses += amount;
      }
    }
    final changes = <CategoryChange>[
      for (final name in {...currentCategories.keys, ...previousCategories.keys})
        CategoryChange(name, currentCategories[name] ?? 0,
            previousCategories[name] ?? 0),
    ]..sort((a, b) => b.difference.compareTo(a.difference));
    return CurrentProgressReport(
      weekIncome: weekIncome, weekExpenses: weekExpenses,
      previousWeekExpenses: previousWeekExpenses,
      monthExpenses: monthExpenses,
      previousMonthExpenses: previousMonthExpenses,
      previousWeekComparable: true,
      previousMonthComparable: comparableMonthDays,
      categoryChanges: changes,
    );
  }

  static const _economicExpenseTypes = {
    'expense',
    'card_purchase',
    'benefit_expense',
  };
}
