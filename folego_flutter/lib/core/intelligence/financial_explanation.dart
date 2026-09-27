import 'financial_report_builder.dart';
import 'weekly_report_builder.dart';

/// Explicações financeiras locais e verificáveis. Não envia dados a modelos
/// externos nem promete recomendações financeiras personalizadas.
class FinancialExplanation {
  const FinancialExplanation._();

  static String monthly(MonthlyIntelligenceReport report) {
    final result = report.result;
    if (!result.isFinite) return 'Resumo indisponível: revise os lançamentos.';
    final direction = result < 0 ? 'negativo' : 'não negativo';
    return 'Seu resultado econômico do mês foi ${direction}. '
        'Receitas: ${report.income.toStringAsFixed(2)} reais; '
        'despesas: ${report.expenses.toStringAsFixed(2)} reais. '
        'Confira os lançamentos antes de tomar decisões.';
  }

  static String weekly(WeeklyFinanceReport report) {
    return 'Na semana selecionada, foram registrados '
        '${report.income.toStringAsFixed(2)} reais de receitas e '
        '${report.expenses.toStringAsFixed(2)} reais de despesas.'
        '${report.comparedWithPreviousWeek ? ' A comparação utiliza duas semanas completas.' : ' A comparação foi omitida porque a semana ainda não terminou.'}';
  }
}
