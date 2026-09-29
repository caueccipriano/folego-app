import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/monthly_money_summary.dart';
import 'package:folego/widgets/local_monthly_answers.dart';

MonthlyMoneySummary month({
  double income = 4000,
  double expenses = 5100,
  double cardPurchases = 1200,
  double cardCompetence = 800,
  double cardPayments = 9000,
}) => MonthlyMoneySummary.fromJson({
  'period_month': '2026-09-01',
  'income_amount': income,
  'competence_net': expenses,
  'spending_net': expenses,
  'spending_cards': cardPurchases,
  'competence_cards_total': cardCompetence,
  'movement_card_payments': cardPayments,
  'movement_transfers': 1500,
  'movement_reserve_investment': 300,
  'refunds_amount': 100,
});

void main() {
  test('unlimited local monthly interpretation uses official competence values', () {
    final answer = buildLocalMonthlyAnswer(
      month(), 'Como está minha situação financeira neste mês?');
    expect(answer, contains('4.000,00'));
    expect(answer, contains('5.100,00'));
    expect(answer, contains('1.100,00'));
    expect(answer, isNot(contains('9.000,00')));
    expect(answer, contains('não uma resposta da IA'));
  });

  test('improvement request never invents missing category breakdown', () {
    final answer = buildLocalMonthlyAnswer(month(), 'Onde posso melhorar?');
    expect(answer, contains('1.100,00'));
    expect(answer, contains('não consigo apontar um gasto específico'));
  });

  test('card questions distinguish purchases, competence and cash payment', () {
    final answer = buildLocalMonthlyAnswer(month(), 'Quanto foi o cartão?');
    expect(answer, contains('1.200,00'));
    expect(answer, contains('800,00'));
    expect(answer, contains('9.000,00'));
    expect(answer, contains('não é contado novamente'));
  });

  test('balance question does not misrepresent economic result as cash', () {
    final answer = buildLocalMonthlyAnswer(month(), 'Posso gastar hoje?');
    expect(answer, contains('não indicam seu saldo disponível hoje'));
    expect(answer, contains('Não use este resumo para autorizar uma compra'));
  });

  test('unsupported free question fails closed instead of simulating model AI', () {
    final answer = buildLocalMonthlyAnswer(month(), 'Explique a economia mundial.');
    expect(answer, contains('requer mais contexto'));
    expect(answer, contains('Não enviei seus dados'));
  });

  test('no records does not fabricate financial conclusions', () {
    final answer = buildLocalMonthlyAnswer(
      month(income: 0, expenses: 0), 'Como está meu mês?');
    expect(answer, contains('Não há receitas ou despesas registradas'));
    expect(answer, isNot(contains('equilibradas')));
  });

  test('manual ChatGPT handoff contains ONLY allowed aggregates and question', () {
    final prompt = buildChatGptMonthlyPrompt(month(), 'Como estou?');
    expect(prompt, contains('09/2026:'));
    expect(prompt, contains('Receitas reais: R\$'));
    expect(prompt, contains('4.000,00')); // Intl emits a nonbreaking space.
    expect(prompt, contains('Pergunta: Como estou?'));
    expect(prompt, contains('Pagamentos de fatura (apenas fluxo de caixa)'));
    expect(prompt, contains('nenhum dado foi enviado'));
    expect(prompt, isNot(contains('CPF')));
    expect(prompt, isNot(contains('senha')));
    expect(prompt, contains('\n'));
  });
}