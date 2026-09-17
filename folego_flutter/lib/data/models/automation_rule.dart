import 'statement_import.dart';

enum AutomationMatchField { description, merchant }
enum AutomationMatchType { equals, contains }
enum AutomationSourceScope { any, account, card, benefit }
enum AutomationDirection { any, debit, credit }
enum AutomationActionType {
  suggestCategory,
  reviewCategory,
  suggestClassification,
  markRecognized,
}
enum AutomationExecutionMode { suggest, review, automatic }

extension AutomationMatchFieldKey on AutomationMatchField {
  String get dbKey => switch (this) {
        AutomationMatchField.description => 'description',
        AutomationMatchField.merchant => 'merchant',
      };
}

extension AutomationMatchTypeKey on AutomationMatchType {
  String get dbKey => switch (this) {
        AutomationMatchType.equals => 'equals',
        AutomationMatchType.contains => 'contains',
      };
}

extension AutomationSourceScopeKey on AutomationSourceScope {
  String get dbKey => switch (this) {
        AutomationSourceScope.any => 'any',
        AutomationSourceScope.account => 'account',
        AutomationSourceScope.card => 'card',
        AutomationSourceScope.benefit => 'benefit',
      };
}

extension AutomationDirectionKey on AutomationDirection {
  String get dbKey => switch (this) {
        AutomationDirection.any => 'any',
        AutomationDirection.debit => 'debit',
        AutomationDirection.credit => 'credit',
      };
}

extension AutomationActionTypeKey on AutomationActionType {
  String get dbKey => switch (this) {
        AutomationActionType.suggestCategory => 'suggest_category',
        AutomationActionType.reviewCategory => 'review_category',
        AutomationActionType.suggestClassification => 'suggest_classification',
        AutomationActionType.markRecognized => 'mark_recognized',
      };
}

extension AutomationExecutionModeKey on AutomationExecutionMode {
  String get dbKey => switch (this) {
        AutomationExecutionMode.suggest => 'suggest',
        AutomationExecutionMode.review => 'review',
        AutomationExecutionMode.automatic => 'automatic',
      };
}

class AutomationRule {
  const AutomationRule({
    required this.id,
    required this.spaceId,
    required this.name,
    required this.active,
    required this.matchField,
    required this.matchType,
    required this.matchValue,
    required this.sourceScope,
    required this.direction,
    required this.actionType,
    required this.executionMode,
    required this.priority,
    this.sourceAccountId,
    this.sourceCardId,
    this.sourceBenefitId,
    this.categoryId,
    this.classificationValue,
  });

  final String id;
  final String spaceId;
  final String name;
  final bool active;
  final AutomationMatchField matchField;
  final AutomationMatchType matchType;
  final String matchValue;
  final AutomationSourceScope sourceScope;
  final String? sourceAccountId;
  final String? sourceCardId;
  final String? sourceBenefitId;
  final AutomationDirection direction;
  final String? categoryId;
  final String? classificationValue;
  final AutomationActionType actionType;
  final AutomationExecutionMode executionMode;
  final int priority;

  bool matchesCandidate(StatementImportCandidate candidate) {
    if (!active) return false;
    if (direction == AutomationDirection.debit &&
        candidate.direction != StatementImportDirection.debit) {
      return false;
    }
    if (direction == AutomationDirection.credit &&
        candidate.direction != StatementImportDirection.credit) {
      return false;
    }
    final haystack = switch (matchField) {
      AutomationMatchField.description => candidate.description,
      AutomationMatchField.merchant => candidate.merchant ?? '',
    };
    final normalizedHaystack = normalizeAutomationText(haystack);
    final normalizedNeedle = normalizeAutomationText(matchValue);
    return switch (matchType) {
      AutomationMatchType.equals => normalizedHaystack == normalizedNeedle,
      AutomationMatchType.contains =>
        normalizedNeedle.isNotEmpty && normalizedHaystack.contains(normalizedNeedle),
    };
  }

  factory AutomationRule.fromJson(Map<String, dynamic> json) => AutomationRule(
        id: json['id'] as String,
        spaceId: json['space_id'] as String,
        name: json['name'] as String? ?? 'Regra',
        active: json['active'] as bool? ?? true,
        matchField: json['match_field'] == 'merchant'
            ? AutomationMatchField.merchant
            : AutomationMatchField.description,
        matchType: json['match_type'] == 'equals'
            ? AutomationMatchType.equals
            : AutomationMatchType.contains,
        matchValue: json['match_value'] as String? ?? '',
        sourceScope: _sourceScope(json['source_scope_type'] as String?),
        sourceAccountId: json['source_account_id'] as String?,
        sourceCardId: json['source_card_id'] as String?,
        sourceBenefitId: json['source_benefit_id'] as String?,
        direction: _direction(json['direction'] as String?),
        categoryId: json['category_id'] as String?,
        classificationValue: json['classification_value'] as String?,
        actionType: _actionType(json['action_type'] as String?),
        executionMode: _executionMode(json['execution_mode'] as String?),
        priority: (json['priority'] as num?)?.toInt() ?? 0,
      );
}

class AutomationRuleDraft {
  const AutomationRuleDraft({
    required this.name,
    required this.matchField,
    required this.matchType,
    required this.matchValue,
    required this.actionType,
    this.active = true,
    this.sourceScope = AutomationSourceScope.any,
    this.sourceAccountId,
    this.sourceCardId,
    this.sourceBenefitId,
    this.direction = AutomationDirection.any,
    this.categoryId,
    this.classificationValue,
    this.executionMode = AutomationExecutionMode.suggest,
    this.priority = 0,
  });

