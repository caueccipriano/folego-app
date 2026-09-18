import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/projection_model.dart';

void main() {
  test('parses chained ProjectionEngine response', () {
    final projection = ProjectionResult.fromJson({
      'scenario': 'current',
      'horizon_months': 3,
      'as_of_date': '2026-09-17',
      'opening_balance': 1000,
      'has_projection_inputs': true,
      'summary': {
        'ending_balance': 2200,
        'minimum_balance': 1500,
        'maximum_balance': 2200,
        'projected_savings': 300,
        'critical_month': null,
      },
      'variable_incomes': [
        {
          'key': 'recurring:freelance',
          'name': 'Freelance',
          'amount': 600,
          'enabled': true,
        },
      ],
      'months': [
        {
          'month': '2026-09-01',
          'opening_balance': 1000,
          'guaranteed_income': 5000,
          'variable_income': 0,
          'income': 5000,
          'direct_expenses': 4000,
          'recurring_expenses': 0,
          'card_installments': 0,
          'debts': 0,
          'reserve_transfers': 0,
          'investments': 0,
          'other_inflows': 0,
          'other_outflows': 0,
          'planned_movements': 0,
          'benefit_expenses': 0,
          'net_change': 1000,
          'closing_balance': 2000,
          'realized_to_date': 1000,
          'still_expected': 1000,
          'closing_projected': 2000,
          'categories': [
            {'name': 'Alimentação', 'amount': 800},
          ],
        },
      ],
    });

    expect(projection.scenario, 'current');
    expect(projection.horizonMonths, 3);
    expect(projection.openingBalance, 1000);
    expect(projection.summary.endingBalance, 2200);
    expect(projection.variableIncomes.single.name, 'Freelance');
    expect(projection.months.single.openingBalance, 1000);
    expect(projection.months.single.closingBalance, 2000);
    expect(projection.months.single.categories.single.name, 'Alimentação');
  });

  test('serializes simulation without ledger semantics', () {
    final adjustment = ProjectionAdjustment(
      id: 'car',
      name: 'Novo carro',
      component: 'debt',
      amountDelta: 1200,
      frequency: 'monthly',
      startsOn: DateTime(2026, 10, 1),
      endsOn: DateTime(2029, 9, 1),
      categoryName: 'Transporte',
    );

    final json = adjustment.toJson();

    expect(json['component'], 'debt');
    expect(json['amount_delta'], 1200);
    expect(json['frequency'], 'monthly');
    expect(json.containsKey('event_type'), isFalse);
    expect(json.containsKey('financial_event'), isFalse);
  });
}
