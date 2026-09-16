import 'package:supabase_flutter/supabase_flutter.dart';

import 'realtime_invalidation.dart';

abstract interface class AppRealtimeSubscription {
  Future<void> dispose();
}

abstract interface class AppRealtimeEventSource {
  AppRealtimeSubscription subscribe({
    required String spaceId,
    required void Function(String table) onTableChanged,
  });
}

class SupabaseRealtimeEventSource implements AppRealtimeEventSource {
  SupabaseRealtimeEventSource(this._client);

  final SupabaseClient _client;

  @override
  AppRealtimeSubscription subscribe({
    required String spaceId,
    required void Function(String table) onTableChanged,
  }) {
    final channel = _client.channel('folego:space:$spaceId');

    for (final table in appRealtimeTableDomains.keys) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'space_id',
          value: spaceId,
        ),
        callback: (_) => onTableChanged(table),
      );
    }

    channel.subscribe();

    return _CallbackRealtimeSubscription(() async {
      await _client.removeChannel(channel);
    });
  }
}

class RealtimeSessionController {
  RealtimeSessionController({
    required this.coordinator,
    required AppRealtimeEventSource eventSource,
  }) : _eventSource = eventSource;

  final RealtimeInvalidationCoordinator coordinator;
  final AppRealtimeEventSource _eventSource;

  AppRealtimeSubscription? _subscription;
  String? _spaceId;
  int _generation = 0;
  bool _disposed = false;

  String? get spaceId => _spaceId;

  Future<void> switchSpace(String spaceId) async {
    if (_disposed) return;
    if (_spaceId == spaceId && _subscription != null) return;

    final generation = ++_generation;
    final previous = _subscription;
    _subscription = null;
    _spaceId = null;
    coordinator.cancelPending();

    if (previous != null) {
      await previous.dispose();
    }

    if (_disposed || generation != _generation) return;

    _spaceId = spaceId;
    _subscription = _eventSource.subscribe(
      spaceId: spaceId,
      onTableChanged: (table) {
        if (_disposed || _spaceId != spaceId) return;
        coordinator.invalidateDomains(domainsForRealtimeTable(table));
      },
    );
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    ++_generation;
    coordinator.cancelPending();
    final subscription = _subscription;
    _subscription = null;
    _spaceId = null;
    coordinator.dispose();
    if (subscription != null) {
      await subscription.dispose();
    }
  }
}

abstract final class AppRealtimeRegistry {
  static RealtimeInvalidationCoordinator? _coordinator;

  static RealtimeInvalidationCoordinator? get coordinator => _coordinator;

  static void attach(RealtimeInvalidationCoordinator coordinator) {
    _coordinator = coordinator;
  }

  static void detach(RealtimeInvalidationCoordinator coordinator) {
    if (identical(_coordinator, coordinator)) {
      _coordinator = null;
    }
  }
}

class _CallbackRealtimeSubscription implements AppRealtimeSubscription {
  _CallbackRealtimeSubscription(this._onDispose);

  final Future<void> Function() _onDispose;
  bool _disposed = false;

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _onDispose();
  }
}
