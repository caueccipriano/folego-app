import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/monthly_money_summary.dart';
import 'package:folego/widgets/local_monthly_answers.dart';
import 'package:folego/widgets/local_question_suggestions.dart';

void main() {
  final summary = MonthlyMoneySummary.fromJson({
    'period_month': '2026-09-01',
    'income_amount': 3000,
    'competence_net': 2200,
  });

  test('guided questions have stable unique keys and are not blank', () {
    expect(localMonthlySuggestions.length, 6);
    expect(localMonthlySuggestions.map((s) => s.id).toSet().length,
        localMonthlySuggestions.length);
    for (final suggestion in localMonthlySuggestions) {
      expect(suggestion.label.trim(), isNotEmpty);
      expect(suggestion.question.length, inInclusiveRange(3, 500));
    }
  });

  test('suggested topics use supported local rules, not invented AI answers', () {
    final byId = {for (final s in localMonthlySuggestions) s.id: s};
    final card = buildLocalMonthlyAnswer(summary, byId['card']!.question);
    final transfers =
        buildLocalMonthlyAnswer(summary, byId['transfers']!.question);
    final balance = buildLocalMonthlyAnswer(summary, byId['balance']!.question);
    expect(card, contains('fatura'));
    expect(transfers, contains('Transferências'));
    expect(balance, contains('não indicam seu saldo disponível hoje'));
  });
}
