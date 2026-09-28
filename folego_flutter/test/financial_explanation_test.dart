import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/intelligence/financial_explanation.dart';
import 'package:folego/core/intelligence/financial_report_builder.dart';

void main() {
  test('monthly explanation uses the supplied financial totals', () {
    const report = MonthlyIntelligenceReport(
      income: 5000,
      expenses: 4200,
      result: 800,
      insights: [],
    );
    final explanation = FinancialExplanation.monthly(report);
    expect(explanation, contains('5000.00'));
    expect(explanation, contains('4200.00'));
    expect(explanation, contains('não negativo'));
  });

  test('non-finite monthly result never becomes financial advice', () {
    const report = MonthlyIntelligenceReport(
      income: 0,
      expenses: 0,
      result: double.nan,
      insights: [],
    );
    expect(FinancialExplanation.monthly(report), contains('indisponível'));
  });
}
