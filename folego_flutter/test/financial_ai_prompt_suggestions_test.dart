import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/features/shell/financial_ai_prompt_suggestions.dart';

void main() {
  testWidgets('suggestion selects a draft without a network request',
      (tester) async {
    final selected = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FinancialAiPromptSuggestions(
          enabled: true,
          onSelected: selected.add,
        ),
      ),
    ));

    await tester.tap(find.text('Qual categoria merece atenção?'));
    await tester.pump();
    expect(selected, ['Qual categoria merece atenção?']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hidden or busy suggestions cannot be selected',
      (tester) async {
    final selected = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FinancialAiPromptSuggestions(
          enabled: false,
          onSelected: selected.add,
        ),
      ),
    ));

    await tester.tap(find.text('Como está meu mês?'));
    await tester.pump();
    expect(selected, isEmpty);
    expect(tester.takeException(), isNull);
  });

  test('the AI screen asks only through explicit submission', () {
    final source = File('lib/features/shell/financial_ai_screen.dart')
        .readAsStringSync();
    final suggestions =
        File('lib/features/shell/financial_ai_prompt_suggestions.dart')
            .readAsStringSync();
    expect(source, contains('FinancialAiPromptSuggestions('));
    expect(source, contains('valueListenable: _question'));
    expect(source, contains('!ready'));
    expect(source, contains('_providerConfigured == false ? null : _ask'));
    expect(source, contains('Só tocar em Perguntar'));
    expect(suggestions, isNot(contains('_ask()')));
    expect(suggestions, isNot(contains('functions.invoke')));
  });
}
