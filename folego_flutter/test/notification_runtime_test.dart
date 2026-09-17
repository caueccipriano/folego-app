import 'package:flutter_test/flutter_test.dart';
import 'package:folego_flutter/core/notifications/notification_models.dart';
import 'package:folego_flutter/core/notifications/notification_runtime.dart';
import 'package:folego_flutter/core/notifications/notification_service.dart';

class _RuntimeAdapter implements NotificationSchedulerAdapter {
  final List<String> clearedSpaces = <String>[];
  int clearAllCount = 0;

  @override
  Future<NotificationPermissionStatus> getPermissionStatus() async =>
      NotificationPermissionStatus.granted;
  @override
  Future<NotificationPermissionStatus> requestPermission() async =>
      NotificationPermissionStatus.granted;
  @override
  Future<List<FinancialNotificationIntent>> pendingForSpace(String spaceId) async =>
      const <FinancialNotificationIntent>[];
  @override
  Future<void> schedule(FinancialNotificationIntent intent) async {}
  @override
  Future<void> cancel(String stableKey) async {}
  @override
  Future<void> cancelForEntity({
    required String spaceId,
    required String entityType,
    required String entityId,
  }) async {}
  @override
  Future<void> clearForSpace(String spaceId) async => clearedSpaces.add(spaceId);
  @override
  Future<void> clearAll() async => clearAllCount += 1;
}

void main() {
  test('space switch clears old namespace before syncing new space', () async {
    final adapter = _RuntimeAdapter();
    final syncs = <String>[];
    final service = NotificationService(
      adapter: adapter,
      loadPreferences: (spaceId) async {
        syncs.add(spaceId);
        return NotificationPreferences(
          spaceId: spaceId,
          financialRemindersEnabled: true,
        );
      },
      loadUpcoming: (_, __, ___) async => const <NotificationUpcomingEvent>[],
    );
    final runtime = NotificationRuntimeController(service);

    await runtime.activateSpace('one');
    await runtime.activateSpace('two');

    expect(syncs, <String>['one', 'two']);
    expect(adapter.clearedSpaces, <String>['one']);
    expect(runtime.activeSpaceId, 'two');
  });

  test('sign out clears scheduled notifications and active space', () async {
    final adapter = _RuntimeAdapter();
    final service = NotificationService(
      adapter: adapter,
      loadPreferences: (spaceId) async => NotificationPreferences(
        spaceId: spaceId,
        financialRemindersEnabled: true,
      ),
      loadUpcoming: (_, __, ___) async => const <NotificationUpcomingEvent>[],
    );
    final runtime = NotificationRuntimeController(service);

    await runtime.activateSpace('one');
    await runtime.onSignedOut();

    expect(adapter.clearAllCount, 1);
    expect(runtime.activeSpaceId, isNull);
  });
}