  final String name;
  final bool active;
  final AutomationMatchField matchField;
  final AutomationMatchType matchType;
  final String matchValue;
  final AutomationSourceScope sourceScope;
  final String? sourceAccountId;
  final String? sourceCardId;
  final String? sourceBenefitId;
  final AutomationDirection direction;
  final String? categoryId;
  final String? classificationValue;
  final AutomationActionType actionType;
  final AutomationExecutionMode executionMode;
  final int priority;

  Map<String, dynamic> toWriteJson({
    required String spaceId,
    String? createdBy,
  }) {
    final json = <String, dynamic>{
      'space_id': spaceId,
      'name': name.trim(),
      'active': active,
      'trigger_type': 'statement_candidate',
      'match_field': matchField.dbKey,
      'match_type': matchType.dbKey,
      'match_value': matchValue.trim(),
      'source_scope_type': sourceScope.dbKey,
      'source_account_id': sourceScope == AutomationSourceScope.account
          ? sourceAccountId
          : null,
      'source_card_id':
          sourceScope == AutomationSourceScope.card ? sourceCardId : null,
      'source_benefit_id': sourceScope == AutomationSourceScope.benefit
          ? sourceBenefitId
          : null,
      'direction': direction == AutomationDirection.any ? null : direction.dbKey,
      'category_id': categoryId,
      'classification_value': classificationValue,
      'action_type': actionType.dbKey,
      'execution_mode': executionMode.dbKey,
      'priority': priority,
    };
    if (createdBy != null) json['created_by'] = createdBy;
    return json;
  }
}

AutomationRuleDraft? automationRuleDraftFromReviewedImportRow({
  required StatementImportRow row,
  required StatementImportSourceKind sourceKind,
  required String sourceId,
}) {
  final categoryId = row.categoryId;
  if (categoryId == null || row.finalType == null) return null;
  final merchant = row.merchant?.trim();
  final useMerchant = merchant != null && merchant.isNotEmpty;
  final matchValue = useMerchant ? merchant : row.description.trim();
  if (matchValue.isEmpty) return null;

  final sourceScope = switch (sourceKind) {
    StatementImportSourceKind.account => AutomationSourceScope.account,
    StatementImportSourceKind.card => AutomationSourceScope.card,
    StatementImportSourceKind.benefit => AutomationSourceScope.benefit,
  };
  final direction = row.direction == StatementImportDirection.credit
      ? AutomationDirection.credit
      : AutomationDirection.debit;

  return AutomationRuleDraft(
    name: 'Sempre: $matchValue',
    matchField: useMerchant
        ? AutomationMatchField.merchant
        : AutomationMatchField.description,
    matchType: AutomationMatchType.contains,
    matchValue: matchValue,
    sourceScope: sourceScope,
    sourceAccountId:
        sourceScope == AutomationSourceScope.account ? sourceId : null,
    sourceCardId: sourceScope == AutomationSourceScope.card ? sourceId : null,
    sourceBenefitId:
        sourceScope == AutomationSourceScope.benefit ? sourceId : null,
    direction: direction,
    categoryId: categoryId,
    actionType: AutomationActionType.suggestCategory,
    executionMode: AutomationExecutionMode.review,
  );
}

int compareAutomationRulesForPreview(AutomationRule a, AutomationRule b) {
  final source = _boolRank(b.sourceScope != AutomationSourceScope.any)
      .compareTo(_boolRank(a.sourceScope != AutomationSourceScope.any));
  if (source != 0) return source;
  final exact = _boolRank(b.matchType == AutomationMatchType.equals)
      .compareTo(_boolRank(a.matchType == AutomationMatchType.equals));
  if (exact != 0) return exact;
  final priority = b.priority.compareTo(a.priority);
  if (priority != 0) return priority;
  return a.id.compareTo(b.id);
}

int _boolRank(bool value) => value ? 1 : 0;

String normalizeAutomationText(String value) {
  var normalized = value.trim().toLowerCase();
  const accents = <String, String>{
    'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
    'ç': 'c', 'ñ': 'n',
  };
  accents.forEach((from, to) => normalized = normalized.replaceAll(from, to));
  return normalized.replaceAll(RegExp(r'\s+'), ' ');
}

AutomationSourceScope _sourceScope(String? value) => switch (value) {
      'account' => AutomationSourceScope.account,
      'card' => AutomationSourceScope.card,
      'benefit' => AutomationSourceScope.benefit,
      _ => AutomationSourceScope.any,
    };
AutomationDirection _direction(String? value) => switch (value) {
      'debit' => AutomationDirection.debit,
      'credit' => AutomationDirection.credit,
      _ => AutomationDirection.any,
    };
AutomationActionType _actionType(String? value) => switch (value) {
      'review_category' => AutomationActionType.reviewCategory,
      'suggest_classification' => AutomationActionType.suggestClassification,
      'mark_recognized' => AutomationActionType.markRecognized,
      _ => AutomationActionType.suggestCategory,
    };
AutomationExecutionMode _executionMode(String? value) => switch (value) {
      'review' => AutomationExecutionMode.review,
      'automatic' => AutomationExecutionMode.automatic,
      _ => AutomationExecutionMode.suggest,
    };
