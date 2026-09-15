enum ReflectionType {
  necessary('necessary', 'necessário'),
  want('want', 'vontade'),
  selfInvestment('self_investment', 'investimento em mim');

  const ReflectionType(this.persistedValue, this.label);

  final String persistedValue;
  final String label;

  static ReflectionType? tryParse(String? value) {
    for (final type in ReflectionType.values) {
      if (type.persistedValue == value) return type;
    }
    return null;
  }
}

const eligibleDiaryEventTypes = <String>{
  'expense',
  'card_purchase',
  'benefit_expense',
};

bool isDiaryEligibleEventType(String eventType) {
  return eligibleDiaryEventTypes.contains(eventType);
}

String diaryDisplayDescription(String value) {
  return value
      .replaceFirst(
        RegExp(r'\s*\[extrato\s+\d+\]\s*$', caseSensitive: false),
        '',
      )
      .trim();
}

class TransactionReflection {
  const TransactionReflection({
    required this.id,
    required this.spaceId,
    required this.eventId,
    required this.type,
    required this.createdAt,
    required this.updatedAt,
    this.note,
  });

  final String id;
  final String spaceId;
  final String eventId;
  final ReflectionType type;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory TransactionReflection.fromJson(Map<String, dynamic> json) {
    final type = ReflectionType.tryParse(json['reflection_type'] as String?);
    if (type == null) {
      throw FormatException('Tipo de reflexão inválido.');
    }
    return TransactionReflection(
      id: json['id'] as String,
      spaceId: json['space_id'] as String,
      eventId: json['event_id'] as String,
      type: type,
      note: (json['note'] as String?)?.trim().isEmpty == true
          ? null
          : (json['note'] as String?)?.trim(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class DiaryEntry {
  const DiaryEntry({
    required this.eventId,
    required this.eventType,
    required this.description,
    required this.amount,
    required this.occurredAt,
    this.categoryName,
    this.categoryParentName,
    this.reflection,
  });

  final String eventId;
  final String eventType;
  final String description;
  final double amount;
  final DateTime occurredAt;
  final String? categoryName;
  final String? categoryParentName;
  final TransactionReflection? reflection;

  bool get isEligible => isDiaryEligibleEventType(eventType);
  bool get isReflected => reflection != null;
  String get displayDescription => diaryDisplayDescription(description);
  String get displayCategory {
    final parent = categoryParentName?.trim();
    final category = categoryName?.trim();
    if (parent != null && parent.isNotEmpty && category != null && category.isNotEmpty) {
      return '$parent › $category';
    }
    if (category != null && category.isNotEmpty) return category;
    return 'A classificar';
  }
}

class DiarySummary {
  const DiarySummary({
    required this.totalReflected,
    required this.amounts,
  });

  final double totalReflected;
  final Map<ReflectionType, double> amounts;

  factory DiarySummary.fromEntries(Iterable<DiaryEntry> entries) {
    final amounts = <ReflectionType, double>{
      for (final type in ReflectionType.values) type: 0,
    };
    for (final entry in entries) {
      final type = entry.reflection?.type;
      if (type != null) {
        amounts[type] = (amounts[type] ?? 0) + entry.amount.abs();
      }
    }
    final total = amounts.values.fold<double>(0, (sum, value) => sum + value);
    return DiarySummary(totalReflected: total, amounts: amounts);
  }

  double percentage(ReflectionType type) {
    if (totalReflected <= 0) return 0;
    return (amounts[type] ?? 0) / totalReflected;
  }

  ReflectionType? get largestType {
    if (totalReflected <= 0) return null;
    return ReflectionType.values.reduce(
      (a, b) => (amounts[a] ?? 0) >= (amounts[b] ?? 0) ? a : b,
    );
  }

  String get insight {
    final type = largestType;
    if (type == null) {
      return 'quando você refletir sobre um gasto, seu mês começa a ganhar contexto.';
    }
    final percent = (percentage(type) * 100).round();
    switch (type) {
      case ReflectionType.necessary:
        return 'a maior parte dos seus gastos refletidos foi necessária ($percent%).';
      case ReflectionType.want:
        return '$percent% dos seus gastos refletidos esse mês foram por vontade.';
      case ReflectionType.selfInvestment:
        return 'investimento em você representou $percent% dos gastos refletidos.';
    }
  }
}

List<DiaryEntry> reflectedTimeline(Iterable<DiaryEntry> entries) {
  final result = entries.where((entry) => entry.reflection != null).toList()
    ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
  return result;
}

List<DiaryEntry> pendingReflectionEntries(
  Iterable<DiaryEntry> entries, {
  int limit = 4,
}) {
  final result = entries
      .where((entry) => entry.isEligible && entry.reflection == null)
      .toList()
    ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
  return result.take(limit).toList(growable: false);
}
