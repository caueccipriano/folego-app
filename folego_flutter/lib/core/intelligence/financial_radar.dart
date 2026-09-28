import '../../data/models/projection_model.dart';

/// Explainable month-level radar based on the official projection engine.
/// Monthly totals cannot establish a specific day of negative balance.
class FinancialRadar {
  const FinancialRadar({
    required this.months,
    required this.firstNegativeMonth,
    required this.lowestClosingBalance,
    required this.hasReliableInputs,
  });
  final List<ProjectionMonth> months;
  final DateTime? firstNegativeMonth;
  final double? lowestClosingBalance;
  final bool hasReliableInputs;

  static FinancialRadar fromProjection(ProjectionResult projection) {
    if (!projection.hasProjectionInputs || projection.months.isEmpty) {
      return const FinancialRadar(
        months: [], firstNegativeMonth: null,
        lowestClosingBalance: null, hasReliableInputs: false,
      );
    }
    final months = projection.months.toList()
      ..sort((a, b) => a.month.compareTo(b.month));
    DateTime? firstNegativeMonth;
    double? lowest;
    for (final month in months) {
      if (lowest == null || month.closingProjected < lowest) {
        lowest = month.closingProjected;
      }
      firstNegativeMonth ??= month.closingProjected < 0 ? month.month : null;
    }
    return FinancialRadar(
      months: List.unmodifiable(months),
      firstNegativeMonth: firstNegativeMonth,
      lowestClosingBalance: lowest,
      hasReliableInputs: true,
    );
  }
}
