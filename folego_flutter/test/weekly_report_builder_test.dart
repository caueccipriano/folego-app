import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/intelligence/weekly_report_builder.dart';
import 'package:folego/data/models/transaction_item.dart';

TransactionItem item(String type, double amount, DateTime date, String category) =>
    TransactionItem(id: '${type}_${date.day}', eventType: type,
      description: category, amount: amount, occurredAt: date,
      status: 'confirmed', source: 'manual', categoryName: category);

void main() {
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
