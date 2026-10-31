import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('paid invoice only permits labels through separate guarded RPC', () {
    final sheet = File('lib/features/transactions/transaction_action_sheets.dart')
        .readAsStringSync();
    final repo = File('lib/data/repositories/folego_repository_transaction_actions.dart')
        .readAsStringSync();
    expect(sheet, contains('await widget.repository.updateCardPurchaseLabels('));
    expect(sheet, contains('if (_financialEditable) {'));
    expect(sheet, contains('enabled: _financialEditable'));
    expect(sheet, contains('onTap: _pickCategory'));
    expect(repo, contains("'update_card_purchase_labels'"));
    final labelsOnly = repo.split('Future<void> updateCardPurchaseLabels(').last
        .split('Future<void> cancelCardPurchase(').first;
    expect(labelsOnly, isNot(contains('p_total_amount')));
    expect(labelsOnly, isNot(contains('p_card_id')));
    expect(labelsOnly, isNot(contains('p_purchase_at')));
  });

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
