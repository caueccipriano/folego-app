enum NotificationPermissionStatus { unsupported, notDetermined, granted, denied }

enum FinancialNotificationKind {
  commitment,
  invoice,
  debtInstallment,
  recurrence,
  subscription,
  recurringIncome,
  overdue,
  bankSyncCompleted,
  transactionsNeedReview,
  automationApplied,
  automationNeedsReview,
  planThreshold,
}

class NotificationPreferences {
  const NotificationPreferences({
    required this.spaceId,
    this.financialRemindersEnabled = false,
    this.invoicesEnabled = true,
    this.debtsEnabled = true,
    this.recurrencesEnabled = true,
    this.subscriptionsEnabled = true,
    this.expectedIncomeEnabled = true,
    this.overdueEnabled = true,
    this.reminderOffsetDays = 1,
    this.preferredHour = 9,
    this.preferredMinute = 0,
  });

  final String spaceId;
  final bool financialRemindersEnabled;
  final bool invoicesEnabled;
  final bool debtsEnabled;
  final bool recurrencesEnabled;
  final bool subscriptionsEnabled;
  final bool expectedIncomeEnabled;
  final bool overdueEnabled;
  final int reminderOffsetDays;
  final int preferredHour;
  final int preferredMinute;

  String get preferredTimeDb =>
      '${preferredHour.toString().padLeft(2, '0')}:${preferredMinute.toString().padLeft(2, '0')}:00';

  NotificationPreferences copyWith({
    bool? financialRemindersEnabled,
    bool? invoicesEnabled,
    bool? debtsEnabled,
    bool? recurrencesEnabled,
    bool? subscriptionsEnabled,
    bool? expectedIncomeEnabled,
    bool? overdueEnabled,
    int? reminderOffsetDays,
    int? preferredHour,
    int? preferredMinute,
  }) => NotificationPreferences(
        spaceId: spaceId,
        financialRemindersEnabled:
            financialRemindersEnabled ?? this.financialRemindersEnabled,
        invoicesEnabled: invoicesEnabled ?? this.invoicesEnabled,
        debtsEnabled: debtsEnabled ?? this.debtsEnabled,
        recurrencesEnabled: recurrencesEnabled ?? this.recurrencesEnabled,
        subscriptionsEnabled: subscriptionsEnabled ?? this.subscriptionsEnabled,
        expectedIncomeEnabled:
            expectedIncomeEnabled ?? this.expectedIncomeEnabled,
        overdueEnabled: overdueEnabled ?? this.overdueEnabled,
        reminderOffsetDays: reminderOffsetDays ?? this.reminderOffsetDays,
        preferredHour: preferredHour ?? this.preferredHour,
        preferredMinute: preferredMinute ?? this.preferredMinute,
      );

  factory NotificationPreferences.fromJson(
    Map<String, dynamic> json, {
    required String fallbackSpaceId,
  }) {
    final preferred = _parseTime(json['preferred_time'] as String?);
    final offset = (json['reminder_offset_days'] as num?)?.toInt() ?? 1;
    return NotificationPreferences(
      spaceId: json['space_id'] as String? ?? fallbackSpaceId,
      financialRemindersEnabled:
          json['financial_reminders_enabled'] as bool? ?? false,
      invoicesEnabled: json['invoices_enabled'] as bool? ?? true,
      debtsEnabled: json['debts_enabled'] as bool? ?? true,
      recurrencesEnabled: json['recurrences_enabled'] as bool? ?? true,
      subscriptionsEnabled: json['subscriptions_enabled'] as bool? ?? true,
      expectedIncomeEnabled: json['expected_income_enabled'] as bool? ?? true,
      overdueEnabled: json['overdue_enabled'] as bool? ?? true,
      reminderOffsetDays: const {0, 1, 3}.contains(offset) ? offset : 1,
      preferredHour: preferred.$1,
      preferredMinute: preferred.$2,
    );
  }

  Map<String, dynamic> toUpsertJson(String userId) => <String, dynamic>{
        'user_id': userId,
        'space_id': spaceId,
        'financial_reminders_enabled': financialRemindersEnabled,
        'invoices_enabled': invoicesEnabled,
        'debts_enabled': debtsEnabled,
        'recurrences_enabled': recurrencesEnabled,
        'subscriptions_enabled': subscriptionsEnabled,
        'expected_income_enabled': expectedIncomeEnabled,
        'overdue_enabled': overdueEnabled,
        'reminder_offset_days': reminderOffsetDays,
        'preferred_time': preferredTimeDb,
      };
}

class NotificationUpcomingEvent {
  const NotificationUpcomingEvent({
    required this.eventKey,
    required this.source,
    required this.sourceId,
    required this.title,
    required this.dueDate,
    required this.direction,
    required this.overdue,
    required this.navigationTarget,
    required this.dayOffset,
    required this.scheduledAt,
    required this.spaceTimezone,
    this.parentId,
    this.subtitle = '',
    this.cardId,
    this.debtId,
    this.invoiceId,
    this.recurrenceKind,
  });

  final String eventKey;
  final String source;
  final String sourceId;
  final String? parentId;
  final String title;
  final String subtitle;
  final DateTime dueDate;
  final String direction;
  final bool overdue;
  final String? cardId;
  final String? debtId;
  final String? invoiceId;
  final String navigationTarget;
  final int dayOffset;
  final String? recurrenceKind;
  final DateTime scheduledAt;
  final String spaceTimezone;

