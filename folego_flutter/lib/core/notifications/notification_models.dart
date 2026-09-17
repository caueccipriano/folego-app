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
  cardLimitThreshold,
  largeExpense,
  dailySummary,
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
    this.planThresholdsEnabled = true,
    this.cardLimitThresholdsEnabled = true,
    this.largeExpensesEnabled = false,
    this.largeExpenseThreshold = 200,
    this.dailySummaryEnabled = true,
    this.dailySummaryHour = 9,
    this.dailySummaryMinute = 0,
    this.quietHoursEnabled = true,
    this.quietStartHour = 22,
    this.quietStartMinute = 0,
    this.quietEndHour = 8,
    this.quietEndMinute = 0,
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
  final bool planThresholdsEnabled;
  final bool cardLimitThresholdsEnabled;
  final bool largeExpensesEnabled;
  final double largeExpenseThreshold;
  final bool dailySummaryEnabled;
  final int dailySummaryHour;
  final int dailySummaryMinute;
  final bool quietHoursEnabled;
  final int quietStartHour;
  final int quietStartMinute;
  final int quietEndHour;
  final int quietEndMinute;
  final int reminderOffsetDays;
  final int preferredHour;
  final int preferredMinute;

  String get preferredTimeDb => _dbTime(preferredHour, preferredMinute);
  String get dailySummaryTimeDb => _dbTime(dailySummaryHour, dailySummaryMinute);
  String get quietStartTimeDb => _dbTime(quietStartHour, quietStartMinute);
  String get quietEndTimeDb => _dbTime(quietEndHour, quietEndMinute);

  NotificationPreferences copyWith({
    bool? financialRemindersEnabled,
    bool? invoicesEnabled,
    bool? debtsEnabled,
    bool? recurrencesEnabled,
    bool? subscriptionsEnabled,
    bool? expectedIncomeEnabled,
    bool? overdueEnabled,
    bool? planThresholdsEnabled,
    bool? cardLimitThresholdsEnabled,
    bool? largeExpensesEnabled,
    double? largeExpenseThreshold,
    bool? dailySummaryEnabled,
    int? dailySummaryHour,
    int? dailySummaryMinute,
    bool? quietHoursEnabled,
    int? quietStartHour,
    int? quietStartMinute,
    int? quietEndHour,
    int? quietEndMinute,
    int? reminderOffsetDays,
    int? preferredHour,
    int? preferredMinute,
  }) =>
      NotificationPreferences(
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
        planThresholdsEnabled:
            planThresholdsEnabled ?? this.planThresholdsEnabled,
        cardLimitThresholdsEnabled:
            cardLimitThresholdsEnabled ?? this.cardLimitThresholdsEnabled,
        largeExpensesEnabled:
            largeExpensesEnabled ?? this.largeExpensesEnabled,
        largeExpenseThreshold:
            largeExpenseThreshold ?? this.largeExpenseThreshold,
        dailySummaryEnabled: dailySummaryEnabled ?? this.dailySummaryEnabled,
        dailySummaryHour: dailySummaryHour ?? this.dailySummaryHour,
        dailySummaryMinute: dailySummaryMinute ?? this.dailySummaryMinute,
        quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
        quietStartHour: quietStartHour ?? this.quietStartHour,
        quietStartMinute: quietStartMinute ?? this.quietStartMinute,
        quietEndHour: quietEndHour ?? this.quietEndHour,
        quietEndMinute: quietEndMinute ?? this.quietEndMinute,
        reminderOffsetDays: reminderOffsetDays ?? this.reminderOffsetDays,
        preferredHour: preferredHour ?? this.preferredHour,
        preferredMinute: preferredMinute ?? this.preferredMinute,
      );

  factory NotificationPreferences.fromJson(
    Map<String, dynamic> json, {
    required String fallbackSpaceId,
  }) {
    final preferred = _parseTime(json['preferred_time'] as String?);
    final daily = _parseTime(
      json['daily_summary_time'] as String?,
      fallbackHour: 9,
    );
    final quietStart = _parseTime(
      json['quiet_hours_start'] as String?,
      fallbackHour: 22,
    );
    final quietEnd = _parseTime(
      json['quiet_hours_end'] as String?,
      fallbackHour: 8,
    );
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
      planThresholdsEnabled: json['plan_thresholds_enabled'] as bool? ?? true,
      cardLimitThresholdsEnabled:
          json['card_limit_thresholds_enabled'] as bool? ?? true,
      largeExpensesEnabled: json['large_expenses_enabled'] as bool? ?? false,
      largeExpenseThreshold:
          (json['large_expense_threshold'] as num?)?.toDouble() ?? 200,
      dailySummaryEnabled: json['daily_summary_enabled'] as bool? ?? true,
      dailySummaryHour: daily.$1,
      dailySummaryMinute: daily.$2,
      quietHoursEnabled: json['quiet_hours_enabled'] as bool? ?? true,
      quietStartHour: quietStart.$1,
      quietStartMinute: quietStart.$2,
      quietEndHour: quietEnd.$1,
      quietEndMinute: quietEnd.$2,
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
        'plan_thresholds_enabled': planThresholdsEnabled,
        'card_limit_thresholds_enabled': cardLimitThresholdsEnabled,
        'large_expenses_enabled': largeExpensesEnabled,
        'large_expense_threshold': largeExpenseThreshold,
        'daily_summary_enabled': dailySummaryEnabled,
        'daily_summary_time': dailySummaryTimeDb,
        'quiet_hours_enabled': quietHoursEnabled,
        'quiet_hours_start': quietStartTimeDb,
        'quiet_hours_end': quietEndTimeDb,
        'reminder_offset_days': reminderOffsetDays,
        'preferred_time': preferredTimeDb,
      };
}

