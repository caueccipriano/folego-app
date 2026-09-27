import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/intelligence/weekly_report_builder.dart';
import 'package:folego/data/models/transaction_item.dart';

TransactionItem item(String type, double amount, DateTime date, String category) =>
    TransactionItem(id: '${type}_${date.day}', eventType: type,
      description: category, amount: amount, occurredAt: date,
      status: 'confirmed', source: 'manual', categoryName: category);

void main() {
  test('compara semana e mês em períodos equivalentes sem duplicar fatura', () {
    final report = WeeklyReportBuilder.currentProgress(
      asOf: DateTime(2026, 9, 23, 18),
      transactions: [
        item('expense', 100, DateTime(2026, 9, 14, 10), 'Mercado'),
        item('expense', 80, DateTime(2026, 9, 21, 10), 'Mercado'),
        item('expense', 50, DateTime(2026, 9, 22, 10), 'Transporte'),
        item('card_payment', 130, DateTime(2026, 9, 22, 11), 'Cartão'),
        item('expense', 60, DateTime(2026, 8, 21, 10), 'Mercado'),
        item('income', 500, DateTime(2026, 9, 22, 12), 'Salário'),
      ],
    );
    expect(report.weekExpenses, 130);
    expect(report.weekIncome, 500);
    expect(report.previousWeekExpenses, 100);
    expect(report.monthExpenses, 230);
    expect(report.previousMonthExpenses, 60);
    expect(report.categoryChanges.first.name, 'Transporte');
    expect(report.categoryChanges.first.difference, 50);
  });
  test('não compara mês sem dias equivalentes', () {
    final report = WeeklyReportBuilder.currentProgress(
      asOf: DateTime(2026, 3, 31),
      transactions: [],
    );
    expect(report.previousMonthComparable, false);
  });
  test('ignora pagamentos de fatura e identifica aumento semanal', () {
    final report = WeeklyReportBuilder.build(
      weekStart: DateTime(2026, 9, 14),
      asOf: DateTime(2026, 9, 22),
      transactions: [
        item('expense', 100, DateTime(2026, 9, 8), 'Mercado'),
        item('card_purchase', 150, DateTime(2026, 9, 15), 'Mercado'),
        item('card_payment', 150, DateTime(2026, 9, 16), 'Mercado'),
        item('income', 300, DateTime(2026, 9, 17), 'Salário'),
      ],
    );
    expect(report.expenses, 150);
    expect(report.income, 300);
    expect(report.patterns.single.variationPercent, 50);
  });
  test('semana em andamento não gera comparação enganosa', () {
    final report = WeeklyReportBuilder.build(
      weekStart: DateTime(2026, 9, 21),
      asOf: DateTime(2026, 9, 23),
      transactions: [],
    );
    expect(report.comparedWithPreviousWeek, false);
    expect(report.patterns, isEmpty);
  });
}
