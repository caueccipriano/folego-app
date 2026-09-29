import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/notifications/notification_models.dart';
import 'package:folego/core/notifications/notification_service.dart';
import 'package:folego/core/notifications/push_recovery.dart';
import 'package:folego/data/repositories/folego_repository.dart';
import 'package:folego/features/profile/notification_settings_data_source.dart';
import 'package:folego/features/profile/notification_settings_screen.dart';

class _UnusedFinancialRepository extends Fake implements FolegoRepository {}

class _SettingsSource implements NotificationSettingsDataSource {
  @override
  Future<NotificationPreferences> load(String spaceId) async =>
      const NotificationPreferences(
        spaceId: 'synthetic-user-space',
        financialRemindersEnabled: true,
      );

  @override
  Future<NotificationPreferences> save(NotificationPreferences prefs) async =>
      prefs;
}

class _FakePushRecovery extends Fake
    implements NotificationSchedulerAdapter, PushDeviceRecovery {
  _FakePushRecovery(
    this.status, {
    bool initiallyGranted = true,
  }) : browserPermission = initiallyGranted
            ? NotificationPermissionStatus.granted
            : NotificationPermissionStatus.notDetermined;

  ExistingPushRecoveryStatus status;
  NotificationPermissionStatus browserPermission;
  int inspectCalls = 0;
  int explicitEnrollCalls = 0;
  int explicitRebindCalls = 0;

  @override
  Future<NotificationPermissionStatus> getPermissionStatus() async =>
      browserPermission;

  @override
  Future<ExistingPushRecoveryStatus> inspectExistingPush() async {
    inspectCalls += 1;
    return status;
  }

  @override
  Future<NotificationPermissionStatus> rebindPreviouslyOwnedPush() async {
    explicitRebindCalls++;
    if (status != ExistingPushRecoveryStatus.needsRebind) {
      return NotificationPermissionStatus.notDetermined;
    }
    status = ExistingPushRecoveryStatus.alreadyActive;
    return NotificationPermissionStatus.granted;
  }

  @override
  Future<NotificationPermissionStatus> requestPermission() async {
    explicitEnrollCalls++;
    if (status == ExistingPushRecoveryStatus.unavailable &&
        browserPermission == NotificationPermissionStatus.notDetermined) {
      browserPermission = NotificationPermissionStatus.granted;
      status = ExistingPushRecoveryStatus.needsEnrollment;
      return NotificationPermissionStatus.notDetermined;
    }
    if (status == ExistingPushRecoveryStatus.alreadyActive) {
      return NotificationPermissionStatus.granted;
    }
    if (status != ExistingPushRecoveryStatus.needsEnrollment) {
      return NotificationPermissionStatus.notDetermined;
    }
    status = ExistingPushRecoveryStatus.alreadyActive;
    return NotificationPermissionStatus.granted;
  }
}

Future<void> _showScreen(
  WidgetTester tester,
  _FakePushRecovery adapter,
) async {
  final source = _SettingsSource();
  final service = NotificationService(
    adapter: adapter,
    loadPreferences: source.load,
    loadUpcoming: (_, _, _) async => const <NotificationUpcomingEvent>[],
  );
  await tester.pumpWidget(
    MaterialApp(
      home: NotificationSettingsScreen(
        repository: _UnusedFinancialRepository(),
        spaceId: 'synthetic-user-space',
        service: service,
        dataSource: source,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('legacy owner sees explicit one-tap reactivation; never auto',
      (tester) async {
    final adapter = _FakePushRecovery(
      ExistingPushRecoveryStatus.needsRebind,
    );
    await _showScreen(tester, adapter);

    expect(find.text('reativar meus alertas'), findsOneWidget);
    expect(adapter.explicitRebindCalls, 0);
    expect(adapter.explicitEnrollCalls, 0);

    await tester.tap(find.byKey(const ValueKey('push-safe-recovery-button')));
    await tester.pumpAndSettle();
    expect(adapter.explicitRebindCalls, 1);
    expect(adapter.explicitEnrollCalls, 0);
    expect(find.text('notificações no celular prontas'), findsOneWidget);
  });

  testWidgets('unlinked B account needs distinct explicit enrollment',
      (tester) async {
    final adapter = _FakePushRecovery(
      ExistingPushRecoveryStatus.needsEnrollment,
    );
    await _showScreen(tester, adapter);

    expect(find.text('ativar neste dispositivo'), findsOneWidget);
    expect(find.text('reativar meus alertas'), findsNothing);
    expect(adapter.explicitEnrollCalls, 0);

    await tester.tap(find.byKey(const ValueKey('push-safe-recovery-button')));
    await tester.pumpAndSettle();
    expect(adapter.explicitEnrollCalls, 1);
    expect(adapter.explicitRebindCalls, 0);
  });

  testWidgets('iPhone first tap grants permission, second tap enrolls device',
      (tester) async {
    final adapter = _FakePushRecovery(
      ExistingPushRecoveryStatus.unavailable,
      initiallyGranted: false,
    );
    await _showScreen(tester, adapter);

    final master = find.byKey(const ValueKey('notifications-master-toggle'));
    // Turn off synthetic pref before testing a genuinely fresh permission
    // journey. A first activation must never claim device enrollment.
    await tester.tap(master);
    await tester.pumpAndSettle();

    await tester.tap(master);
    await tester.pumpAndSettle();
    expect(adapter.explicitEnrollCalls, 1);
    expect(adapter.status, ExistingPushRecoveryStatus.needsEnrollment);
    expect(find.text('ativar neste dispositivo'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('push-safe-recovery-button')));
    await tester.pumpAndSettle();
    expect(adapter.explicitEnrollCalls, 2);
    expect(adapter.status, ExistingPushRecoveryStatus.alreadyActive);
    expect(find.text('notificações no celular prontas'), findsOneWidget);
  });

  testWidgets('a server outage never offers unsafe rebind or false success',
      (tester) async {
    final adapter = _FakePushRecovery(
      ExistingPushRecoveryStatus.lookupFailed,
    );
    await _showScreen(tester, adapter);

    expect(find.text('verificação temporariamente indisponível'), findsOneWidget);
    expect(find.byKey(const ValueKey('push-safe-recovery-button')), findsNothing);
    expect(adapter.explicitRebindCalls, 0);
    expect(adapter.explicitEnrollCalls, 0);
  });
}
