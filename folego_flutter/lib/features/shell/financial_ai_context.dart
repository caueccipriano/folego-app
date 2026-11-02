/// A narrow, read-only snapshot for the financial AI endpoint.
/// Do not attach card names, event descriptions, account IDs or transactions.
Map<String, Object> financialAiMonthlyContext({
  required DateTime month,
  required num income,
  required num competenceExpenses,
}) {
  if (!income.isFinite || !competenceExpenses.isFinite ||
      income < 0 || competenceExpenses < 0) {
    throw const FormatException('Resumo financeiro indisponível');
  }
  final result = income - competenceExpenses;
  if (!result.isFinite) {
    throw const FormatException('Resumo financeiro indisponível');
  }
  return {
    'month': '${month.year}-${month.month.toString().padLeft(2, '0')}',
    'income': income,
    'expenses': competenceExpenses,
    'result': result,
  };
}
