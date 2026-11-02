import 'package:flutter_test/flutter_test.dart';
import 'package:folego/features/shell/financial_ai_status.dart';

void main() {
  test('Only actual providers receive their public names', () {
    expect(financialAiProviderName('gemini'), 'gemini');
    expect(financialAiProviderName('openai'), isNull);
    expect(financialAiProviderName('other'), isNull);
    expect(financialAiProviderName(null), isNull);
  });

  test('Premium status has a clear error without disclosing other fields', () {
    expect(
      financialAiErrorMessage(403, {
        'error': 'Disponível para Premium, até 30 perguntas por mês.',
      }),
      contains('Premium'),
    );
    expect(
      financialAiErrorMessage(403, {'error': 'Sem acesso ao espaço financeiro.'}),
      contains('Sem acesso'),
    );
  });

  test('Unknown upstream payloads are not exposed in the interface', () {
    const privateToken = 'private-upstream-token-123';
    final text = financialAiErrorMessage(502, {
      'error': privateToken,
      'debug': 'sensitive context',
    });
    expect(text, isNot(contains(privateToken)));
    expect(text, isNot(contains('sensitive')));
  });

  test('Status messages distinguish configuration from login', () {
    expect(
      financialAiErrorMessage(503, {
        'error': 'Assistente ainda não configurado.',
      }),
      contains('configurado'),
    );
    expect(financialAiErrorMessage(401, {}), contains('sessão'));
    expect(financialAiErrorMessage(429, {}), contains('Muitas'));
  });
}
