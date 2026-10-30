import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:folego/features/plan/purchase_comparison.dart';

void main() {
  test('quick purchase accepts an unnamed simulation', () {
    expect(purchaseSimulationName(''), 'compra simulada');
    expect(purchaseSimulationName('   '), 'compra simulada');
    expect(purchaseSimulationName('  notebook  '), 'notebook');
  });

  test('purchase starts with one value; other fields are optional', () {
    final source = File('lib/features/plan/projection_screen.dart')
        .readAsStringSync();
    expect(source, contains("ValueKey('purchase-advanced-toggle')"));
    expect(source, contains("'valor da compra'"));
    expect(source, contains('purchaseSimulationName(_name.text)'));
    expect(source, contains('buildPurchaseSimulation('));
    expect(source, contains('nada aqui vira lançamento'));
    expect(source, contains('ver impacto da compra'));
  });
}
