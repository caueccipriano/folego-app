enum UpcomingEventSource {
  recurring,
  cardInvoice,
  debt,
  unknown,
}

enum UpcomingEventDirection {
  income,
  outflow,
  informational,
}

enum AgendaFilter {
  all,
  recurring,
  cards,
  debts,
  income,
}

enum AgendaSection {
  overdue,
  today,
  tomorrow,
  thisWeek,
  later,
}

class UpcomingFinancialEvent {
  const UpcomingFinancialEvent({
    required this.eventKey,
    required this.source,
    required this.sourceId,
    required this.title,
    required this.subtitle,
    required this.dueDate,
    required this.amount,
    required this.direction,
    required this.status,
    required this.overdue,
    required this.realized,
    required this.recurring,
    required this.dayOffset,
    required this.cashObligation,
    required this.navigationTarget,
    this.parentId,
    this.categoryId,
    this.accountId,
    this.cardId,
    this.debtId,
    this.installmentNumber,
    this.installmentCount,
    this.invoiceId,
  });

  final String eventKey;
  final UpcomingEventSource source;
  final String sourceId;
  final String? parentId;
  final String title;
  final String subtitle;
  final DateTime dueDate;
  final double amount;
  final UpcomingEventDirection direction;
  final String status;
  final String? categoryId;
  final String? accountId;
  final String? cardId;
  final String? debtId;
  final bool overdue;
  final bool realized;
  final bool recurring;
  final int? installmentNumber;
  final int? installmentCount;
  final String? invoiceId;
  final String navigationTarget;
  final int dayOffset;
  final bool cashObligation;

  bool get isIncome => direction == UpcomingEventDirection.income;
  bool get isOutflow => direction == UpcomingEventDirection.outflow;
  bool get isInformational =>
      direction == UpcomingEventDirection.informational;
  bool get isRecurring => source == UpcomingEventSource.recurring;
  bool get isInvoice => source == UpcomingEventSource.cardInvoice;
  bool get isDebt => source == UpcomingEventSource.debt;

  AgendaSection get section {
    if (overdue || dayOffset < 0) return AgendaSection.overdue;
    if (dayOffset == 0) return AgendaSection.today;
    if (dayOffset == 1) return AgendaSection.tomorrow;
    if (dayOffset <= 7) return AgendaSection.thisWeek;
    return AgendaSection.later;
  }

  bool matches(AgendaFilter filter) {
    return switch (filter) {
      AgendaFilter.all => true,
      AgendaFilter.recurring => isRecurring && !isIncome,
      AgendaFilter.cards => isInvoice,
      AgendaFilter.debts => isDebt,
      AgendaFilter.income => isIncome,
    };
  }

  String get sourceLabel => switch (source) {
    UpcomingEventSource.recurring => 'recorrente',
    UpcomingEventSource.cardInvoice => 'cartão',
    UpcomingEventSource.debt => 'dívida',
    UpcomingEventSource.unknown => 'previsto',
  };

  factory UpcomingFinancialEvent.fromJson(Map<String, dynamic> json) {
    return UpcomingFinancialEvent(
      eventKey: json['event_key'] as String,
      source: _source(json['source'] as String?),
      sourceId: json['source_id'] as String,
      parentId: json['parent_id'] as String?,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String? ?? '',
      dueDate: DateTime.parse(json['due_date'] as String),
      amount: _number(json['amount']),
      direction: _direction(json['direction'] as String?),
      status: json['status'] as String? ?? 'pending',
      categoryId: json['category_id'] as String?,
      accountId: json['account_id'] as String?,
      cardId: json['card_id'] as String?,
      debtId: json['debt_id'] as String?,
      overdue: json['overdue'] as bool? ?? false,
      realized: json['realized'] as bool? ?? false,
      recurring: json['recurring'] as bool? ?? false,
      installmentNumber: (json['installment_number'] as num?)?.toInt(),
      installmentCount: (json['installment_count'] as num?)?.toInt(),
      invoiceId: json['invoice_id'] as String?,
      navigationTarget: json['navigation_target'] as String? ?? '',
      dayOffset: (json['day_offset'] as num?)?.toInt() ?? 0,
      cashObligation: json['cash_obligation'] as bool? ?? false,
    );
  }
}

class AgendaSummary {
  const AgendaSummary({
    required this.outflowCount,
    required this.outflowAmount,
    required this.incomeCount,
    required this.incomeAmount,
  });

  final int outflowCount;
  final double outflowAmount;
  final int incomeCount;
  final double incomeAmount;

  factory AgendaSummary.nextDays(
    Iterable<UpcomingFinancialEvent> events, {
    int days = 7,
  }) {
    var outflowCount = 0;
    var outflowAmount = 0.0;
    var incomeCount = 0;
    var incomeAmount = 0.0;

    for (final event in events) {
      if (event.dayOffset < 0 || event.dayOffset >= days) continue;
      if (event.isIncome) {
        incomeCount += 1;
        incomeAmount += event.amount;
      } else if (event.isOutflow && event.cashObligation) {
        outflowCount += 1;
        outflowAmount += event.amount;
      }
    }

    return AgendaSummary(
      outflowCount: outflowCount,
      outflowAmount: outflowAmount,
      incomeCount: incomeCount,
      incomeAmount: incomeAmount,
    );
  }
}

String agendaSectionLabel(AgendaSection section) => switch (section) {
  AgendaSection.overdue => 'atrasados',
  AgendaSection.today => 'hoje',
  AgendaSection.tomorrow => 'amanhã',
  AgendaSection.thisWeek => 'esta semana',
  AgendaSection.later => 'mais adiante',
};

String agendaFilterLabel(AgendaFilter filter) => switch (filter) {
  AgendaFilter.all => 'todos',
  AgendaFilter.recurring => 'recorrências',
  AgendaFilter.cards => 'cartões',
  AgendaFilter.debts => 'dívidas',
  AgendaFilter.income => 'entradas',
};

UpcomingEventSource _source(String? value) => switch (value) {
  'recurring' => UpcomingEventSource.recurring,
  'invoice' => UpcomingEventSource.cardInvoice,
  'debt' => UpcomingEventSource.debt,
  _ => UpcomingEventSource.unknown,
};

UpcomingEventDirection _direction(String? value) => switch (value) {
  'income' => UpcomingEventDirection.income,
  'outflow' => UpcomingEventDirection.outflow,
  _ => UpcomingEventDirection.informational,
};

double _number(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
