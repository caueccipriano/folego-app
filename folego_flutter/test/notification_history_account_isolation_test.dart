import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/notifications/notification_history_cache.dart';
import 'package:folego/core/notifications/notification_models.dart';
import 'package:folego/data/repositories/folego_repository.dart';
import 'package:folego/features/profile/notification_history_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

NotificationHistoryItem _item(String title, int id) => NotificationHistoryItem(
      id: id,
      kind: 'dailySummary',
      title: title,
      body: 'Saldo pessoal: R\$ 42,00',
      route: '/',
      deliveredAt: DateTime.utc(2026, 10, 9, 17),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('cache never exposes one signed-in user to another in the same space',
      () async {
    final cache = NotificationHistoryCache();
    await cache.save('shared-space', [_item('Aviso de A', 1)], userId: 'user-a');

    expect((await cache.load('shared-space', userId: 'user-a')).single.title,
        'Aviso de A');
    expect(await cache.load('shared-space', userId: 'user-b'), isEmpty);
    expect(await cache.load('other-space', userId: 'user-a'), isEmpty);

    await cache.save('shared-space', [_item('Aviso de B', 2)],
        userId: 'user-b');
    expect((await cache.load('shared-space', userId: 'user-a')).single.title,
        'Aviso de A');
    expect((await cache.load('shared-space', userId: 'user-b')).single.title,
        'Aviso de B');
  });

  test('old space-only cached financial text is not migrated or shown',
      () async {
    final preferences = SharedPreferencesAsync();
    await preferences.setString(
      'folego.notification_history.shared-space',
      jsonEncode([
        {
          'id': 7,
          'kind': 'dailySummary',
          'title': 'Aviso legado confidencial',
          'body': 'R\$ 800',
          'route': '/',
          'delivered_at': '2026-10-09T15:00:00Z',
        },
      ]),
    );
    final cache = NotificationHistoryCache(preferences: preferences);
    expect(await cache.load('shared-space', userId: 'user-b'), isEmpty);
    expect(await cache.load('shared-space', userId: ''), isEmpty);
    await cache.save('shared-space', [_item('Não salvar', 3)], userId: '');
    expect(await cache.load('shared-space', userId: ''), isEmpty);
  });

  testWidgets('late response from previous space cannot replace next history',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final requests = <String, Completer<List<NotificationHistoryItem>>>{
      'space-a': Completer<List<NotificationHistoryItem>>(),
      'space-b': Completer<List<NotificationHistoryItem>>(),
    };
    final repository = _DelayedHistoryRepository(requests);
    String? currentUser() => 'same-user';

    Widget screen(String spaceId) => MaterialApp(
          home: NotificationHistoryScreen(
            repository: repository,
            spaceId: spaceId,
            authenticatedUserId: currentUser,
            cache: NotificationHistoryCache(),
          ),
        );

    await tester.pumpWidget(screen('space-a'));
    await tester.pump();
    await tester.pumpWidget(screen('space-b'));
    await tester.pump();

    requests['space-a']!.complete([_item('Aviso exclusivo A', 1)]);
    await tester.pump();
    await tester.pump();
    expect(find.text('Aviso exclusivo A'), findsNothing);

    requests['space-b']!.complete([_item('Aviso exclusivo B', 2)]);
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('Aviso exclusivo A'), findsNothing);
    expect(find.text('Aviso exclusivo B'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('signed-out device cannot open the offline notification cache',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final cache = NotificationHistoryCache();
    await cache.save('space', [_item('Privado offline', 10)], userId: 'user-a');
    final requests = <String, Completer<List<NotificationHistoryItem>>>{
      'space': Completer<List<NotificationHistoryItem>>(),
    };
    await tester.pumpWidget(MaterialApp(
      home: NotificationHistoryScreen(
        repository: _DelayedHistoryRepository(requests),
        spaceId: 'space',
        authenticatedUserId: () => null,
        cache: cache,
      ),
    ));
    await tester.pump();

    expect(find.text('Privado offline'), findsNothing);
    expect(find.text('entre na sua conta para consultar o histórico'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _DelayedHistoryRepository implements FolegoRepository {
  _DelayedHistoryRepository(this.requests);

  final Map<String, Completer<List<NotificationHistoryItem>>> requests;

  @override
  Future<List<NotificationHistoryItem>> getNotificationHistory(
    String spaceId, {
    int limit = 100,
  }) => requests[spaceId]!.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
