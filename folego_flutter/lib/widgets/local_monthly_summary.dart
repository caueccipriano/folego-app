import 'package:intl/intl.dart';

import '../data/models/monthly_money_summary.dart';

/// A transparent, deterministic fallback. This is NOT a language-model answer
/// and never pretends to answer the user's free-form question.
String buildLocalMonthlySummary(MonthlyMoneySummary summary) {
  final money = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');
  final income = summary.realIncome;
  final expenses = summary.competenceExpenses;
  final result = summary.economicResult;
  if (income.abs() < .005 && expenses.abs() < .005) {
    return 'Não há receitas ou despesas registradas neste mês para gerar '
        'um resumo. Confira seus lançamentos.';
  }
  final status = result < -.005
      ? 'As despesas registradas superam as receitas neste mês.'
      : result > .005
          ? 'As receitas registradas superam as despesas neste mês.'
          : 'As receitas e despesas registradas estão equilibradas.';
  return 'Receitas reais: ${money.format(income)}\n'
      'Despesas por competência: ${money.format(expenses)}\n'
      'Resultado do mês: ${money.format(result)}\n\n'
      '$status\n'
      'Este é um resumo automático dos números do Fôlego, não uma '
      'resposta da IA. Não inclui movimentos ainda não cadastrados.';
}
