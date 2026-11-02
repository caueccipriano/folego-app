import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:folego/features/home/quick_register_defaults.dart';

void main() {
  group('quick register instrument preselection', () {
    test('preselects only an unambiguous account', () {
      expect(
        quickRegisterInstrumentId(
          items: const ['a'],
          currentId: null,
          idOf: (value) => value,
        ),
        'a',
      );
      expect(
        quickRegisterInstrumentId(
          items: const ['a', 'b'],
          currentId: null,
          idOf: (value) => value,
        ),
        isNull,
      );
      expect(
        quickRegisterInstrumentId(
          items: const <String>[],
          currentId: null,
          idOf: (value) => value,
        ),
        isNull,
      );
    });

    test('keeps valid choices but never keeps a removed instrument', () {
      expect(
        quickRegisterInstrumentId(
          items: const ['a', 'b'],
          currentId: 'b',
          idOf: (value) => value,
        ),
        'b',
      );
      expect(
        quickRegisterInstrumentId(
          items: const ['a', 'b'],
          currentId: 'old',
          idOf: (value) => value,
        ),
        isNull,
      );
      expect(
        quickRegisterInstrumentId(
          items: const ['only'],
          currentId: 'old',
          idOf: (value) => value,
        ),
        isNull,
      );
    });
  });

  group('historical shortcut payment rules', () {
    test('only copies direct expenses to currently unselected accounts', () {
      expect(
        quickRegisterHistoryAccountId(
          eventType: 'expense',
          historicalAccountId: 'a',
          activeAccountIds: const ['a', 'b'],
          currentlyUsingAccount: true,
          selectedAccountId: null,
        ),
        'a',
      );
      for (final type in ['card_purchase', 'benefit_expense', 'debt_payment']) {
        expect(
          quickRegisterHistoryAccountId(
            eventType: type,
            historicalAccountId: 'a',
            activeAccountIds: const ['a', 'b'],
            currentlyUsingAccount: true,
            selectedAccountId: null,
          ),
          isNull,
        );
      }
      expect(
        quickRegisterHistoryAccountId(
          eventType: 'expense',
          historicalAccountId: 'a',
          activeAccountIds: const ['a', 'b'],
          currentlyUsingAccount: false,
          selectedAccountId: null,
        ),
        isNull,
      );
      expect(
        quickRegisterHistoryAccountId(
          eventType: 'expense',
          historicalAccountId: 'a',
          activeAccountIds: const ['a', 'b'],
          currentlyUsingAccount: true,
          selectedAccountId: 'b',
        ),
        isNull,
      );
      expect(
        quickRegisterHistoryAccountId(
          eventType: 'expense',
          historicalAccountId: 'inactive',
          activeAccountIds: const ['a', 'b'],
          currentlyUsingAccount: true,
          selectedAccountId: null,
        ),
        isNull,
      );
    });
  });

  test('quick capture remains opt-in with explicit save and category selection', () {
    final source = File('lib/features/home/quick_register_sheet_v3.dart')
        .readAsStringSync();
    expect(source, contains('QuickCaptureDraft.parse(value)'));
    expect(source, contains("setState(() => _error = 'selecione uma categoria')"));
    expect(source, contains('onPressed: _saving ? null : _save'));
    expect(source, contains('quickRegisterInstrumentId('));
    expect(source, contains('quickRegisterHistoryAccountId('));
  });
}
