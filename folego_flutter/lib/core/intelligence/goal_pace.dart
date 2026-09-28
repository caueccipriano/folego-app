import '../../data/models/financial_goal.dart';

/// A transparent target-date calculation, never an automatic contribution.
class GoalPace {
  const GoalPace({required this.remaining, required this.monthsRemaining,
    required this.monthlyContribution});
  final double remaining;
  final int monthsRemaining;
  final double monthlyContribution;

  static GoalPace? forGoal(FinancialGoal goal, DateTime asOf) {
    if (!goal.isActive || goal.targetDate == null || goal.target <= 0) return null;
    final remaining = goal.remaining.toDouble();
    if (remaining <= 0) return null;
    final deadline = goal.targetDate!;
    final today = DateTime(asOf.year, asOf.month, asOf.day);
    if (deadline.isBefore(today)) return null;
    // Include current month, and avoid counting the deadline month if its
    // target day has already passed relative to the current calendar day.
    final months = (deadline.year - today.year) * 12 +
        deadline.month - today.month + 1;
    if (months <= 0) return null;
    return GoalPace(
      remaining: remaining,
      monthsRemaining: months,
      monthlyContribution: remaining / months,
    );
  }
}
