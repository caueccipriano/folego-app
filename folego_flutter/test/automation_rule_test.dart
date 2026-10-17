import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/automation_rule.dart';
import 'package:folego/data/models/statement_import.dart';

void main() {
  final candidate = StatementImportCandidate(
    rowNumber: 1,
    occurredAt: DateTime(2026, 9, 17),
    dateOnly: true,
    amountMinor: 2590,
    description: 'PAGAMENTO CAFÉ DO CENTRO',
    merchant: 'Café do Centro',
    direction: StatementImportDirection.debit,
    candidateType: StatementImportCandidateType.expense,
  );

  AutomationRule rule({
    AutomationMatchField field = AutomationMatchField.description,
    AutomationMatchType type = AutomationMatchType.contains,
    String value = 'cafe do centro',
    AutomationDirection direction = AutomationDirection.any,
    bool active = true,
  }) => AutomationRule(
        id: 'rule-1',
        spaceId: 'space-1',
        name: 'Café',
        active: active,
        matchField: field,
        matchType: type,
        matchValue: value,
        sourceScope: AutomationSourceScope.any,
        direction: direction,
        actionType: AutomationActionType.suggestCategory,
        executionMode: AutomationExecutionMode.suggest,
        priority: 0,
      );

  test('matching is accent, case and whitespace insensitive', () {
    expect(rule().matchesCandidate(candidate), isTrue);
    expect(
      rule(
        field: AutomationMatchField.merchant,
        type: AutomationMatchType.equals,
        value: '  CAFÉ   DO CENTRO ',
      ).matchesCandidate(candidate),
      isTrue,
    );
  });

  test('direction and active state constrain preview', () {
    expect(
      rule(direction: AutomationDirection.credit).matchesCandidate(candidate),
      isFalse,
    );
    expect(rule(active: false).matchesCandidate(candidate), isFalse);
  });

  test('preview only selects scoped rules for the exact source instrument', () {
    final scoped = AutomationRule(
      id: 'scoped-card-rule',
      spaceId: 'space-1',
      name: 'Assinatura do cartão',
      active: true,
      matchField: AutomationMatchField.description,
      matchType: AutomationMatchType.contains,
      matchValue: 'streaming',
      sourceScope: AutomationSourceScope.card,
      sourceCardId: 'card-1',
      direction: AutomationDirection.debit,
      actionType: AutomationActionType.suggestCategory,
      executionMode: AutomationExecutionMode.review,
      priority: 5,
    );
    final general = AutomationRule(
      id: 'general-rule',
      spaceId: 'space-1',
      name: 'Streaming geral',
      active: true,
      matchField: AutomationMatchField.description,
      matchType: AutomationMatchType.contains,
      matchValue: 'streaming',
      sourceScope: AutomationSourceScope.any,
      direction: AutomationDirection.any,
      actionType: AutomationActionType.suggestCategory,
      executionMode: AutomationExecutionMode.review,
      priority: 0,
    );

    List<AutomationRule> preview(String source) => previewAutomationRules(
          rules: [general, scoped],
          text: 'STREAMING PREMIUM',
          direction: AutomationDirection.debit,
          sourceKey: source,
        );

    expect(preview('any').map((item) => item.id), ['general-rule']);
    expect(preview('account:card-1').map((item) => item.id),
        ['general-rule']);
    expect(preview('card:other-card').map((item) => item.id),
        ['general-rule']);
    expect(preview('card:card-1').map((item) => item.id),
        ['scoped-card-rule', 'general-rule']);
  });

  test('preview filters credit vs debit and never applies a rule', () {
    final incomeRule = AutomationRule(
      id: 'income-rule',
      spaceId: 'space-1',
      name: 'Salário',
      active: true,
      matchField: AutomationMatchField.merchant,
      matchType: AutomationMatchType.contains,
      matchValue: 'salário',
      sourceScope: AutomationSourceScope.account,
      sourceAccountId: 'bank-1',
      direction: AutomationDirection.credit,
      actionType: AutomationActionType.suggestClassification,
      executionMode: AutomationExecutionMode.suggest,
      priority: 1,
    );

    List<AutomationRule> preview(AutomationDirection direction) =>
        previewAutomationRules(
          rules: [incomeRule],
          text: 'SALÁRIO MENSAL',
          direction: direction,
          sourceKey: 'account:bank-1',
        );

    expect(preview(AutomationDirection.debit), isEmpty);
    expect(preview(AutomationDirection.credit).single.id, 'income-rule');
    expect(previewAutomationRules(
      rules: [incomeRule],
      text: ' ',
      direction: AutomationDirection.credit,
      sourceKey: 'account:bank-1',
    ), isEmpty);
    expect(previewAutomationRules(
      rules: [incomeRule],
      text: 'salario',
      direction: AutomationDirection.credit,
      sourceKey: 'benefit:bank-1',
    ), isEmpty);
  });
}
