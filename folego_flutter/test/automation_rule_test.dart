import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/automation_rule.dart';
import 'package:folego/data/models/statement_import.dart';

void main() {
  const candidate = StatementImportCandidate(
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
}
