import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/income_date_schedule.dart';
import 'package:folego/data/models/onboarding_state.dart';
import 'package:folego/features/home/home_setup_gate.dart';

void main() {
  test('conta existente libera a Home mesmo sem receita recorrente', () {
    const setup = OnboardingState(
      accountCount: 1,
      hasAccount: true,
      hasConfirmedIncome: false,
      recurringExpenseCount: 0,
      hasCard: false,
      budgetConfigured: false,
      reserveConfigured: false,
      folegoReady: false,
      onboardingCompleted: false,
    );
    expect(shouldShowFirstUseHome(setup), isFalse);
  });

  test('apenas a ausência de conta mantém o primeiro uso', () {
    const setup = OnboardingState(
      accountCount: 0,
      hasAccount: false,
      hasConfirmedIncome: false,
      recurringExpenseCount: 0,
      hasCard: false,
      budgetConfigured: false,
      reserveConfigured: false,
      folegoReady: false,
      onboardingCompleted: false,
    );
    expect(shouldShowFirstUseHome(setup), isTrue);
  });

  test('calendário armazena somente dia e descrição, não salário', () {
    final item = IncomeDateSchedule(
      id: '1', label: 'Salário', dayOfMonth: 15,
      lastDayOfMonth: false, startsOn: DateTime(2026, 11, 1), active: true,
    );
    expect(item.dayOfMonth, 15);
    expect(item.whenLabel, 'Dia 15 de cada mês');
  });

  test('dia 30 se ajusta a fevereiro sem criar valor financeiro', () {
    final item = IncomeDateSchedule(
      id: '1', label: 'Salário', dayOfMonth: 30,
      lastDayOfMonth: false, startsOn: DateTime(2027, 1, 1), active: true,
    );
    final dates = item.datesBetween(DateTime(2027, 2, 1), DateTime(2027, 3, 31));
    expect(dates, [DateTime(2027, 2, 28), DateTime(2027, 3, 30)]);
  });

  test('calendário respeita data de início e último dia do mês', () {
    final item = IncomeDateSchedule(
      id: '1', label: 'Pagamento', dayOfMonth: null,
      lastDayOfMonth: true, startsOn: DateTime(2028, 2, 10), active: true,
    );
    final dates = item.datesBetween(DateTime(2028, 2, 1), DateTime(2028, 3, 31));
    expect(dates, [DateTime(2028, 2, 29), DateTime(2028, 3, 31)]);
  });

  test('confirmações ficam vinculadas a data e agendamento', () {
    final value = IncomeDateAmount.fromJson({
      'schedule_id': 'salario',
      'due_date': '2026-11-30',
      'confirmed_amount': '2350.75',
    });
    expect(value.amount, 2350.75);
    expect(value.key, 'salario:2026-11-30');
  });

  test('valor inválido nunca é tratado como recebimento', () {
    expect(() => IncomeDateAmount.fromJson({
      'schedule_id': 'salario',
      'due_date': '2026-11-30',
      'confirmed_amount': 0,
    }), throwsFormatException);
  });
}
