import 'spending_behavior.dart';

/// A calendar-month comparison of REGISTERED income and recorded purchases.
///
/// These are expense occurrences, not booked future obligations, available
/// account balances, card limits, or a forecast of affordable purchases.
class RegisteredSpendingMargin {
  const RegisteredSpendingMargin({
    required this.registeredIncome,
    required this.expenses,
  }) : assert(registeredIncome >= 0);

  final double registeredIncome;
  final SpendingBehaviorSummary expenses;

  /// A reference before variable/unclassified purchases are considered.
  double get afterClassifiedFixed => registeredIncome - expenses.fixed;

  /// Only the economic difference of recorded income and all recorded spending.
  /// Never label this a spendable bank balance or available card limit.
  double get afterAllRecordedSpending =>
      registeredIncome - expenses.total;

  bool get hasUnknownExpenses => expenses.unclassifiedCount > 0;
  bool get hasIncome => registeredIncome > 0;

  /// Share of recorded income associated with expenses tagged as fixed.
  double? get fixedShareOfIncome => !hasIncome
      ? null
      : expenses.fixed / registeredIncome;
}

/// Rejects malformed/unreliable amounts rather than quietly showing zero.
RegisteredSpendingMargin buildRegisteredSpendingMargin({
  required double registeredIncome,
  required SpendingBehaviorSummary expenses,
}) {
  if (!registeredIncome.isFinite || registeredIncome < 0) {
    throw const FormatException('Invalid registered income');
  }
  return RegisteredSpendingMargin(
    registeredIncome: registeredIncome,
    expenses: expenses,
  );
}
