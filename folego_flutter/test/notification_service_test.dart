import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/notifications/notification_models.dart';
import 'package:folego/core/notifications/notification_service.dart';

class _FakeAdapter implements NotificationSchedulerAdapter {
  NotificationPermissionStatus permission = NotificationPermissionStatus.granted;
  final Map<String, FinancialNotificationIntent> pending =
      <String, FinancialNotificationIntent>{};
  int clearSpaceCalls = 0;
  int clearAllCalls = 0;

  @override
  Future<NotificationPermissionStatus> getPermissionStatus() async => permission;

  @override
  Future<NotificationPermissionStatus> requestPermission() async => permission;

  @override
  Future<List<FinancialNotificationIntent>> pendingForSpace(String spaceId) async =>
      pending.values.where((item) => item.spaceId == spaceId).toList();

  @override
  Future<void> schedule(FinancialNotificationIntent intent) async {
    pending[intent.stableKey] = intent;
  }

  @override
  Future<void> cancel(String stableKey) async {
    pending.remove(stableKey);
  }

  @override
  Future<void> cancelForEntity({
    required String spaceId,
    required String entityType,
    required String entityId,
  }) async {
    pending.removeWhere(
      (_, item) =>
          item.spaceId == spaceId &&
          item.entityType == entityType &&
          item.entityId == entityId,
    );
  }

  @override
  Future<void> clearForSpace(String spaceId) async {
    clearSpaceCalls += 1;
    pending.removeWhere((_, item) => item.spaceId == spaceId);
  }

  @override
  Future<void> clearAll() async {
    clearAllCalls += 1;
    pending.clear();
  }
}

void main() {
  const preferences = NotificationPreferences(
    spaceId: 'space-1',
    financialRemindersEnabled: true,
  );
  final upcoming = NotificationUpcomingEvent(
    eventKey: 'event-1',
    source: 'debt',
    sourceId: 'installment-1',
    debtId: 'debt-1',
    title: 'Parcela',
    dueDate: DateTime(2026, 9, 18),
    direction: 'outflow',
    overdue: false,
    navigationTarget: 'debt',
    dayOffset: 1,
    scheduledAt: DateTime.utc(2026, 9, 17, 12),
    spaceTimezone: 'America/Sao_Paulo',
  );

  test('sync is idempotent by stable key', () async {
    final adapter = _FakeAdapter();
    final service = NotificationService(
      adapter: adapter,
      loadPreferences: (_) async => preferences,
      loadUpcoming: (_, _, _) async => <NotificationUpcomingEvent>[upcoming],
    );

    await service.syncUpcoming('space-1');
    await service.syncUpcoming('space-1');

    expect(adapter.pending, hasLength(1));
  });

  test('disabled master toggle clears pending notifications for space', () async {
    final adapter = _FakeAdapter();
    final service = NotificationService(
      adapter: adapter,
      loadPreferences: (_) async =>
          const NotificationPreferences(spaceId: 'space-1'),
      loadUpcoming: (_, _, _) async => <NotificationUpcomingEvent>[upcoming],
    );

    await service.syncUpcoming('space-1');

    expect(adapter.clearSpaceCalls, 1);
    expect(adapter.pending, isEmpty);
  });

  test('logout clears all scheduled state', () async {
    final adapter = _FakeAdapter();
    final service = NotificationService(
      adapter: adapter,
      loadPreferences: (_) async => preferences,
      loadUpcoming: (_, _, _) async => <NotificationUpcomingEvent>[upcoming],
    );

    await service.syncUpcoming('space-1');
    await service.clearForLogout();

    expect(adapter.clearAllCalls, 1);
    expect(adapter.pending, isEmpty);
  });
}
