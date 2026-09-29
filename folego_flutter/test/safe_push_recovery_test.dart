import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/notifications/push_recovery.dart';

void main() {
  group('Same-user browser Push recovery policy', () {
    test('browser permission denied never implies a Fôlego enrollment', () {
      expect(
        classifyExistingPush(
          browserPermissionGranted: false,
          hasBrowserSubscription: true,
          ownEndpointIsEnabled: true,
          lookupFailed: false,
        ),
        ExistingPushRecoveryStatus.unavailable,
      );
    });

    test('only an exact signed-in owner gets the rebind action', () {
      expect(
        classifyExistingPush(
          browserPermissionGranted: true,
          hasBrowserSubscription: true,
          ownEndpointIsEnabled: false,
          lookupFailed: false,
        ),
        ExistingPushRecoveryStatus.needsRebind,
      );
    });

    test('already registered current account is not reenrolled', () {
      expect(
        classifyExistingPush(
          browserPermissionGranted: true,
          hasBrowserSubscription: true,
          ownEndpointIsEnabled: true,
          lookupFailed: false,
        ),
        ExistingPushRecoveryStatus.alreadyActive,
      );
    });

    test('another account or unknown browser endpoint needs explicit opt-in',
        () {
      expect(
        classifyExistingPush(
          browserPermissionGranted: true,
          hasBrowserSubscription: true,
          ownEndpointIsEnabled: null,
          lookupFailed: false,
        ),
        ExistingPushRecoveryStatus.needsEnrollment,
      );
    });

    test('no browser subscription never triggers silent creation', () {
      expect(
        classifyExistingPush(
          browserPermissionGranted: true,
          hasBrowserSubscription: false,
          ownEndpointIsEnabled: null,
          lookupFailed: false,
        ),
        ExistingPushRecoveryStatus.needsEnrollment,
      );
    });

    test('backend ownership failure prevents false recovery approval', () {
      expect(
        classifyExistingPush(
          browserPermissionGranted: true,
          hasBrowserSubscription: true,
          ownEndpointIsEnabled: true,
          lookupFailed: true,
        ),
        ExistingPushRecoveryStatus.lookupFailed,
      );
    });

    test('shared-browser mutation queue finishes old cleanup before signup',
        () async {
      final events = <String>[];
      final firstStarted = Completer<void>();
      final allowCleanup = Completer<void>();

      final oldUserCleanup = PushBrowserOperationQueue.run(() async {
        events.add('old-cleanup-start');
        firstStarted.complete();
        await allowCleanup.future;
        events.add('old-cleanup-finished');
      });
      await firstStarted.future;

      final newUserRegistration = PushBrowserOperationQueue.run(() async {
        events.add('new-user-registration');
      });

      await Future<void>.delayed(Duration.zero);
      expect(events, <String>['old-cleanup-start']);

      allowCleanup.complete();
      await Future.wait(<Future<void>>[
        oldUserCleanup,
        newUserRegistration,
      ]);

      expect(events, <String>[
        'old-cleanup-start',
        'old-cleanup-finished',
        'new-user-registration',
      ]);
    });

    test('a failed operation releases the queue for next account', () async {
      await expectLater(
        PushBrowserOperationQueue.run(() async {
          throw StateError('synthetic failed old device');
        }),
        throwsStateError,
      );
      var nextRun = false;
      await PushBrowserOperationQueue.run(() async {
        nextRun = true;
      });
      expect(nextRun, isTrue);
    });
  });

  group('Browser/DB privacy contract', () {
    test('read-only browser probe never prompts or subscribes', () {
      final bridge = File('web/folego_push_bridge.js').readAsStringSync();
      final start = bridge.indexOf(
        'window.folegoPushPeekExistingSubscription =',
      );
      final end = bridge.indexOf(
        'window.folegoPushRequestAndSubscribe =',
        start,
      );
      expect(start, greaterThan(-1));
      expect(end, greaterThan(start));

      final probe = bridge.substring(start, end);
      expect(probe, contains("Notification.permission !== 'granted'"));
      expect(probe, contains('pushManager.getSubscription()'));
      expect(probe, isNot(contains('pushManager.subscribe(')));
      expect(probe, isNot(contains('Notification.requestPermission(')));
    });

    test('a foreign browser endpoint cannot pass own-user restore', () {
      final webAdapter = File(
        'lib/core/notifications/notification_adapter_web.dart',
      ).readAsStringSync();

      expect(webAdapter, contains('get_my_push_device_recovery_status'));
      expect(webAdapter, contains("'owned_rebind'"));
      expect(webAdapter, contains("'new_device'"));
      expect(webAdapter, contains('client.auth.currentUser?.id != userId'));
      expect(webAdapter, contains(".eq('user_id', userId)"));
      expect(webAdapter, contains(".eq('endpoint', existing.endpoint!)"));
      expect(webAdapter, contains('_folegoPushUnsubscribe()'));
      expect(webAdapter, contains('PushBrowserOperationQueue.run('));
    });

    test('no recovery occurs automatically on auth state transitions', () {
      final gate = File(
        'lib/features/auth/auth_gate.dart',
      ).readAsStringSync();
      final service = File(
        'lib/core/notifications/notification_service.dart',
      ).readAsStringSync();

      expect(gate, isNot(contains('rebindPreviouslyOwnedPush')));
      expect(gate, isNot(contains('requestPermission(')));
      expect(service, contains('rebindPreviouslyOwnedPush()'));
    });

    test('settings requires explicit press and verifies server success', () {
      final settings = File(
        'lib/features/profile/notification_settings_screen.dart',
      ).readAsStringSync();

      expect(settings, contains("'push-safe-recovery-button'"));
      expect(settings, contains('_activatePushOnThisDevice'));
      expect(settings, contains('rebindPreviouslyOwnedPush()'));
      expect(settings, contains('verified != ExistingPushRecoveryStatus.alreadyActive'));
    });

    test('new RPC validates signed active session and only own endpoint', () {
      final sql = File(
        '../supabase/migrations/'
        '20260929103000_owner_scoped_push_recovery_status.sql',
      ).readAsStringSync();

      expect(sql, contains("auth.role() <> 'authenticated'"));
      expect(sql, contains("auth.jwt()->>'session_id'"));
      expect(sql, contains('FROM auth.sessions s'));
      expect(sql, contains('ws.user_id = auth.uid()'));
      expect(sql, contains("RETURN 'new_device'"));
      expect(sql, contains("RETURN 'owned_rebind'"));
    });
  });
}
