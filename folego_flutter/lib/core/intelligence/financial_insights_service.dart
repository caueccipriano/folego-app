import '../../data/repositories/folego_repository.dart';
import 'financial_report_builder.dart';
import 'weekly_report_builder.dart';

/// Camada de integração: mantém os cálculos desacoplados do Supabase e da UI.
/// Não usa dados fictícios nem envia transações a serviços de IA.
class FinancialInsightsService {
  const FinancialInsightsService(this.repository);
  final FolegoRepository repository;

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
