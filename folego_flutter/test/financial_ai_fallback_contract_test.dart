import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:folego/features/shell/financial_ai_status.dart';

void main() {
  test('A local response is never credited to OpenAI or Gemini', () {
    expect(financialAiProviderName('local'), 'Cálculo do Fôlego');
    expect(financialAiProviderName('gemini'), 'gemini');
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
    expect(source, contains('limite disponível não verificado'));
    expect(source, contains('Só tocar em Perguntar'));
    expect(source, isNot(contains('getMonthlyMoneySummary')));
  });

  test('Financial AI backend uses Gemini exclusively with local fallback', () {
    final code = File('../supabase/functions/financial-ai/index.ts')
        .readAsStringSync();
    expect(code, contains("const provider = 'gemini';"));
    expect(code, contains("Deno.env.get('GEMINI_API_KEY')"));
    expect(code, contains("localReply('fallback')"));
    expect(code, isNot(contains('OPENAI_API_KEY')));
    expect(code, isNot(contains('api.openai.com')));
    expect(code, isNot(contains('FOLEGO_AI_PROVIDER')));
    expect(code, isNot(contains('gpt-4.1-mini')));
  });

  test('A failed AI reply cannot pretend to be an AI-generated text', () {
    final source = File('lib/features/shell/financial_ai_screen.dart')
        .readAsStringSync();
    expect(source, contains("responseMode == 'fallback'"));
    expect(source, contains("financialAiProviderName(payload['provider'])"));
    expect(source, contains('sem geração de texto por IA'));
  });

  test('Switching financial spaces invalidates pending AI and status replies', () {
    final source = File('lib/features/shell/financial_ai_screen.dart')
        .readAsStringSync();
    expect(source, contains('int _requestSerial = 0;'));
    expect(source, contains('int _providerSerial = 0;'));
    expect(source, contains('final serial = ++_requestSerial;'));
    expect(source, contains('serial != _requestSerial'));
    expect(source, contains('_requestSerial++;'));
    expect(source, contains('_sending = false;'));
    expect(source, contains('oldWidget.spaceId != widget.spaceId ||'));
    expect(source, contains('widget.client != requestedClient'));
    expect(source, contains('serial != _providerSerial'));
  });
}
