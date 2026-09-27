/// Motor determinístico para simulações e análises do Fôlego.
/// Não envia dados pessoais para serviços externos.
class FinanceEntry {
  const FinanceEntry({required this.date, required this.amount, required this.category});
  final DateTime date;
  /// Receitas positivas e despesas negativas, em reais.
  final double amount;
  final String category;
}

class PurchaseImpact {
  const PurchaseImpact({required this.monthlyBalances, required this.lowestBalance, required this.firstNegativeMonth});
  final List<double> monthlyBalances;
  final double lowestBalance;
  /// Índice 0-based; null quando não há saldo negativo.
  final int? firstNegativeMonth;
}

class SpendingPattern {
  const SpendingPattern(this.category, this.previous, this.current);
  final String category;
  final double previous;
  final double current;
  double get variationPercent => previous == 0 ? 0 : (current - previous) / previous * 100;
}

class FinancialIntelligence {
  /// Considera saldo disponível, movimentos previstos e compra parcelada.
  /// Movimentos de entrada e saída devem estar previstos UMA única vez.
  static PurchaseImpact simulatePurchase({
    required double openingBalance,
    required DateTime startMonth,
    required List<FinanceEntry> projectedEntries,
    required double purchaseAmount,
    int installments = 1,
    int months = 12,
  }) {
    if (!openingBalance.isFinite || !purchaseAmount.isFinite ||
        purchaseAmount < 0 || installments < 1 || months < 1) {
      throw ArgumentError('Parâmetros financeiros inválidos');
    }
    final monthlyPayment = purchaseAmount / installments;
    var balance = openingBalance;
    final balances = <double>[];
    int? firstNegative;
    for (var i = 0; i < months; i++) {
      final month = DateTime(startMonth.year, startMonth.month + i);
      final next = DateTime(month.year, month.month + 1);
      for (final entry in projectedEntries) {
        if (!entry.amount.isFinite) throw ArgumentError('Lançamento inválido');
        if (!entry.date.isBefore(month) && entry.date.isBefore(next)) {
          balance += entry.amount;
        }
      }
      if (i < installments) balance -= monthlyPayment;
      balances.add(balance);
      if (balance < 0 && firstNegative == null) firstNegative = i;
    }
    return PurchaseImpact(
      monthlyBalances: List.unmodifiable(balances),
      lowestBalance: balances.reduce((a, b) => a < b ? a : b),
      firstNegativeMonth: firstNegative,
    );
  }

  /// Compara gastos efetivos por categoria em dois períodos fechados.
  /// Valores negativos representam despesas. Não inclui receitas.
  static List<SpendingPattern> compareExpenses({
    required List<FinanceEntry> entries,
    required DateTime previousStart,
    required DateTime currentStart,
    required DateTime currentEnd,
  }) {
    if (!previousStart.isBefore(currentStart) || !currentStart.isBefore(currentEnd)) {
      throw ArgumentError('Períodos inválidos');
    }
    final previous = <String, double>{};
    final current = <String, double>{};
    for (final entry in entries) {
      if (entry.amount >= 0) continue;
      if (!entry.date.isBefore(previousStart) && entry.date.isBefore(currentStart)) {
        previous.update(entry.category, (v) => v - entry.amount, ifAbsent: () => -entry.amount);
      } else if (!entry.date.isBefore(currentStart) && entry.date.isBefore(currentEnd)) {
        current.update(entry.category, (v) => v - entry.amount, ifAbsent: () => -entry.amount);
      }
    }
    final categories = {...previous.keys, ...current.keys}.toList()..sort();
    return categories.map((name) => SpendingPattern(name, previous[name] ?? 0, current[name] ?? 0)).toList();
  }
}
