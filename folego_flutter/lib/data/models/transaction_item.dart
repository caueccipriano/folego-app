class TransactionItem {
  const TransactionItem({
    required this.id,
    required this.eventType,
    required this.description,
    required this.amount,
    required this.occurredAt,
    required this.status,
    required this.source,
    this.competenceDate,
    this.categoryId,
    this.categoryName,
    this.categoryColorHex,
    this.categoryParentId,
    this.accountId,
    this.accountName,
  });

  final String id;
  final String eventType;
  final String description;
  final double amount;
  final DateTime occurredAt;
  final DateTime? competenceDate;
  final String status;
  final String source;

  final String? categoryId;
  final String? categoryName;
  final String? categoryColorHex;
  final String? categoryParentId;

  final String? accountId;
  final String? accountName;

  bool get isIncome {
    return eventType == 'income';
  }

  bool get isExpense {
    return eventType == 'expense' ||
        eventType == 'card_purchase' ||
        eventType == 'benefit_expense' ||
        eventType == 'debt_payment';
  }

  bool get canEditAsSimple {
    return eventType == 'income' || eventType == 'expense';
  }

  factory TransactionItem.fromJson(Map<String, dynamic> json) {
    final categoryRaw = json['category'] ?? json['categories'];

    final category = categoryRaw is Map
        ? Map<String, dynamic>.from(categoryRaw)
        : null;

    final accountData = _extractAccountData(
      json['financial_impacts'],
    );

    return TransactionItem(
      id: json['id'] as String,
      eventType: json['event_type'] as String,
      description: json['description'] as String,
      amount: (json['amount'] as num).toDouble(),
      occurredAt: DateTime.parse(
        json['occurred_at'] as String,
      ),
      competenceDate: json['competence_date'] == null
          ? null
          : DateTime.parse(
              json['competence_date'] as String,
            ),
      status: json['status'] as String,
      source: json['source'] as String,
      categoryId: category?['id'] as String?,
      categoryName: category?['name'] as String?,
      categoryColorHex: category?['color_hex'] as String?,
      categoryParentId: category?['parent_id'] as String?,
      accountId: accountData.$1,
      accountName: accountData.$2,
    );
  }

  static (String?, String?) _extractAccountData(
    dynamic impactsRaw,
  ) {
    if (impactsRaw is! List) {
      return (null, null);
    }

    Map<String, dynamic>? fallback;

    for (final raw in impactsRaw) {
      if (raw is! Map) {
        continue;
      }

      final impact = Map<String, dynamic>.from(raw);

      final accountId = impact['account_id'] as String?;

      if (accountId == null) {
        continue;
      }

      fallback ??= impact;

      if (impact['dimension'] == 'cash') {
        return _accountFromImpact(impact);
      }
    }

    if (fallback != null) {
      return _accountFromImpact(fallback);
    }

    return (null, null);
  }

  static (String?, String?) _accountFromImpact(
    Map<String, dynamic> impact,
  ) {
    final accountRaw = impact['account'];

    final account = accountRaw is Map
        ? Map<String, dynamic>.from(accountRaw)
        : null;

    return (
      (impact['account_id'] ?? account?['id']) as String?,
      account?['name'] as String?,
    );
  }
}
