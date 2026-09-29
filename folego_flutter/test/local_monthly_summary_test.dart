import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/monthly_money_summary.dart';
import 'package:folego/widgets/local_monthly_summary.dart';

MonthlyMoneySummary _month(double income, double expenses) =>
    MonthlyMoneySummary.fromJson({
      'period_month': '2026-09-01',
      'income_amount': income,
      'competence_net': expenses,
      'cash_outflow': 9000,
      'movement_card_payments': 9000,
    });

void main() {
  test('offline summary uses official competence totals only', () {
    final result = buildLocalMonthlySummary(_month(4033.23, 5103.31));
    expect(result, contains('R\$ 4.033,23'));
    expect(result, contains('R\$ 5.103,31'));
    expect(result, contains('R\$ -1.070,08'));
    expect(result, isNot(contains('9.000')));
    expect(result, contains('não uma resposta da IA'));
  });

  test('missing activity never fabricates financial guidance', () {
    final result = buildLocalMonthlySummary(_month(0, 0));
    expect(result, contains('Não há receitas ou despesas registradas'));
    expect(result, isNot(contains('equilibradas')));
  });
}
