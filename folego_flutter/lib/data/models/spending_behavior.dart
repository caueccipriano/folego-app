/// Expense behavior is independent from frequency (recurring/one-off) and
/// necessity (need/want). An unknown behavior must never be guessed.
enum ExpenseBehavior {
  fixed,
  variable,
  unclassified;

  String get databaseValue => switch (this) {
    fixed => 'fixed',
    variable => 'variable',
    unclassified => '',
  };

  String get label => switch (this) {
    fixed => 'fixos',
    variable => 'variáveis',
    unclassified => 'sem classificação',
  };

  static ExpenseBehavior fromDatabase(String? value) => switch (value) {
    'fixed' => fixed,
    'variable' => variable,
    _ => unclassified,
  };
}

class SpendingBehaviorEntry {
  const SpendingBehaviorEntry({
    required this.id,
    required this.description,
    required this.amount,
    required this.occurredAt,
    required this.behavior,
    this.eventType = 'expense',
    this.necessityClass,
    this.frequencyClass,
  });

  final String id;
  final String description;
  final double amount;
  final DateTime occurredAt;
  final ExpenseBehavior behavior;
  final String eventType;
  final String? necessityClass;
  final String? frequencyClass;

  SpendingBehaviorEntry withBehavior(ExpenseBehavior updated) =>
      SpendingBehaviorEntry(
        id: id,
        description: description,
        amount: amount,
        occurredAt: occurredAt,
        behavior: updated,
        eventType: eventType,
        necessityClass: necessityClass,
        frequencyClass: frequencyClass,
      );

  factory SpendingBehaviorEntry.fromJson(Map<String, dynamic> json) {
    final rawAmount = json['amount'];
    final amount = rawAmount is num
        ? rawAmount.toDouble()
        : double.tryParse(rawAmount?.toString() ?? '');
    final when = DateTime.tryParse(json['occurred_at']?.toString() ?? '');
    if (amount == null || !amount.isFinite || when == null) {
      throw const FormatException('Invalid financial expense amount/date');
    }
    return SpendingBehaviorEntry(
      id: json['id'] as String,
      description: (json['description'] as String?)?.trim().isNotEmpty == true
          ? (json['description'] as String).trim()
          : 'gasto sem descrição',
      amount: amount.abs(),
      occurredAt: when,
      eventType: json['event_type'] as String? ?? 'expense',
      behavior: ExpenseBehavior.fromDatabase(json['behavior_class'] as String?),
      necessityClass: json['necessity_class'] as String?,
      frequencyClass: json['frequency_class'] as String?,
    );
  }
}

class SpendingBehaviorSummary {
  const SpendingBehaviorSummary({
    required this.fixed,
    required this.variable,
    required this.unclassified,
    required this.total,
    required this.count,
    required this.unclassifiedCount,
  });

  final double fixed;
  final double variable;
  final double unclassified;
  final double total;
  final int count;
  final int unclassifiedCount;

  double shareOf(ExpenseBehavior behavior) {
    if (total <= 0) return 0;
    final amount = switch (behavior) {
      ExpenseBehavior.fixed => fixed,
      ExpenseBehavior.variable => variable,
      ExpenseBehavior.unclassified => unclassified,
    };
    return (amount / total).clamp(0.0, 1.0);
  }

  factory SpendingBehaviorSummary.fromEntries(
    Iterable<SpendingBehaviorEntry> entries,
  ) {
    var fixed = 0.0;
    var variable = 0.0;
    var unknown = 0.0;
    var count = 0;
    var unknownCount = 0;
    for (final entry in entries) {
      if (entry.amount < 0 || !entry.amount.isFinite) {
        throw const FormatException('Invalid expense');
      }
      count++;
      switch (entry.behavior) {
        case ExpenseBehavior.fixed:
          fixed += entry.amount;
        case ExpenseBehavior.variable:
          variable += entry.amount;
        case ExpenseBehavior.unclassified:
          unknown += entry.amount;
          unknownCount++;
      }
    }
    return SpendingBehaviorSummary(
      fixed: fixed,
      variable: variable,
      unclassified: unknown,
      total: fixed + variable + unknown,
      count: count,
      unclassifiedCount: unknownCount,
    );
  }
}
