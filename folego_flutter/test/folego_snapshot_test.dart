import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/folego_snapshot.dart';

void main() {
  test('interpreta o snapshot retornado pelo Fôlego Engine', () {
    final snapshot = FolegoSnapshot.fromJson({
      'as_of_date': '2026-09-09',
      'next_income_date': '2026-09-15',
      'next_income_amount': 2300,
      'days_until_income': 6,
      'liquid_balance': 1500,
      'protected_balance': 300,
      'mandatory_outflows_until_income': 800,
      'cash_headroom': 700,
      'monthly_budget_planned': 500,
      'monthly_budget_used': 0,
      'economic_headroom': 500,
      'spendable_pool': 500,
      'daily_folego': 83.33,
      'shortfall': 0,
      'limiting_factor': 'budget',
      'status': 'tranquilo',
      'budget_configured': true,
      'needs_income_setup': false,
    });

    expect(snapshot.dailyFolego, 83.33);
    expect(snapshot.spendablePool, 500);
    expect(snapshot.limitingFactor, 'budget');
    expect(snapshot.status, 'tranquilo');
  });
}
