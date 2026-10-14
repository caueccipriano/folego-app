import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/sheet_sync_status.dart';
import 'package:folego/features/profile/sheet_sync_status_card.dart';

void main() {
  test('unconfigured and paused integrations cannot claim synchronization', () {
    const empty = SheetSyncStatus(configured: false, enabled: false);
    const paused = SheetSyncStatus(configured: true, enabled: false);
    expect(empty.headline, 'Planilha não conectada');
    expect(paused.headline, 'Integração desativada');
  });

  test('date parsing uses actual RPC timestamps and ignores backend secrets', () {
    final status = SheetSyncStatus.fromJson({
      'configured': true,
      'enabled': true,
      'last_push_at': '2026-10-13T08:53:14.385Z',
      'last_pull_at': '2026-10-13T22:33:02.340Z',
      'spreadsheet_id': 'not-for-client',
      'token_hash': 'not-for-client',
    });
    expect(status.lastPushAt?.toUtc().hour, 8);
    expect(status.lastPullAt?.toUtc().hour, 22);
    expect(status.headline, 'Integração habilitada');
  });

  testWidgets('shows two directions without a false success assertion',
      (tester) async {
    final status = SheetSyncStatus(
      configured: true,
      enabled: true,
      lastPushAt: DateTime.utc(2026, 10, 13, 8, 53),
      lastPullAt: DateTime.utc(2026, 10, 13, 22, 33),
    );
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: SheetSyncStatusCard(
        spaceId: 'space-a',
        loadStatus: (_) async => status,
      ),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Integração habilitada'), findsOneWidget);
    expect(find.byKey(const ValueKey('sheet-sync-last-push')), findsOneWidget);
    expect(find.byKey(const ValueKey('sheet-sync-last-pull')), findsOneWidget);
    expect(find.textContaining('não confirmação de que todos'), findsOneWidget);
    expect(find.text('Planilha sincronizada'), findsNothing);
  });

  testWidgets('does not show previous space data after a fast switch',
      (tester) async {
    final a = Completer<SheetSyncStatus>();
    final b = Completer<SheetSyncStatus>();
    Future<SheetSyncStatus> loader(String id) =>
        id == 'a' ? a.future : b.future;

    Widget child(String spaceId) => MaterialApp(
      home: Scaffold(
        body: SheetSyncStatusCard(spaceId: spaceId, loadStatus: loader),
      ),
    );

    await tester.pumpWidget(child('a'));
    await tester.pumpWidget(child('b'));
    a.complete(const SheetSyncStatus(configured: true, enabled: true));
    await tester.pump();
    expect(find.text('Integração habilitada'), findsNothing);
    b.complete(const SheetSyncStatus(configured: false, enabled: false));
    await tester.pumpAndSettle();
    expect(find.text('Planilha não conectada'), findsOneWidget);
  });

  testWidgets('users without Sheets never see optional synchronization UI',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SheetSyncStatusCard(
          hideWhenUnconfigured: true,
          spaceId: 'regular-user-space',
          loadStatus: (_) async =>
              const SheetSyncStatus(configured: false, enabled: false),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sheet-sync-status')), findsNothing);
    expect(find.text('Planilha não conectada'), findsNothing);
  });

  testWidgets('connected users can still access optional diagnostics',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SheetSyncStatusCard(
          hideWhenUnconfigured: true,
          spaceId: 'connected-space',
          loadStatus: (_) async =>
              const SheetSyncStatus(configured: true, enabled: true),
          onOpenAudit: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sheet-sync-status')), findsOneWidget);
    expect(find.byKey(const ValueKey('sheet-audit-open')), findsOneWidget);
  });

  testWidgets('optional card keeps ordinary users clear of technical failures',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SheetSyncStatusCard(
          hideWhenUnconfigured: true,
          spaceId: 'unconnected-space',
          loadStatus: (_) async => throw StateError('service unavailable'),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sheet-sync-status')), findsNothing);
  });

  testWidgets('discloses connection failures without stale success',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SheetSyncStatusCard(
          spaceId: 'a',
          loadStatus: (_) async => throw StateError('private server detail'),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('não foi possível verificar a conexão agora'),
        findsOneWidget);
    expect(find.textContaining('private server detail'), findsNothing);
  });
}
