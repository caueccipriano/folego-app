import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/features/shell/financial_ai_answer_actions.dart';

void main() {
  for (final enabled in [true, false]) {
    testWidgets('answer actions only respond when enabled: $enabled',
        (tester) async {
      var copied = 0;
      var cleared = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FinancialAiAnswerActions(
            enabled: enabled,
            onCopy: () => copied++,
            onClear: () => cleared++,
          ),
        ),
      ));
      expect(find.byKey(const ValueKey('financial-ai-answer-actions')),
          findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('financial-ai-copy-answer')));
      await tester.tap(find.byKey(const ValueKey('financial-ai-clear-answer')));
      await tester.pump();
      expect(copied, enabled ? 1 : 0);
      expect(cleared, enabled ? 1 : 0);
      expect(tester.takeException(), isNull);
    });
  }

  test('answers are only copied on request and never while hidden', () {
    final source = File('lib/features/shell/financial_ai_screen.dart')
        .readAsStringSync();
    expect(source, contains('Clipboard.setData(ClipboardData(text: answer))'));
    expect(source, contains('if (answer == null || FinancialPrivacy.hidden.value)'));
    expect(source, contains('if (_answer != null && !hidden)'));
    expect(source, contains('FinancialAiAnswerActions('));
    expect(source, contains('onCopy: _copyAnswer'));
    expect(source, contains('onClear: _clearAnswer'));
    expect(source, isNot(contains('Clipboard.getData')));
  });

  test('clear removes the prior answer and focus without remote writes', () {
    final source = File('lib/features/shell/financial_ai_screen.dart')
        .readAsStringSync();
    expect(source, contains('void _clearAnswer()'));
    expect(source, contains('_answer = null;'));
    expect(source, contains('_focusTitle = null;'));
    expect(source, contains('_focusDescription = null;'));
    expect(source, isNot(contains('.insert(')));
    expect(source, isNot(contains('.update(')));
  });
}
