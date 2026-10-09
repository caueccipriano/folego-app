import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/projection_model.dart';

void main() {
  test('installments preserve cents and remain under adjustment cap', () {
    for (final payments in [1, 3, 40, 120]) {
      final result = buildPurchaseSimulation(
        id: 'test',
        name: 'Compra',
        totalCents: 10001,
        payments: payments,
        firstPayment: DateTime(2026, 1, 31),
      );
      final total = result.fold<int>(
        0,
        (sum, a) =>
            sum +
            (a.amountDelta * 100).round() *
                (a.frequency == 'monthly' ? payments : 1),
      );
      expect(total, 10001);
      expect(result.length, lessThanOrEqualTo(2));
      expect(
        result.first.endsOn,
        payments == 1
            ? null
            : projectionMonthlyEndDate(DateTime(2026, 1, 31), payments),
      );
    }
  });
  test('month end clamps and restores on later months', () {
    expect(
      projectionMonthlyEndDate(DateTime(2026, 1, 31), 2),
      DateTime(2026, 2, 28),
    );
    expect(
      projectionMonthlyEndDate(DateTime(2026, 1, 31), 3),
      DateTime(2026, 3, 31),
    );
  });
  test('invalid installment counts are rejected', () {
    for (final payments in [0, 121]) {
      expect(
        () => buildPurchaseSimulation(
          id: 'test',
          name: 'Compra',
          totalCents: 10000,
          payments: payments,
          firstPayment: DateTime(2026, 1, 1),
        ),
        throwsArgumentError,
      );
    }
  });
}
