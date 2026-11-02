import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/projection_model.dart';

void main() {
  test('quick spend uses an exact one-time charge in the existing engine', () {
    final purchase = buildPurchaseSimulation(
      id: 'quick-spend-preview',
      name: 'gasto hipotético',
      totalCents: 25750,
      payments: 1,
      firstPayment: DateTime(2026, 11, 2),
    );
    expect(purchase, hasLength(1));
    expect(purchase.single.component, 'direct_expense');
    expect(purchase.single.frequency, 'once');
    expect(purchase.single.amountDelta, 257.50);
    expect(purchase.single.source, 'simulation');
  });

  test('screen is read-only, privacy-aware and avoids stale spaces', () {
    final source = File('lib/features/plan/quick_spend_simulator_screen.dart')
        .readAsStringSync();
    expect(source, contains('FinancialPrivacy.hidden'));
    expect(source, contains('getProjection('));
    expect(source, contains('buildPurchaseSimulation('));
    expect(source, contains('serial != _request'));
    expect(source, contains('widget.spaceId != spaceId'));
    expect(source, contains("ValueKey('quick-spend-comparison')"));
    expect(source, isNot(contains('.insert(')));
    expect(source, isNot(contains('.update(')));
  });

  test('plan keeps existing long purchase comparison accessible', () {
    final entry = File('lib/features/plan/plan_screen_web2.dart')
        .readAsStringSync();
    final route = File('lib/features/plan/plan_screen.dart')
        .readAsStringSync();
    expect(entry, contains("ValueKey('plan-quick-spend')"));
    expect(entry, contains("ValueKey('plan-can-i-buy')"));
    expect(route, contains('QuickSpendSimulatorScreen('));
    expect(route, contains('onQuickSpendRequested: _openQuickSpend'));
  });
}