class NotificationHistoryItem {
  const NotificationHistoryItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.route,
    required this.deliveredAt,
  });

  final int id;
  final String kind;
  final String title;
  final String body;
  final String route;
  final DateTime deliveredAt;

  factory NotificationHistoryItem.fromJson(Map<String, dynamic> json) =>
      NotificationHistoryItem(
        id: (json['id'] as num).toInt(),
        kind: json['kind'] as String? ?? 'notification',
        title: json['title'] as String? ?? 'Fôlego',
        body: json['body'] as String? ?? '',
        route: json['route'] as String? ?? '/',
        deliveredAt: DateTime.parse(json['delivered_at'] as String),
      );
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
      body: notificationBody(
        event,
        reminderOffsetDays: preferences.reminderOffsetDays,
      ),
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

String notificationBody(
  NotificationUpcomingEvent event, {
  int reminderOffsetDays = 0,
}) {
  if (event.overdue || event.dayOffset < 0) return '${event.title} está atrasado';
  final leadDays = event.dayOffset < reminderOffsetDays
      ? event.dayOffset
      : reminderOffsetDays;
  if (leadDays <= 0) {
    return event.isRecurringIncome
        ? '${event.title} está previsto para hoje'
        : '${event.title} vence hoje';
  }
  if (leadDays == 1) {
    return event.isRecurringIncome
        ? '${event.title} está previsto para amanhã'
        : '${event.title} vence amanhã';
  }
  return event.isRecurringIncome
      ? '${event.title} está previsto em $leadDays dias'
      : '${event.title} vence em $leadDays dias';
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

(int, int) _parseTime(
  String? value, {
  int fallbackHour = 9,
  int fallbackMinute = 0,
}) {
  final parts = value?.split(':') ?? const <String>[];
  if (parts.length < 2) return (fallbackHour, fallbackMinute);
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null ||
      minute == null ||
      hour < 0 ||
      hour > 23 ||
      minute < 0 ||
      minute > 59) {
    return (fallbackHour, fallbackMinute);
  }
  return (hour, minute);
}

String _dbTime(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:00';

String _dateOnly(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
