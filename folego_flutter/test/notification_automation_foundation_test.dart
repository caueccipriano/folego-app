import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/entitlements/feature_entitlements.dart';
import 'package:folego/core/notifications/notification_models.dart';
import 'package:folego/data/models/automation_rule.dart';
import 'package:folego/data/models/statement_import.dart';

void main() {
  test('free entitlements keep essential notifications and no premium automation', () {
    final free = const FreeEntitlementProvider().entitlements;
    expect(free.essentialNotifications, isTrue);
    expect(free.automationRules, isFalse);
    expect(free.bankSync, isFalse);
    expect(free.automaticTransactionProcessing, isFalse);
    expect(free.advancedNotifications, isFalse);

    final premium = const MockPremiumEntitlementProvider().entitlements;
    expect(premium.essentialNotifications, isTrue);
    expect(premium.automationRules, isTrue);
    expect(premium.bankSync, isFalse);
    expect(premium.automaticTransactionProcessing, isFalse);
  });

  test('import row preserves automation suggestion metadata without auto posting', () {
    final row = StatementImportRow.fromJson(<String, dynamic>{
      'id': 'row-1',
      'batch_id': 'batch-1',
      'row_number': 1,
      'occurred_at': '2026-09-17T12:00:00.000Z',
      'description': 'UBER *TRIP',
      'merchant': 'UBER',
      'amount': 35.90,
      'direction': 'debit',
      'candidate_type': 'expense',
      'final_type': 'expense',
      'category_id': 'cat-transport',
      'duplicate_state': 'unique',
      'user_decision': 'review',
      'status': 'staged',
      'automation_rule_id': 'rule-1',
      'automation_suggested_category_id': 'cat-transport',
      'automation_suggested_final_type': null,
      'automation_recognized': false,
    });

    expect(row.hasAutomationSuggestion, isTrue);
    expect(row.automationRuleId, 'rule-1');
    expect(row.automationSuggestedCategoryId, 'cat-transport');
    final patch = row.toReviewPatch();
    expect(patch.keys, isNot(contains('automation_rule_id')));
    expect(patch.keys, isNot(contains('imported_event_id')));
  });

  test('explicit always-do-this helper creates review-only scoped category rule', () {
    final row = StatementImportRow(
      id: 'row-1',
      batchId: 'batch-1',
      rowNumber: 1,
      occurredAt: DateTime(2026, 9, 17),
      description: 'UBER *TRIP',
      merchant: 'UBER',
      amount: 35.90,
      direction: StatementImportDirection.debit,
      candidateType: StatementImportCandidateType.expense,
      finalType: StatementImportFinalType.expense,
      categoryId: 'cat-transport',
      duplicateState: StatementImportDuplicateState.unique,
      decision: StatementImportDecision.review,
      status: StatementImportRowStatus.staged,
    );

    final draft = automationRuleDraftFromReviewedImportRow(
      row: row,
      sourceKind: StatementImportSourceKind.card,
      sourceId: 'card-1',
    );

    expect(draft, isNotNull);
    expect(draft!.matchField, AutomationMatchField.merchant);
    expect(draft.matchType, AutomationMatchType.contains);
    expect(draft.matchValue, 'UBER');
    expect(draft.sourceScope, AutomationSourceScope.card);
    expect(draft.sourceCardId, 'card-1');
    expect(draft.categoryId, 'cat-transport');
    expect(draft.executionMode, AutomationExecutionMode.review);
    expect(draft.actionType, AutomationActionType.suggestCategory);
  });

  test('always-do-this helper refuses incomplete review rows', () {
    final row = StatementImportRow(
      id: 'row-1',
      batchId: 'batch-1',
      rowNumber: 1,
      occurredAt: DateTime(2026, 9, 17),
      description: 'SEM CATEGORIA',
      amount: 10,
      direction: StatementImportDirection.debit,
      candidateType: StatementImportCandidateType.expense,
      finalType: StatementImportFinalType.expense,
      duplicateState: StatementImportDuplicateState.unique,
      decision: StatementImportDecision.review,
      status: StatementImportRowStatus.staged,
    );

    expect(
      automationRuleDraftFromReviewedImportRow(
        row: row,
        sourceKind: StatementImportSourceKind.account,
        sourceId: 'account-1',
      ),
      isNull,
    );
  });

  test('deterministic preview precedence prefers source-specific then exact then priority', () {
    AutomationRule rule({
      required String id,
      AutomationSourceScope scope = AutomationSourceScope.any,
      AutomationMatchType matchType = AutomationMatchType.contains,
      int priority = 0,
    }) => AutomationRule(
          id: id,
          spaceId: 'space-1',
          name: id,
          active: true,
          matchField: AutomationMatchField.description,
          matchType: matchType,
          matchValue: 'UBER',
          sourceScope: scope,
          sourceCardId: scope == AutomationSourceScope.card ? 'card-1' : null,
          direction: AutomationDirection.any,
          actionType: AutomationActionType.markRecognized,
          executionMode: AutomationExecutionMode.suggest,
          priority: priority,
        );

    final rules = <AutomationRule>[
      rule(id: 'global-exact', matchType: AutomationMatchType.equals, priority: 99),
      rule(id: 'specific-contains', scope: AutomationSourceScope.card),
      rule(id: 'specific-exact-low', scope: AutomationSourceScope.card, matchType: AutomationMatchType.equals),
      rule(id: 'specific-exact-high', scope: AutomationSourceScope.card, matchType: AutomationMatchType.equals, priority: 10),
    ]..sort(compareAutomationRulesForPreview);

    expect(rules.first.id, 'specific-exact-high');
  });

  test('notification stable id remains deterministic and privacy-minimal', () {
    final key = financialNotificationStableKey(
      entityType: 'invoice',
      entityId: 'invoice-1',
      dueDate: DateTime(2026, 9, 20),
      reminderOffsetDays: 3,
      kind: FinancialNotificationKind.invoice,
    );
    expect(key, 'invoice:invoice-1:2026-09-20:3:invoice');
    expect(key, isNot(contains('35.90')));
  });
}
