import 'dart:async';

import 'package:flutter/material.dart';
import 'package:folego/shared/widgets/activity_inbox_bell.dart';
import 'package:folego/features/profile/capture_review_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/notifications/notification_models.dart';
import 'package:folego/data/repositories/folego_repository.dart';
import 'package:folego/features/profile/notification_history_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _Repository implements FolegoRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });
  testWidgets(
    'filters keep review receipts distinct from confirmed transactions',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final items = [
        NotificationHistoryItem(
          id: 1,
          kind: 'newTransaction',
          title: 'transação nova',
          body: 'R\$ 10',
          route: '/transactions/a',
          deliveredAt: DateTime.utc(2026, 10, 16),
        ),
        NotificationHistoryItem(
          id: 2,
          kind: 'captureNeedsReview',
          title: 'comprovante pendente',
          body: 'sem lançamento confirmado',
          route: '/captures/b',
          deliveredAt: DateTime.utc(2026, 10, 16),
        ),
        NotificationHistoryItem(
          id: 3,
          kind: 'newTransaction',
          title: 'transação anterior',
          body: '',
          route: '/transactions/c',
          deliveredAt: DateTime.utc(2026, 10, 15),
          seenAt: DateTime.utc(2026, 10, 16),
        ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: NotificationHistoryScreen(
            repository: _Repository(),
            spaceId: 'space-a',
            authenticatedUserId: () => 'user-a',
            historyLoader: (_) async => items,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'pendentes'));
      await tester.pumpAndSettle();
      expect(find.text('comprovante pendente'), findsOneWidget);
      expect(find.text('transação nova'), findsNothing);
      expect(find.text('conferir comprovante'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'novas'));
      await tester.pumpAndSettle();
      expect(find.text('transação nova'), findsOneWidget);
      expect(find.text('transação anterior'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('mark read writes only selected space and stable key', (
    tester,
  ) async {
    var read = false;
    final calls = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: NotificationHistoryScreen(
          repository: _Repository(),
          spaceId: 'space-a',
          authenticatedUserId: () => 'user-a',
          historyLoader: (_) async => [
            NotificationHistoryItem(
              id: 1,
              kind: 'newTransaction',
              title: 'novo',
              body: '',
              route: '/transactions/a',
              stableKey: 'newTx:a',
              deliveredAt: DateTime.utc(2026, 10, 16),
              seenAt: read ? DateTime.utc(2026, 10, 16) : null,
            ),
          ],
          notificationReadWriter: (space, key) async {
            calls.add('$space/$key');
            read = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('marcar como lida'));
    await tester.pumpAndSettle();
    expect(calls, ['space-a/newTx:a']);
    expect(find.byTooltip('marcar como lida'), findsNothing);
    expect(find.text('anteriores'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'badge uses exact count and rejects late response from previous space',
    (tester) async {
      final requests = {
        'space-a': Completer<int>(),
        'space-b': Completer<int>(),
      };
      final repository = _Repository();
      Future<int> load(String space) => requests[space]!.future;
      String? user() => 'user-a';
      Widget bell(String space) => MaterialApp(
        home: Scaffold(
          body: ActivityInboxBell(
            repository: repository,
            spaceId: space,
            unreadLoader: load,
            authenticatedUserId: user,
            onOpen: (_) async {},
          ),
        ),
      );
      await tester.pumpWidget(bell('space-a'));
      await tester.pumpWidget(bell('space-b'));
      requests['space-b']!.complete(281);
      await tester.pumpAndSettle();
      expect(find.byTooltip('notificações · 281 não lidas'), findsOneWidget);
      expect(find.text('99+'), findsOneWidget);
      requests['space-a']!.complete(0);
      await tester.pumpAndSettle();
      expect(find.byTooltip('notificações · 281 não lidas'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('bell tolerates screens without initialized Supabase', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ActivityInboxBell(repository: _Repository(), spaceId: 'demo'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test('all backend receipt reasons have human copy and unknown reasons stay neutral', () {
    for (final reason in [
      'multiple_compatible_events',
      'direction_unknown',
      'scan_limit',
      'existing_confirmed_event',
      'counterparty_mismatch',
      'context_unknown',
      'future_machine_code',
    ]) {
      expect(captureReviewReason(reason, null), isNot(contains(reason)));
    }
  });
  test('receipt direction maps backend in/out and excludes unknown or internal transfer', () {
    expect(captureSuggestionEventType('in', {}), 'income');
    expect(captureSuggestionEventType('out', {}), 'expense');
    expect(captureSuggestionEventType('unknown', {}), isNull);
    expect(
      captureSuggestionEventType('in', {'is_internal_transfer': true}),
      isNull,
    );
    expect(
      captureSuggestionEventType('out', {'event_type': 'transfer'}),
      isNull,
    );
  });
}
