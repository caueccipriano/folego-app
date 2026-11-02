import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Financial AI uses authenticated server-side space scope', () {
    final screen = File('lib/features/shell/financial_ai_screen.dart')
        .readAsStringSync();
    final shell = File('lib/features/shell/home_shell.dart').readAsStringSync();
    expect(screen, contains("'spaceId': requestedSpaceId"));
    expect(screen, contains("'financial-ai'"));
    expect(screen, contains('FinancialPrivacy.hidden'));
    expect(screen, contains("ValueKey('financial-ai-focus')"));
    expect(screen, contains("ValueKey('financial-ai-open-plan')"));
    expect(screen, isNot(contains(".from('financial_events')")));
    expect(shell, contains('onOpenPlan: ()'));
  });

  test('AI focus is read-only and requires a user request', () {
    final screen = File('lib/features/shell/financial_ai_screen.dart')
        .readAsStringSync();
    expect(screen, contains('_providerConfigured == false ? null : _ask'));
    expect(screen, contains('method: HttpMethod.get'));
    expect(screen, isNot(contains('getMonthlyMoneySummary')));
    expect(screen, isNot(contains('financialAiMonthlyContext')));
    expect(screen, contains("ValueKey('financial-ai-provider-status')"));
    expect(screen, contains('widget.onOpenPlan'));
    expect(screen, isNot(contains('.insert(')));
    expect(screen, isNot(contains('.update(')));
    expect(screen, isNot(contains('Gemini API key')));
  });
}