  bool get isInvoice => source == 'invoice';
  bool get isDebt => source == 'debt';
  bool get isRecurring => source == 'recurring';
  bool get isSubscription => isRecurring && recurrenceKind == 'subscription';
  bool get isRecurringIncome => isRecurring && direction == 'income';

  factory NotificationUpcomingEvent.fromJson(Map<String, dynamic> json) =>
      NotificationUpcomingEvent(
        eventKey: json['event_key'] as String,
        source: json['source'] as String? ?? 'unknown',
        sourceId: json['source_id'] as String,
        parentId: json['parent_id'] as String?,
        title: json['title'] as String? ?? 'Compromisso',
        subtitle: json['subtitle'] as String? ?? '',
        dueDate: DateTime.parse(json['due_date'] as String),
        direction: json['direction'] as String? ?? 'informational',
        overdue: json['overdue'] as bool? ?? false,
        cardId: json['card_id'] as String?,
        debtId: json['debt_id'] as String?,
        invoiceId: json['invoice_id'] as String?,
        navigationTarget: json['navigation_target'] as String? ?? 'agenda',
        dayOffset: (json['day_offset'] as num?)?.toInt() ?? 0,
        recurrenceKind: json['recurrence_kind'] as String?,
        scheduledAt: DateTime.parse(json['scheduled_at'] as String),
        spaceTimezone:
            json['space_timezone'] as String? ?? 'America/Sao_Paulo',
      );
}

class FinancialNotificationIntent {
  const FinancialNotificationIntent({
    required this.stableKey,
    required this.kind,
    required this.entityType,
    required this.entityId,
    required this.title,
    required this.body,
    required this.scheduledAt,
    required this.route,
    required this.spaceId,
  });

  final String stableKey;
  final FinancialNotificationKind kind;
  final String entityType;
  final String entityId;
  final String title;
  final String body;
  final DateTime scheduledAt;
  final String route;
  final String spaceId;

  static FinancialNotificationIntent? fromUpcoming({
    required NotificationUpcomingEvent event,
    required NotificationPreferences preferences,
  }) {
    if (!preferences.financialRemindersEnabled) return null;

    final FinancialNotificationKind kind;
    if (event.overdue) {
      if (!preferences.overdueEnabled) return null;
      kind = FinancialNotificationKind.overdue;
    } else if (event.isInvoice) {
      if (!preferences.invoicesEnabled) return null;
      kind = FinancialNotificationKind.invoice;
    } else if (event.isDebt) {
      if (!preferences.debtsEnabled) return null;
      kind = FinancialNotificationKind.debtInstallment;
    } else if (event.isSubscription) {
      if (!preferences.subscriptionsEnabled) return null;
      kind = FinancialNotificationKind.subscription;
    } else if (event.isRecurringIncome) {
      if (!preferences.expectedIncomeEnabled) return null;
      kind = FinancialNotificationKind.recurringIncome;
    } else if (event.isRecurring) {
      if (!preferences.recurrencesEnabled) return null;
      kind = FinancialNotificationKind.recurrence;
    } else {
      kind = FinancialNotificationKind.commitment;
    }

    final entityType = event.isInvoice
        ? 'invoice'
        : event.isDebt
            ? 'debt_installment'
            : event.isSubscription
                ? 'subscription'
                : event.isRecurring
                    ? 'recurring'
                    : event.source;
    return FinancialNotificationIntent(
      stableKey: financialNotificationStableKey(
        entityType: entityType,
        entityId: event.sourceId,
        dueDate: event.dueDate,
        reminderOffsetDays: preferences.reminderOffsetDays,
        kind: kind,
      ),
      kind: kind,
      entityType: entityType,
      entityId: event.sourceId,
      title: event.title,
      body: notificationBody(event),
      scheduledAt: event.scheduledAt,
      route: notificationRoute(event),
      spaceId: preferences.spaceId,
    );
  }
}

String financialNotificationStableKey({
  required String entityType,
  required String entityId,
  required DateTime dueDate,
  required int reminderOffsetDays,
  required FinancialNotificationKind kind,
}) => '$entityType:$entityId:${_dateOnly(dueDate)}:$reminderOffsetDays:${kind.name}';

String notificationBody(NotificationUpcomingEvent event) {
  if (event.overdue || event.dayOffset < 0) return '${event.title} está atrasado';
  if (event.dayOffset == 0) {
    return event.isRecurringIncome
        ? '${event.title} está previsto para hoje'
        : '${event.title} vence hoje';
  }
  if (event.dayOffset == 1) {
    return event.isRecurringIncome
        ? '${event.title} está previsto para amanhã'
        : '${event.title} vence amanhã';
  }
  return event.isRecurringIncome
      ? '${event.title} está previsto em ${event.dayOffset} dias'
      : '${event.title} vence em ${event.dayOffset} dias';
}

String notificationRoute(NotificationUpcomingEvent event) {
  if (event.isInvoice && event.cardId != null && event.invoiceId != null) {
    return '/wallet/card/${event.cardId}/invoice/${event.invoiceId}';
  }
  if (event.isDebt && event.debtId != null) return '/wallet/debt/${event.debtId}';
  if (event.isSubscription) return '/transactions/subscriptions/${event.sourceId}';
  if (event.isRecurring) return '/transactions/recurring/${event.sourceId}';
  return '/agenda';
}

(int, int) _parseTime(String? value) {
  final parts = value?.split(':') ?? const <String>[];
  if (parts.length < 2) return (9, 0);
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
    return (9, 0);
  }
  return (hour, minute);
}

String _dateOnly(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
