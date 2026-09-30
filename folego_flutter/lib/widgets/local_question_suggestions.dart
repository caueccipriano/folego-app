/// Shortcuts for the deterministic, privacy-first local totals analysis.
//// No suggestion claims to inspect individual transactions or future cash flow.
class LocalMonthlyQuestion {
  const LocalMonthlyQuestion(this.id, this.label, this.question);
  final String id;
  final String label;
  final String question;
}

const localMonthlySuggestions = <LocalMonthlyQuestion>[
  LocalMonthlyQuestion(
    'month', 'Como está meu mês?',
    'Como está minha situação financeira neste mês?',
  ),
  LocalMonthlyQuestion(
    'budget', 'Onde posso melhorar?',
    'O que posso melhorar no orçamento com os totais disponíveis?',
  ),
  LocalMonthlyQuestion(
    'card', 'Cartão e fatura',
    'Qual é a diferença entre compras no cartão e pagamentos de fatura?',
  ),
  LocalMonthlyQuestion(
    'income', 'Receitas e despesas',
    'Quanto registrei de receitas e despesas neste mês?',
  ),
  LocalMonthlyQuestion(
    'transfers', 'Transferências',
    'Como são tratadas minhas transferências e aplicações?',
  ),
  LocalMonthlyQuestion(
    'balance', 'Saldo disponível?',
    'Quanto tenho disponível hoje? Estes totais são suficientes para saber?',
  ),
];
