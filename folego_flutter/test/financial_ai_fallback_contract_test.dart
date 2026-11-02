import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:folego/features/shell/financial_ai_status.dart';

void main() {
  test('A local response is never credited to OpenAI or Gemini', () {
    expect(financialAiProviderName('local'), 'Cálculo do Fôlego');
    expect(financialAiProviderName('gemini'), 'Gemini');
    expect(financialAiProviderName('openai'), isNull);
  });

  test('Automatic summary is explicit, free and respects privacy', () {
    final source = File('lib/features/shell/financial_ai_screen.dart')
        .readAsStringSync();
    expect(source, contains("ValueKey('financial-ai-local-summary')"));
    expect(source, contains("'mode': 'summary'"));
    expect(source, contains('withoutAi: true'));
    expect(source, contains('FinancialPrivacy.hidden.value'));
    expect(source, contains('não usa cota'));
    expect(source, contains("ValueKey('financial-ai-local-notice')"));
    expect(source, contains('créditos não verificados'));
    expect(source, isNot(contains('getMonthlyMoneySummary')));
  });

  test('A failed AI reply cannot pretend to be an AI-generated text', () {
    final source = File('lib/features/shell/financial_ai_screen.dart')
        .readAsStringSync();
    expect(source, contains("responseMode == 'fallback'"));
    expect(source, contains("financialAiProviderName(payload['provider'])"));
    expect(source, contains('sem geração de texto por IA'));
  });
}
