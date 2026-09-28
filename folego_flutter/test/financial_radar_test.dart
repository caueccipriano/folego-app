import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/intelligence/financial_radar.dart';
import 'package:folego/data/models/projection_model.dart';

void main() {
  test('does not claim reliable results without projection inputs', () {
    final projection = ProjectionResult.fromJson({
      'as_of_date': '2026-09-27',
      'has_projection_inputs': false,
      'months': [],
    });
    final radar = FinancialRadar.fromProjection(projection);
    expect(radar.hasReliableInputs, isFalse);
    expect(radar.firstNegativeMonth, isNull);
  });
  test('uses projected closing balance and orders months', () {
    final projection = ProjectionResult.fromJson({
      'as_of_date': '2026-09-27',
      'has_projection_inputs': true,
      'months': [
        {'month': '2026-11-01', 'closing_projected': -100},
        {'month': '2026-10-01', 'closing_projected': 50},
      ],
    });
    final radar = FinancialRadar.fromProjection(projection);
    expect(radar.hasReliableInputs, isTrue);
    expect(radar.months.first.month.month, 10);
    expect(radar.firstNegativeMonth, DateTime(2026, 11));
    expect(radar.lowestClosingBalance, -100);
  });
}
