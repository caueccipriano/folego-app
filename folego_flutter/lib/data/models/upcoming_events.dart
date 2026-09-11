class UpcomingEvent {
  const UpcomingEvent({
    required this.id,
    required this.source,
    required this.name,
    required this.dueDate,
    required this.amount,
    required this.direction,
    required this.status,
    this.categoryId,
  });

  final String id;
  final String source;
  final String name;
  final DateTime dueDate;
  final double amount;
  final String direction;
  final String status;
  final String? categoryId;

  bool get isIncome => direction == 'income';

  bool get isExpense => direction == 'expense';

  bool get isPending => status == 'pending';

  bool get isRecurring => source == 'recurring';

  bool get isInvoice => source == 'invoice';

  bool get isDebt => source == 'debt';

  String get sourceLabel {
    switch (source) {
      case 'recurring':
        return 'Recorrência';

      case 'invoice':
        return 'Fatura';

      case 'debt':
        return 'Dívida';

      default:
        return 'Previsto';
    }
  }

  factory UpcomingEvent.fromJson(
    Map<String, dynamic> json,
  ) {
    return UpcomingEvent(
      id: json['id'] as String,
      source: json['source'] as String,
      name: json['name'] as String,
      dueDate: DateTime.parse(
        json['due_date'] as String,
      ),
      amount:
          (json['amount'] as num).toDouble(),
      direction:
          json['direction'] as String,
      categoryId:
          json['category_id'] as String?,
      status:
          json['status'] as String? ??
              'pending',
    );
  }
}
