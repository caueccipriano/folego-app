import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('zeroed budgets never look like permission to spend', () {
    final source = File('lib/features/plan/plan_screen_web2.dart')
        .readAsStringSync();

    expect(source, contains('sem verba planejada'));
    expect(source, contains('sem verba para novas compras'));
    expect(source, contains('R$ 0 de verba liberada neste mês'));
    expect(source, contains('sem teto definido · não significa dinheiro livre'));
    expect(source, contains('não é saldo livre'));
    expect(source, contains('confira também seu caixa antes de gastar'));

    // Existing financial and category logic remains the primary source.
    expect(source, contains('_buildSummary(brightness)'));
    expect(source, contains('_buildCategories(brightness)'));
    expect(source, contains('_editBudget(child)'));
    expect(source, isNot(contains("'nenhum gasto neste mês · sem limite'")));
  });
}
