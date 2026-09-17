import 'dart:async';

import 'notification_models.dart';

abstract interface class NotificationSchedulerAdapter {
  Future<NotificationPermissionStatus> requestPermission();
  Future<NotificationPermissionStatus> getPermissionStatus();
  Future<List<FinancialNotificationIntent>> pendingForSpace(String spaceId);
  Future<void> schedule(FinancialNotificationIntent intent);
  Future<void> cancel(String stableKey);
  Future<void> cancelForEntity({
    required String spaceId,
    required String entityType,
    required String entityId,
  });
  Future<void> clearForSpace(String spaceId);
  Future<void> clearAll();
}

class WebSafeNoopNotificationAdapter implements NotificationSchedulerAdapter {
  const WebSafeNoopNotificationAdapter();

  @override
  Future<NotificationPermissionStatus> requestPermission() async =>
      NotificationPermissionStatus.unsupported;

  @override
  Future<NotificationPermissionStatus> getPermissionStatus() async =>
      NotificationPermissionStatus.unsupported;

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
  Future<void> clearForSpace(String spaceId) async {}

  @override
  Future<void> clearAll() async {}
}

typedef NotificationPreferencesLoader =
    Future<NotificationPreferences> Function(String spaceId);
typedef NotificationUpcomingLoader =
    Future<List<NotificationUpcomingEvent>> Function(
      String spaceId,
      NotificationPreferences preferences,
      int horizonDays,
    );
typedef NotificationOpenHandler = Future<void> Function(String route);

class NotificationService {
  NotificationService({
    required NotificationSchedulerAdapter adapter,
    required NotificationPreferencesLoader loadPreferences,
    required NotificationUpcomingLoader loadUpcoming,
    NotificationOpenHandler? onOpen,
    this.horizonDays = 30,
  })  : _adapter = adapter,
        _loadPreferences = loadPreferences,
        _loadUpcoming = loadUpcoming,
        _onOpen = onOpen;

  final NotificationSchedulerAdapter _adapter;
  final NotificationPreferencesLoader _loadPreferences;
  final NotificationUpcomingLoader _loadUpcoming;
  final NotificationOpenHandler? _onOpen;
  final int horizonDays;

  final Map<String, Future<void>> _runningSyncs = <String, Future<void>>{};
  final Set<String> _syncAgain = <String>{};

  Future<NotificationPermissionStatus> requestPermission() =>
      _adapter.requestPermission();

  Future<NotificationPermissionStatus> getPermissionStatus() =>
      _adapter.getPermissionStatus();

  Future<void> schedule(FinancialNotificationIntent intent) =>
      _adapter.schedule(intent);

  Future<void> cancel(String stableKey) => _adapter.cancel(stableKey);

  Future<void> cancelForEntity({
    required String spaceId,
    required String entityType,
    required String entityId,
  }) =>
      _adapter.cancelForEntity(
        spaceId: spaceId,
        entityType: entityType,
        entityId: entityId,
      );

  Future<void> reschedule({
    required FinancialNotificationIntent previous,
    required FinancialNotificationIntent next,
  }) async {
    if (previous.stableKey != next.stableKey) {
      await _adapter.cancel(previous.stableKey);
    }
    await _adapter.schedule(next);
  }

  Future<void> syncUpcoming(String spaceId) {
    final running = _runningSyncs[spaceId];
    if (running != null) {
      _syncAgain.add(spaceId);
      return running;
    }

    late final Future<void> future;
    future = _syncLoop(spaceId).whenComplete(() {
      if (identical(_runningSyncs[spaceId], future)) {
        _runningSyncs.remove(spaceId);
      }
    });
    _runningSyncs[spaceId] = future;
    return future;
  }

  Future<void> _syncLoop(String spaceId) async {
    do {
      _syncAgain.remove(spaceId);
      await _syncOnce(spaceId);
    } while (_syncAgain.remove(spaceId));
  }

  Future<void> _syncOnce(String spaceId) async {
    // Check the platform adapter first. This keeps web/no-op builds side-effect
    // free and avoids unnecessary financial reads when OS notifications cannot
    // be scheduled on the current target.
    final permission = await _adapter.getPermissionStatus();
    if (permission != NotificationPermissionStatus.granted) {
      await _adapter.clearForSpace(spaceId);
      return;
    }

    final preferences = await _loadPreferences(spaceId);
    if (!preferences.financialRemindersEnabled) {
      await _adapter.clearForSpace(spaceId);
      return;
    }

    final events = await _loadUpcoming(spaceId, preferences, horizonDays);
    final desired = <String, FinancialNotificationIntent>{};
    for (final event in events) {
      final intent = FinancialNotificationIntent.fromUpcoming(
        event: event,
        preferences: preferences,
      );
      if (intent != null) desired[intent.stableKey] = intent;
    }

    final pending = await _adapter.pendingForSpace(spaceId);
    for (final existing in pending) {
      if (!desired.containsKey(existing.stableKey)) {
        await _adapter.cancel(existing.stableKey);
      }
    }
    for (final intent in desired.values) {
      await _adapter.schedule(intent);
    }
  }

  Future<void> handleOpen(String route) async {
    final handler = _onOpen;
    if (handler != null) await handler(route.trim().isEmpty ? '/agenda' : route);
  }

  Future<void> clearForLogout() async {
    _syncAgain.clear();
    await _adapter.clearAll();
  }

  Future<void> clearForSpaceChange(String previousSpaceId) async {
    _syncAgain.remove(previousSpaceId);
    await _adapter.clearForSpace(previousSpaceId);
  }
}
