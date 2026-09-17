import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/notifications/notification_models.dart';

void main() {
  NotificationUpcomingEvent event({
    String source = 'recurring',
    String sourceId = 'source-1',
    String direction = 'outflow',
    String? recurrenceKind,
    bool overdue = false,
    int dayOffset = 1,
    String navigationTarget = 'recurring',
    String? cardId,
    String? debtId,
    String? invoiceId,
  }) =>
      NotificationUpcomingEvent(
        eventKey: 'event-$sourceId',
        source: source,
        sourceId: sourceId,
        title: 'Internet',
        dueDate: DateTime(2026, 9, 18),
        direction: direction,
        overdue: overdue,
        navigationTarget: navigationTarget,
        dayOffset: dayOffset,
        recurrenceKind: recurrenceKind,
        cardId: cardId,
        debtId: debtId,
        invoiceId: invoiceId,
        scheduledAt: DateTime.utc(2026, 9, 17, 12),
        spaceTimezone: 'America/Sao_Paulo',
      );

  const enabled = NotificationPreferences(
    spaceId: 'space-1',
    financialRemindersEnabled: true,
  );

  test('stable key is deterministic and contains no financial amount', () {
    final key = financialNotificationStableKey(
      entityType: 'recurring',
      entityId: 'abc',
      dueDate: DateTime(2026, 9, 18),
      reminderOffsetDays: 1,
      kind: FinancialNotificationKind.recurrence,
    );

    expect(key, 'recurring:abc:2026-09-18:1:recurrence');
    expect(key, isNot(contains('R\$')));
  });

  test('subscription uses recurring_items kind and subscription deep link', () {
    final intent = FinancialNotificationIntent.fromUpcoming(
      event: event(recurrenceKind: 'subscription'),
      preferences: enabled,
    );

    expect(intent, isNotNull);
    expect(intent!.kind, FinancialNotificationKind.subscription);
    expect(intent.entityType, 'subscription');
    expect(intent.route, '/transactions/subscriptions/source-1');
    expect(intent.body, isNot(contains('25')));
  });

  test('invoice, debt and recurrence routes remain deterministic', () {
    final invoice = FinancialNotificationIntent.fromUpcoming(
      event: event(
        source: 'invoice',
        sourceId: 'invoice-1',
        cardId: 'card-1',
        invoiceId: 'invoice-1',
        navigationTarget: 'card_invoice',
      ),
      preferences: enabled,
    );
    final debt = FinancialNotificationIntent.fromUpcoming(
      event: event(
        source: 'debt',
        sourceId: 'installment-1',
        debtId: 'debt-1',
        navigationTarget: 'debt',
      ),
      preferences: enabled,
    );
    final recurring = FinancialNotificationIntent.fromUpcoming(
      event: event(sourceId: 'rent-1'),
      preferences: enabled,
    );

    expect(invoice!.kind, FinancialNotificationKind.invoice);
    expect(invoice.route, '/wallet/card/card-1/invoice/invoice-1');
    expect(debt!.kind, FinancialNotificationKind.debtInstallment);
    expect(debt.route, '/wallet/debt/debt-1');
    expect(recurring!.kind, FinancialNotificationKind.recurrence);
    expect(recurring.route, '/transactions/recurring/rent-1');
  });

  test('recurring income becomes expected-income reminder', () {
    final intent = FinancialNotificationIntent.fromUpcoming(
      event: event(direction: 'income', dayOffset: 3),
      preferences: enabled.copyWith(reminderOffsetDays: 3),
    );

    expect(intent!.kind, FinancialNotificationKind.recurringIncome);
    expect(intent.body, 'Internet está previsto em 3 dias');
  });

  test('overdue wins over source kind and respects overdue preference', () {
    final overdueEvent = event(
      source: 'invoice',
      overdue: true,
      dayOffset: -2,
      cardId: 'card-1',
      invoiceId: 'invoice-1',
    );
    final intent = FinancialNotificationIntent.fromUpcoming(
      event: overdueEvent,
      preferences: enabled,
    );
    final disabled = FinancialNotificationIntent.fromUpcoming(
      event: overdueEvent,
      preferences: enabled.copyWith(overdueEnabled: false),
    );

    expect(intent!.kind, FinancialNotificationKind.overdue);
    expect(intent.body, 'Internet está atrasado');
    expect(disabled, isNull);
  });

  test('delivery copy follows 0, 1 and 3 day reminder lead time', () {
    final futureEvent = event(dayOffset: 8);

    expect(
      FinancialNotificationIntent.fromUpcoming(
        event: futureEvent,
        preferences: enabled.copyWith(reminderOffsetDays: 0),
      )!.body,
      'Internet vence hoje',
    );
    expect(
      FinancialNotificationIntent.fromUpcoming(
        event: futureEvent,
        preferences: enabled.copyWith(reminderOffsetDays: 1),
      )!.body,
      'Internet vence amanhã',
    );
    expect(
      FinancialNotificationIntent.fromUpcoming(
        event: futureEvent,
        preferences: enabled.copyWith(reminderOffsetDays: 3),
      )!.body,
      'Internet vence em 3 dias',
    );
  });

  test('lead copy never claims more days than remain until due date', () {
    final tomorrow = event(dayOffset: 1);
    final intent = FinancialNotificationIntent.fromUpcoming(
      event: tomorrow,
      preferences: enabled.copyWith(reminderOffsetDays: 3),
    );
    expect(intent!.body, 'Internet vence amanhã');
  });

  test('individual notification preferences suppress their event kinds', () {
    expect(
      FinancialNotificationIntent.fromUpcoming(
        event: event(source: 'invoice'),
        preferences: enabled.copyWith(invoicesEnabled: false),
      ),
      isNull,
    );
    expect(
      FinancialNotificationIntent.fromUpcoming(
        event: event(source: 'debt'),
        preferences: enabled.copyWith(debtsEnabled: false),
      ),
      isNull,
    );
    expect(
      FinancialNotificationIntent.fromUpcoming(
        event: event(),
        preferences: enabled.copyWith(recurrencesEnabled: false),
      ),
      isNull,
    );
    expect(
      FinancialNotificationIntent.fromUpcoming(
        event: event(recurrenceKind: 'subscription'),
        preferences: enabled.copyWith(subscriptionsEnabled: false),
      ),
      isNull,
    );
    expect(
      FinancialNotificationIntent.fromUpcoming(
        event: event(direction: 'income'),
        preferences: enabled.copyWith(expectedIncomeEnabled: false),
      ),
      isNull,
    );
  });

  test('master toggle prevents intent creation', () {
    const preferences = NotificationPreferences(spaceId: 'space-1');
    expect(
      FinancialNotificationIntent.fromUpcoming(
        event: event(),
        preferences: preferences,
      ),
      isNull,
    );
  });

  test('preferred time parser falls back safely and serializes local time', () {
    final parsed = NotificationPreferences.fromJson(
      const <String, dynamic>{
        'space_id': 'space-1',
        'preferred_time': '07:45:00',
        'reminder_offset_days': 3,
      },
      fallbackSpaceId: 'fallback',
    );
    final invalid = NotificationPreferences.fromJson(
      const <String, dynamic>{'preferred_time': '99:99:00'},
      fallbackSpaceId: 'space-2',
    );

    expect(parsed.preferredHour, 7);
    expect(parsed.preferredMinute, 45);
    expect(parsed.preferredTimeDb, '07:45:00');
    expect(parsed.reminderOffsetDays, 3);
    expect(invalid.preferredHour, 9);
    expect(invalid.preferredMinute, 0);
  });
}
