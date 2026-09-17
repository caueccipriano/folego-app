import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/notifications/notification_models.dart';

void main() {
  group('NotificationPreferences hardening', () {
    test('parses daily summary and quiet-hour preferences', () {
      final preferences = NotificationPreferences.fromJson(
        <String, dynamic>{
          'space_id': 'space-1',
          'financial_reminders_enabled': true,
          'daily_summary_enabled': false,
          'daily_summary_time': '07:35:00',
          'quiet_hours_enabled': true,
          'quiet_hours_start': '23:15:00',
          'quiet_hours_end': '06:45:00',
          'preferred_time': '10:20:00',
          'reminder_offset_days': 3,
        },
        fallbackSpaceId: 'fallback',
      );

      expect(preferences.spaceId, 'space-1');
      expect(preferences.dailySummaryEnabled, isFalse);
      expect(preferences.dailySummaryHour, 7);
      expect(preferences.dailySummaryMinute, 35);
      expect(preferences.quietHoursEnabled, isTrue);
      expect(preferences.quietStartHour, 23);
      expect(preferences.quietStartMinute, 15);
      expect(preferences.quietEndHour, 6);
      expect(preferences.quietEndMinute, 45);
      expect(preferences.preferredHour, 10);
      expect(preferences.preferredMinute, 20);
      expect(preferences.reminderOffsetDays, 3);
    });

    test('serializes server-side delivery controls', () {
      const preferences = NotificationPreferences(
        spaceId: 'space-1',
        financialRemindersEnabled: true,
        dailySummaryEnabled: true,
        dailySummaryHour: 8,
        dailySummaryMinute: 5,
        quietHoursEnabled: true,
        quietStartHour: 22,
        quietStartMinute: 30,
        quietEndHour: 7,
        quietEndMinute: 15,
        largeExpensesEnabled: true,
        largeExpenseThreshold: 350,
      );

      final json = preferences.toUpsertJson('user-1');
      expect(json['user_id'], 'user-1');
      expect(json['space_id'], 'space-1');
      expect(json['daily_summary_enabled'], isTrue);
      expect(json['daily_summary_time'], '08:05:00');
      expect(json['quiet_hours_enabled'], isTrue);
      expect(json['quiet_hours_start'], '22:30:00');
      expect(json['quiet_hours_end'], '07:15:00');
      expect(json['large_expenses_enabled'], isTrue);
      expect(json['large_expense_threshold'], 350);
    });

    test('falls back safely when a stored time is invalid', () {
      final preferences = NotificationPreferences.fromJson(
        <String, dynamic>{
          'daily_summary_time': '99:99:00',
          'quiet_hours_start': 'invalid',
          'quiet_hours_end': null,
        },
        fallbackSpaceId: 'space-1',
      );

      expect(preferences.dailySummaryHour, 9);
      expect(preferences.dailySummaryMinute, 0);
      expect(preferences.quietStartHour, 22);
      expect(preferences.quietStartMinute, 0);
      expect(preferences.quietEndHour, 8);
      expect(preferences.quietEndMinute, 0);
    });
  });

  group('Notification history', () {
    test('parses delivered notification rows', () {
      final item = NotificationHistoryItem.fromJson(<String, dynamic>{
        'id': 42,
        'kind': 'dailySummary',
        'title': 'Seu Fôlego de hoje',
        'body': 'R\$ 500 livres',
        'route': '/',
        'delivered_at': '2026-09-17T09:00:00-03:00',
      });

      expect(item.id, 42);
      expect(item.kind, 'dailySummary');
      expect(item.title, 'Seu Fôlego de hoje');
      expect(item.body, 'R\$ 500 livres');
      expect(item.route, '/');
      expect(item.deliveredAt.isUtc, isTrue);
    });
  });
}
