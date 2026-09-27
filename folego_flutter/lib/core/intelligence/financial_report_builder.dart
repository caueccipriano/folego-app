import '../../data/models/monthly_money_summary.dart';

/// Resumo explicável: usa os números oficiais do app, sem inventar insights.
class PeriodInsight {
  const PeriodInsight({required this.title, required this.description});
  final String title;
  final String description;
}

class MonthlyIntelligenceReport {
  const MonthlyIntelligenceReport({
    required this.income,
    required this.expenses,
    required this.result,
    required this.insights,
  });
  final double income;
  final double expenses;
  final double result;
  final List<PeriodInsight> insights;
}

class FinancialReportBuilder {
  static MonthlyIntelligenceReport monthly({
    required MonthlyMoneySummary current,
    MonthlyMoneySummary? previous,
  }) {
    // Competência econômica evita contar pagamento da fatura duas vezes.
    final income = current.realIncome;
    final expenses = current.competenceExpenses;
    final result = current.economicResult;
    final insights = <PeriodInsight>[];
    if (result < 0) {
      insights.add(PeriodInsight(
        title: 'Atenção ao resultado',
        description: 'As despesas do mês superaram as receitas em R\$ ${(-result).toStringAsFixed(2)}.',
      ));
    } else {
      insights.add(PeriodInsight(
        title: 'Resultado do mês',
        description: 'As receitas superaram ou igualaram as despesas em R\$ ${result.toStringAsFixed(2)}.',
      ));
    }
    if (previous != null && previous.competenceExpenses > 0) {
      final change = (expenses - previous.competenceExpenses) /
          previous.competenceExpenses * 100;
      if (change.abs() >= 5) {
        insights.add(PeriodInsight(
          title: 'Mudança nas despesas',
          description: 'As despesas por competência ${change > 0 ? 'aumentaram' : 'diminuíram'} ${change.abs().toStringAsFixed(1)}% em relação ao mês anterior.',
        ));
      }
    }
    return MonthlyIntelligenceReport(
      income: income,
      expenses: expenses,
      result: result,
      insights: List.unmodifiable(insights),
    );
  }
}
