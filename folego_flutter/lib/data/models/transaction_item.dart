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
    this.categoryName,
    this.categoryColorHex,
  });

  final String id;
  final String eventType;
  final String description;
  final double amount;
  final DateTime occurredAt;
  final DateTime? competenceDate;
  final String status;
  final String source;
  final String? categoryName;
  final String? categoryColorHex;

  factory TransactionItem.fromJson(Map<String, dynamic> json) {
    final category =
        (json['category'] ?? json['categories']) as Map<String, dynamic>?;

    return TransactionItem(
      id: json['id'] as String,
      eventType: json['event_type'] as String,
      description: json['description'] as String,
      amount: (json['amount'] as num).toDouble(),
      occurredAt: DateTime.parse(json['occurred_at'] as String),
      competenceDate: json['competence_date'] == null
          ? null
          : DateTime.parse(json['competence_date'] as String),
      status: json['status'] as String,
      source: json['source'] as String,
      categoryName: category?['name'] as String?,
      categoryColorHex: category?['color_hex'] as String?,
    );
  }
}
