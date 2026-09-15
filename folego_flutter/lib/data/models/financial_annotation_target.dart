enum FinancialAnnotationTargetType {
  event,
  recurring,
}

class FinancialAnnotationTarget {
  const FinancialAnnotationTarget({
    required this.id,
    required this.targetType,
    required this.title,
    required this.eventType,
    this.date,
    this.active = true,
    this.necessityClass,
    this.behaviorClass,
    this.frequencyClass,
    this.tagIds = const <String>[],
  });

  final String id;
  final FinancialAnnotationTargetType targetType;
  final String title;
  final String eventType;
  final DateTime? date;
  final bool active;
  final String? necessityClass;
  final String? behaviorClass;
  final String? frequencyClass;
  final List<String> tagIds;

  bool get isRecurring => targetType == FinancialAnnotationTargetType.recurring;

  bool get isIncome => eventType == 'income';

  bool get isExpense {
    return eventType == 'expense' ||
        eventType == 'card_purchase' ||
        eventType == 'benefit_expense' ||
        eventType == 'debt_payment';
  }

  String get typeLabel {
    if (isRecurring) return 'Recorrência';
    if (isIncome) return 'Receita';
    if (isExpense) return 'Gasto';
    return 'Movimentação';
  }

  FinancialAnnotationTarget copyWithAnnotations({
    String? necessityClass,
    String? behaviorClass,
    String? frequencyClass,
    List<String>? tagIds,
  }) {
    return FinancialAnnotationTarget(
      id: id,
      targetType: targetType,
      title: title,
      eventType: eventType,
      date: date,
      active: active,
      necessityClass: necessityClass,
      behaviorClass: behaviorClass,
      frequencyClass: isRecurring ? 'recurring' : frequencyClass,
      tagIds: tagIds ?? this.tagIds,
    );
  }
}
