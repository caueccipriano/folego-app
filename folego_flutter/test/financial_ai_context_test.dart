import 'package:flutter_test/flutter_test.dart';
import 'package:folego/features/shell/financial_ai_context.dart';

void main() {
  test('AI sends only a bounded month and consolidated money semantics', () {
    final context = financialAiMonthlyContext(
      month: DateTime(2026, 11, 15),
      income: 6000,
      competenceExpenses: 3900,
    );
    expect(context, {
      'month': '2026-11',
      'income': 6000,
      'expenses': 3900,
      'result': 2100,
    });
    expect(context.keys, hasLength(4));
    expect(context.containsKey('cardName'), isFalse);
    expect(context.containsKey('transaction'), isFalse);
  });

  test('Non-finite or negative monthly totals cannot be sent to the AI', () {
    expect(
      () => financialAiMonthlyContext(
        month: DateTime(2026, 11), income: double.nan,
        competenceExpenses: 20,
      ), throwsFormatException,
    );
    expect(
      () => financialAiMonthlyContext(
        month: DateTime(2026, 11), income: 200,
        competenceExpenses: -1,
      ), throwsFormatException,
    );
  });
}
