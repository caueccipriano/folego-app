import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/realtime/realtime_invalidation.dart';
import 'package:folego/core/realtime/realtime_session.dart';

void main() {
  testWidgets('multiple realtime changes collapse into one domain refresh', (
    tester,
  ) async {
    final coordinator = RealtimeInvalidationCoordinator();
    var refreshes = 0;
    final binding = coordinator.bind(
      domain: AppRealtimeDomain.transactions,
      onRefresh: () async => refreshes += 1,
    );

    coordinator.invalidate(AppRealtimeDomain.transactions);
    coordinator.invalidate(AppRealtimeDomain.transactions);
    coordinator.invalidate(AppRealtimeDomain.transactions);

    await tester.pump(const Duration(milliseconds: 249));
    expect(refreshes, 0);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(refreshes, 1);

    binding.dispose();
    coordinator.dispose();
  });

  testWidgets('change during refresh produces at most one required rerun', (
    tester,
  ) async {
    final coordinator = RealtimeInvalidationCoordinator();
    final firstRefresh = Completer<void>();
    var refreshes = 0;
    final binding = coordinator.bind(
      domain: AppRealtimeDomain.wallet,
      onRefresh: () async {
        refreshes += 1;
        if (refreshes == 1) await firstRefresh.future;
      },
    );

    coordinator.invalidate(AppRealtimeDomain.wallet);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    expect(refreshes, 1);

    coordinator.invalidate(AppRealtimeDomain.wallet);
    coordinator.invalidate(AppRealtimeDomain.wallet);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    expect(refreshes, 1);

    firstRefresh.complete();
    await tester.pump();
    await tester.pump();
    expect(refreshes, 2);

    binding.dispose();
    coordinator.dispose();
  });

  testWidgets('inactive binding stays dirty and refreshes once when activated', (
    tester,
  ) async {
    final coordinator = RealtimeInvalidationCoordinator();
    var refreshes = 0;
    final binding = coordinator.bind(
      domain: AppRealtimeDomain.plan,
      active: false,
      onRefresh: () async => refreshes += 1,
    );

    coordinator.invalidate(AppRealtimeDomain.plan);
    coordinator.invalidate(AppRealtimeDomain.plan);
    await tester.pump(const Duration(milliseconds: 250));
    expect(refreshes, 0);

    binding.setActive(true);
    await tester.pump();
    expect(refreshes, 1);

    binding.dispose();
    coordinator.dispose();
  });

  testWidgets('removed binding and disposed coordinator leave no pending refresh', (
    tester,
  ) async {
    final coordinator = RealtimeInvalidationCoordinator();
    var refreshes = 0;
    final binding = coordinator.bind(
      domain: AppRealtimeDomain.diary,
      onRefresh: () async => refreshes += 1,
    );

    coordinator.invalidate(AppRealtimeDomain.diary);
    binding.dispose();
    coordinator.dispose();
    await tester.pump(const Duration(seconds: 1));

    expect(refreshes, 0);
  });

  testWidgets('session switches space, disposes old source and ignores old events', (
    tester,
  ) async {
    final source = _FakeRealtimeEventSource();
    final coordinator = RealtimeInvalidationCoordinator();
    final session = RealtimeSessionController(
      coordinator: coordinator,
      eventSource: source,
    );
    var transactionRefreshes = 0;
    final binding = coordinator.bind(
      domain: AppRealtimeDomain.transactions,
      onRefresh: () async => transactionRefreshes += 1,
    );

    await session.switchSpace('space-a');
    final old = source.subscriptions.single;
    old.emit('financial_events');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    expect(transactionRefreshes, 1);

    await session.switchSpace('space-b');
    expect(old.disposed, isTrue);
    expect(source.subscriptions.length, 2);

    old.emit('financial_events');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    expect(transactionRefreshes, 1);

    source.subscriptions.last.emit('financial_events');
    source.subscriptions.last.emit('financial_impacts');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    expect(transactionRefreshes, 2);

    binding.dispose();
    await session.dispose();
    expect(source.subscriptions.last.disposed, isTrue);
  });
}

class _FakeRealtimeEventSource implements AppRealtimeEventSource {
  final List<_FakeRealtimeSubscription> subscriptions = [];

  @override
  AppRealtimeSubscription subscribe({
    required String spaceId,
    required void Function(String table) onTableChanged,
  }) {
    final subscription = _FakeRealtimeSubscription(
      spaceId: spaceId,
      onTableChanged: onTableChanged,
    );
    subscriptions.add(subscription);
    return subscription;
  }
}

class _FakeRealtimeSubscription implements AppRealtimeSubscription {
  _FakeRealtimeSubscription({
    required this.spaceId,
    required this.onTableChanged,
  });

  final String spaceId;
  final void Function(String table) onTableChanged;
  bool disposed = false;

  void emit(String table) => onTableChanged(table);

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}
