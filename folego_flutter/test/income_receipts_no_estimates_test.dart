import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/upcoming_financial_event.dart';
import 'package:folego/data/repositories/folego_repository_income_receipts.dart';

UpcomingFinancialEvent scheduledIncome({
  required String id,
  required DateTime date,
  required double estimatedAmount,
}) => UpcomingFinancialEvent(
  eventKey: 'recurring:$id',
  source: UpcomingEventSource.recurring,
  sourceId: id,
  title: 'Salário',
  subtitle: 'Mensal',
  dueDate: date,
  amount: estimatedAmount,
  direction: UpcomingEventDirection.income,
  status: 'pending',
  overdue: false,
  realized: false,
  recurring: true,
  dayOffset: 5,
  cashObligation: false,
  navigationTarget: 'recurring',
);

void main() {
  test('um recebimento desconhecido não ganha valor previsto', () {
    final event = scheduledIncome(
      id: 'income-a',
      date: DateTime(2026, 11, 15),
      estimatedAmount: 9000,
    );
    final totals = IncomeReceiptTotals.fromEvents([event], {});
    expect(totals.confirmedTotal, 0);
    expect(totals.confirmedCount, 0);
    expect(totals.unknownCount, 1);
  });

  test('soma somente os valores informados em cada ocorrência', () {
    final first = scheduledIncome(
      id: 'income-a',
      date: DateTime(2026, 11, 15),
      estimatedAmount: 9000,
    );
    final second = scheduledIncome(
      id: 'income-a',
      date: DateTime(2026, 11, 30),
      estimatedAmount: 12000,
    );
    final totals = IncomeReceiptTotals.fromEvents(
      [first, second],
      {incomeReceiptKey(first.sourceId, first.dueDate): 2300.45},
    );
    expect(totals.confirmedTotal, closeTo(2300.45, 0.001));
    expect(totals.confirmedCount, 1);
    expect(totals.unknownCount, 1);
    expect(
      incomeReceiptKey(first.sourceId, first.dueDate),
      isNot(incomeReceiptKey(second.sourceId, second.dueDate)),
    );
  });

  test('ignora receitas já realizadas e outros tipos de evento', () {
    final future = scheduledIncome(
      id: 'income-c',
      date: DateTime(2026, 12, 15),
      estimatedAmount: 15000,
    );
    final totals = IncomeReceiptTotals.fromEvents(
      [future],
      {incomeReceiptKey('other', DateTime(2026, 12, 15)): 3000},
    );
    expect(totals.confirmedTotal, 0);
    expect(totals.unknownCount, 1);
  });
}
