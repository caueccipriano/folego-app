import '../../data/repositories/folego_repository.dart';
import '../../data/repositories/folego_repository_budget.dart';
import '../../data/repositories/folego_repository_agenda.dart';
import 'cash_runway_preparation.dart';
import '../../data/models/budget_overview_item.dart';
import 'financial_report_builder.dart';
import 'financial_radar.dart';
import 'weekly_report_builder.dart';

/// Camada de integração: mantém os cálculos desacoplados do Supabase e da UI.
/// Não usa dados fictícios nem envia transações a serviços de IA.
class FinancialInsightsService {
  const FinancialInsightsService(this.repository);
  final FolegoRepository repository;

  Future<CashRunwayPreparation> cashRunway({
    required String spaceId,
    required DateTime asOf,
  }) async {
    final wallet = await repository.getWalletOverview(spaceId: spaceId);
    final agenda = await repository.getFinancialAgenda(
      spaceId, startDate: DateTime(asOf.year, asOf.month, asOf.day - 30),
      endDate: DateTime(asOf.year, asOf.month, asOf.day + 62),
      limit: 200,
    );
    return CashRunwayPreparation.fromOfficialData(
      wallet: wallet, agenda: agenda, asOf: asOf,
      agendaMayBeTruncated: agenda.length >= 200,
    );
  }

  Future<FinancialRadar> radar({
    required String spaceId,
    int horizonMonths = 3,
  }) async {
    final projection = await repository.getProjection(
      spaceId: spaceId, horizonMonths: horizonMonths,
    );
    return FinancialRadar.fromProjection(projection);
  }

  Future<MonthlyIntelligenceReport> monthly({
    required String spaceId,
    required DateTime month,
  }) async {
    final currentMonth = DateTime(month.year, month.month);
    final previousMonth = DateTime(month.year, month.month - 1);
    final current = await repository.getMonthlyMoneySummary(
      spaceId: spaceId,
      periodMonth: currentMonth,
    );
    // Se o mês anterior falhar, não escondemos o erro nem inventamos variação.
    final previous = await repository.getMonthlyMoneySummary(
      spaceId: spaceId,
      periodMonth: previousMonth,
    );
    return FinancialReportBuilder.monthly(
      current: current,
      previous: previous,
    );
  }

  Future<List<RepeatedExpense>> repeatedPurchases({
    required String spaceId,
    required DateTime asOf,
  }) async {
    final transactions = await repository.getTransactions(spaceId);
    return SpendingDetector.currentMonth(transactions: transactions, asOf: asOf);
  }

  Future<FlexibleBudgetOverview> flexibleBudget({
    required String spaceId,
    required DateTime asOf,
  }) => repository.getFlexibleBudgetOverview(
    spaceId: spaceId,
    periodMonth: DateTime(asOf.year, asOf.month),
  );

  Future<CurrentProgressReport> currentProgress({
    required String spaceId,
    required DateTime asOf,
  }) async {
    final transactions = await repository.getTransactions(spaceId);
    return WeeklyReportBuilder.currentProgress(transactions: transactions, asOf: asOf);
  }

  Future<WeeklyFinanceReport> weekly({
    required String spaceId,
    required DateTime weekStart,
    required DateTime asOf,
  }) async {
    final transactions = await repository.getTransactions(spaceId);
    return WeeklyReportBuilder.build(
      transactions: transactions,
      weekStart: weekStart,
      asOf: asOf,
    );
  }
}
