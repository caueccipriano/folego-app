import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('planner goes straight to the existing safe purchase template', () {
    final planner = File('lib/features/plan/plan_screen_web2.dart')
        .readAsStringSync();
    final shell = File('lib/features/plan/plan_screen.dart')
        .readAsStringSync();
    final projection = File('lib/features/plan/projection_screen.dart')
        .readAsStringSync();

    expect(planner, contains("ValueKey('plan-can-i-buy')"));
    expect(planner, contains('onPurchaseSimulationRequested'));
    expect(shell, contains('startWithPurchase: _startWithPurchase'));
    expect(projection, contains('initialTemplate: _SimulationTemplate.purchase'));
    expect(projection, contains('buildPurchaseSimulation('));
    expect(projection, contains('nada aqui vira lançamento'));
  });
}
