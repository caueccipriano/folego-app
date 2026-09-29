import '../../data/models/budget_overview_item.dart';
import '../../data/models/financial_goal.dart';
import '../../data/models/folego_snapshot.dart';
import '../../data/models/monthly_money_summary.dart';
import '../../data/models/upcoming_events.dart';
import '../../data/repositories/folego_repository.dart';
import '../../data/repositories/folego_repository_goals.dart';
import 'panorama_month_trend.dart';

/// Every nullable field means "not verified / could not load", NOT a
/// financial zero. An empty list means the scoped query succeeded but had
/// nothing to display. All amounts come from existing canonical RPCs.
class Panorama360Data {
  const Panorama360Data({
    this.snapshot,
    this.monthlyMoney,
    this.budgets,
    this.goals,
    this.upcoming,
    this.closedEarlier,
    this.closedLater,
    this.referenceDate,
  });

  final FolegoSnapshot? snapshot;
  final MonthlyMoneySummary? monthlyMoney;
  final List<BudgetOverviewItem>? budgets;
  final List<FinancialGoal>? goals;
  final List<UpcomingEvent>? upcoming;

  /// Independent optional queries for the last TWO completed months.
  /// If either request fails, the comparison is unknown (never zero).
  final MonthlyMoneySummary? closedEarlier;
  final MonthlyMoneySummary? closedLater;
  final DateTime? referenceDate;

  PanoramaClosedMonthTrend? get closedMonthTrend => referenceDate == null
      ? null
      : PanoramaClosedMonthTrend.tryFrom(
          earlier: closedEarlier,
          later: closedLater,
          referenceDate: referenceDate!,
        );

  bool get hasAnyData =>
      snapshot != null ||
      monthlyMoney != null ||
      budgets != null ||
      goals != null ||
      upcoming != null ||
      closedMonthTrend != null;

  /// Sum parent categories only. Children are already included within
  /// their parent aggregation: adding them again would double consumption.
  BudgetMonthSummary? get budgetSummary =>
      budgets == null ? null : BudgetMonthSummary.fromItems(budgets!);

  List<FinancialGoal>? get activeGoals => goals
      ?.where((goal) => goal.status == GoalStatus.active)
      .toList(growable: false);

  /// The upcoming preview must NOT be subtracted from spendablePool: the
  /// server snapshot may have already reserved precisely these bills.
  List<UpcomingEvent>? pendingOutflows({DateTime? now}) {
    if (upcoming == null) return null;
    final reference = now ?? DateTime.now();
    final today = DateTime(reference.year, reference.month, reference.day);
    final result = upcoming!
        .where((item) =>
            item.isPending &&
            item.isExpense &&
            !DateTime(item.dueDate.year, item.dueDate.month, item.dueDate.day)
                .isBefore(today))
        .toList(growable: false)
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return result;
  }

  bool get needsSetup =>
      (snapshot?.needsIncomeSetup ?? false) ||
      (snapshot?.budgetConfigured == false);
}

typedef Panorama360Loader = Future<Panorama360Data> Function(String spaceId);

/// Read-only orchestrator. An error in one RPC never turns it into a
/// fabricated zero, and never prevents independently available sections.
class Panorama360DataLoader {
  Panorama360DataLoader(this.repository, {this.now});

  final FolegoRepository repository;
  final DateTime? now;

  Future<T?> _optional<T>(Future<T> Function() fetch) async {
    try {
      return await fetch();
    } catch (_) {
      // Avoid printing user/space identifiers or financial payloads.
      return null;
    }
  }

  Future<Panorama360Data> load(String spaceId) async {
    if (spaceId.trim().isEmpty) {
      throw ArgumentError('É necessário um espaço financeiro válido.');
    }
    final month = now ?? DateTime.now();
    final earlierClosedMonth = DateTime(month.year, month.month - 2);
    final laterClosedMonth = DateTime(month.year, month.month - 1);
    final data = await Future.wait<dynamic>([
      _optional(() => repository.getSnapshot(spaceId)),
      _optional(() => repository.getMonthlyMoneySummary(
            spaceId: spaceId,
            periodMonth: month,
          )),
      _optional(() => repository.getBudgetOverview(
            spaceId: spaceId,
            periodMonth: month,
          )),
      _optional(() => repository.listGoals(spaceId)),
      _optional(() => repository.getUpcomingEvents(spaceId, days: 30)),
      _optional(() => repository.getMonthlyMoneySummary(
            spaceId: spaceId,
            periodMonth: earlierClosedMonth,
          )),
      _optional(() => repository.getMonthlyMoneySummary(
            spaceId: spaceId,
            periodMonth: laterClosedMonth,
          )),
    ]);
    final rawGoals = data[3] as List<FinancialGoal>?;
    // Belt-and-braces client-side scope check; actual authorization is RLS.
    // Never display a malformed cross-space goal even if backend regresses.
    final scopedGoals = rawGoals
        ?.where((goal) => goal.spaceId == spaceId)
        .toList(growable: false);
    return Panorama360Data(
      snapshot: data[0] as FolegoSnapshot?,
      monthlyMoney: data[1] as MonthlyMoneySummary?,
      budgets: data[2] as List<BudgetOverviewItem>?,
      goals: scopedGoals,
      upcoming: data[4] as List<UpcomingEvent>?,
      closedEarlier: data[5] as MonthlyMoneySummary?,
      closedLater: data[6] as MonthlyMoneySummary?,
      referenceDate: month,
    );
  }
}
