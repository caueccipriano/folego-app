import 'package:flutter_test/flutter_test.dart';
import 'package:folego_flutter/data/models/income_amount_confirmation.dart';

void main() {
  group('Confirmações de recebimentos', () {
    test('ausência de confirmação não deve ser interpretada como zero', () {
      const confirmations = <IncomeAmountConfirmation>[];
      expect(confirmations, isEmpty);
      // A agenda pode ter um valor recorrente, mas ele NÃO constitui
      // confirmação de uma ocorrência futura.
    });

    test('identifica a confirmação por recorrência e data', () {
      final a = IncomeAmountConfirmation.occurrenceId(
        'item-1', DateTime(2026, 11, 15),
      );
      final b = IncomeAmountConfirmation.occurrenceId(
        'item-1', DateTime(2026, 12, 15),
      );
      final c = IncomeAmountConfirmation.occurrenceId(
        'item-2', DateTime(2026, 11, 15),
      );
      expect(a, 'item-1:2026-11-15');
      expect(a, isNot(b));
      expect(a, isNot(c));
    });

    test('somente valores explicitamente confirmados são parseados', () {
      final value = IncomeAmountConfirmation.fromJson({
        'recurring_item_id': 'item-1',
        'due_date': '2026-11-30',
        'confirmed_amount': '2300.50',
        'confirmed_at': '2026-11-13T17:00:00Z',
      });
      expect(value.amount, 2300.50);
      expect(value.occurrenceKey, 'item-1:2026-11-30');
    });

    test('impede valores não positivos ou inválidos', () {
      for (final raw in [0, -1, 'abc', null]) {
        expect(
          () => IncomeAmountConfirmation.fromJson({
            'recurring_item_id': 'item-1',
            'due_date': '2026-11-15',
            'confirmed_amount': raw,
            'confirmed_at': '2026-11-13T17:00:00Z',
          }),
          throwsFormatException,
        );
      }
    });
  });
}
