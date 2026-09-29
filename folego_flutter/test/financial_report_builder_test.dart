import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/intelligence/financial_report_builder.dart';
import 'package:folego/data/models/monthly_money_summary.dart';

MonthlyMoneySummary summary(double income, double expense) => MonthlyMoneySummary(
  periodMonth: DateTime(2026, 9), incomeAmount: income,
  spendingAccount: expense, spendingCards: 0, spendingBenefits: 0,
  refundsAmount: 0, spendingNet: expense, incomeMinusSpending: income-expense,
  competenceCardsTotal: 0, competenceDirect: expense,
  competenceBenefits: 0, competenceRefunds: 0, competenceNet: expense,
  competenceCards: const [], cashInflow: income, cashOutflow: expense,
  cashNet: income-expense, movementCardPayments: 0, movementTransfers: 0,
  movementReserveInvestment: 0, movementReconciliation: 0,
);

void main() {
  test('relatório usa competência, sem duplicar pagamentos de cartão', () {
    final report = FinancialReportBuilder.monthly(
      current: summary(1000, 800), previous: summary(1000, 500));
    expect(report.result, 200);
    expect(report.insights.length, 2);
    expect(report.insights.last.description, contains('60,0%'));
  });
  test('sem mês anterior não inventa tendência', () {
    final report = FinancialReportBuilder.monthly(current: summary(100, 200));
    expect(report.result, -100);
    expect(report.insights.length, 1);
    expect(report.insights.first.description, contains('R\$'));
    expect(report.insights.first.description, contains('100,00'));
  });
}
