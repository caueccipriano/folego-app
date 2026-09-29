import 'package:intl/intl.dart';
import '../data/models/monthly_money_summary.dart';
import 'local_monthly_summary.dart';

/// Answer a supported monthly-total question locally. This is deterministic
/// product logic, NOT AI. No provider request, token billing or question quota.
/// The caller must fetch the summary for the CURRENT authorized space only.
String buildLocalMonthlyAnswer(
  MonthlyMoneySummary summary,
  String question,
) {
  final q = _plain(question.trim().toLowerCase());
  final money = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');
  final income = summary.realIncome;
  final expenses = summary.competenceExpenses;
  final result = summary.economicResult;

  if (income.abs() < .005 && expenses.abs() < .005) {
    return 'Não há receitas ou despesas registradas neste mês. '
        'Cadastre seus movimentos para receber uma análise automática. '
        'Isso não é uma resposta de IA.';
  }

  if (_has(q, ['saldo', 'disponivel', 'posso gastar', 'proximo recebimento',
               'quanto tenho', 'hoje', 'semana que vem'])) {
    return 'Seus totais mensais mostram receitas de ${money.format(income)}, '
        'despesas por competência de ${money.format(expenses)} e '
        'resultado de ${money.format(result)}. '
        'Esses valores não indicam seu saldo disponível hoje: '
        'consulte o indicador Fôlego e a agenda de compromissos na Home. '
        'Não use este resumo para autorizar uma compra.';
  }

  if (_has(q, ['cartao', 'fatura', 'parcelamento'])) {
    return 'Compras feitas no cartão neste mês: '
        '${money.format(summary.cardPurchasesMade)}. '
        'Despesas de cartão atribuídas à competência deste mês: '
        '${money.format(summary.cardCompetence)}. '
        'Pagamentos de fatura registrados como movimentação de caixa: '
        '${money.format(summary.cardPayments)}. '
        'O pagamento da fatura não é contado novamente como despesa.';
  }

  if (_has(q, ['transferencia', 'investimento', 'aplicacao'])) {
    return 'Transferências registradas como movimentação de caixa: '
        '${money.format(summary.movementTransfers)}. '
        'Movimentações de reserva/investimento: '
        '${money.format(summary.movementReserveInvestment)}. '
        'Essas movimentações não são somadas às despesas econômicas '
        'do mês. Confira cada registro antes de tomar decisões.';
  }

  if (_has(q, ['melhor', 'economiz', 'reduz', 'orcamento', 'planej'])) {
    if (result < -.005) {
      return 'Neste mês, as despesas por competência ultrapassam as '
          'receitas registradas em ${money.format(-result)}. '
          'Confira suas categorias e despesas flexíveis para identificar '
          'o que pode ser revisto. Sem o detalhamento das categorias, '
          'não consigo apontar um gasto específico. '
          'Isto é uma análise automática por regras, sem IA.';
    }
    return 'Seu resultado mensal registrado é ${money.format(result)}. '
        'Confira as categorias, os próximos vencimentos e o orçamento '
        'flexível antes de decidir quanto reservar ou gastar. '
        'Esta análise não considera transações ainda não cadastradas.';
  }

  if (_has(q, ['receita', 'salario', 'renda', 'ganhei', 'entrou'])) {
    return 'Receitas reais registradas neste mês: '
        '${money.format(income)}. '
        'O total não detalha a origem de cada recebimento. '
        'Consulte os lançamentos para conferir os valores individuais.';
  }

  if (_has(q, ['despesa', 'gasto', 'gastei', 'compras', 'saida'])) {
    return 'Despesas por competência neste mês: '
        '${money.format(expenses)}. '
        'Gastos registrados pela data da compra/movimento: '
        '${money.format(summary.spendingMade)}. '
        'Reembolsos registrados: ${money.format(summary.refunds)}. '
        'As bases são diferentes, então os totais podem divergir; '
        'pagamentos de fatura não são somados duas vezes.';
  }

  if (_has(q, ['mes', 'situacao', 'resultado', 'balanco', 'lucro', 'prejuizo',
               'como estou'])) {
    return buildLocalMonthlySummary(summary);
  }

  return 'Consigo explicar seu resultado mensal, receitas, despesas, '
      'cartões, transferências e possíveis pontos de revisão usando '
      'apenas totais registrados. Sua pergunta requer mais contexto '
      'ou raciocínio aberto. Para isso, copie o resumo e converse '
      'manualmente no seu ChatGPT. Não enviei seus dados para nenhuma IA.';
}

String buildChatGptMonthlyPrompt(
  MonthlyMoneySummary summary,
  String question,
) {
  final money = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');
  return 'Estou consultando meu resumo financeiro no aplicativo Fôlego. '
      'Considere SOMENTE estes totais agregados do período '
      '${summary.periodMonth.month.toString().padLeft(2, '0')}/'
      '${summary.periodMonth.year}:\n'
      'Receitas reais: ${money.format(summary.realIncome)}\n'
      'Despesas por competência: ${money.format(summary.competenceExpenses)}\n'
      'Resultado: ${money.format(summary.economicResult)}\n'
      'Compras de cartão registradas: '
      '${money.format(summary.cardPurchasesMade)}\n'
      'Pagamentos de fatura (apenas fluxo de caixa): '
      '${money.format(summary.cardPayments)}\n'
      'Pergunta: ${question.trim()}\n'
      'Não invente categorias, transações, saldo disponível nem '
      'movimentos futuros. Se faltarem dados, diga quais. '
      'Isto foi copiado manualmente: nenhum dado foi enviado '
      'automaticamente pelo Fôlego.';
}

String _plain(String input) => input
    .replaceAll(RegExp('[áàâãä]'), 'a')
    .replaceAll(RegExp('[éèêë]'), 'e')
    .replaceAll(RegExp('[íìîï]'), 'i')
    .replaceAll(RegExp('[óòôõö]'), 'o')
    .replaceAll(RegExp('[úùûü]'), 'u')
    .replaceAll('ç', 'c');

bool _has(String text, List<String> terms) =>
    terms.any((term) => text.contains(term));
