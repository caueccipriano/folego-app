import 'package:flutter_test/flutter_test.dart';
import 'package:folego_flutter/core/notifications/notification_models.dart';

void main() {
  NotificationUpcomingEvent event({
    String source = 'recurring',
    String direction = 'outflow',
    String? recurrenceKind,
    bool overdue = false,
    int dayOffset = 1,
  }) => NotificationUpcomingEvent(
        eventKey: 'event-1',
        source: source,
        sourceId: 'source-1',
        title: 'Internet',
        dueDate: DateTime(2026, 9, 18),
        direction: direction,
        overdue: overdue,
        navigationTarget: 'recurring',
        dayOffset: dayOffset,
        recurrenceKind: recurrenceKind,
        scheduledAt: DateTime.utc(2026, 9, 17, 12),
        spaceTimezone: 'America/Sao_Paulo',
      );

  test('stable key is deterministic and contains no amount', () {
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

  test('subscription respects its own preference and deep link', () {
    const preferences = NotificationPreferences(
      spaceId: 'space-1',
      financialRemindersEnabled: true,
      subscriptionsEnabled: true,
    );
    final intent = FinancialNotificationIntent.fromUpcoming(
      event: event(recurrenceKind: 'subscription'),
      preferences: preferences,
    );

    expect(intent, isNotNull);
    expect(intent!.kind, FinancialNotificationKind.subscription);
    expect(intent.route, '/transactions/subscriptions/source-1');
    expect(intent.body, isNot(contains('25')));
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
}
