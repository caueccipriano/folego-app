import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/notifications/session_notification_cleanup.dart';

void main() {
  test('browser unsubscribe finishes while the former identity is signed in',
      () async {
    final events = <String>[];
    await SessionNotificationCleanup.performSafeSignOut(
      cleanup: () async {
        events.add('unsubscribe:start');
        await Future<void>.delayed(Duration.zero);
        events.add('unsubscribe:finished');
      },
      signOut: () async => events.add('supabase:signout'),
    );

    expect(
      events,
      <String>[
        'unsubscribe:start',
        'unsubscribe:finished',
        'supabase:signout',
      ],
    );
  });

  test('a cleanup failure does not trap the customer in an active session',
      () async {
    var signedOut = false;
    await SessionNotificationCleanup.performSafeSignOut(
      cleanup: () async => throw StateError('synthetic browser unavailable'),
      signOut: () async => signedOut = true,
    );
    expect(signedOut, isTrue);
  });

  test('bootstrap error and first-run onboarding both use protected logout',
      () {
    final source =
        File('lib/features/bootstrap/bootstrap_screen.dart').readAsStringSync();

    expect(
      source,
      contains('onPressed: () => SessionNotificationCleanup.signOut('),
    );
    expect(
      source,
      contains('onSignOut: () => SessionNotificationCleanup.signOut('),
    );
    expect(source, isNot(contains('widget.client.auth.signOut')));
  });

  test('profile logout shares cleanup and preserves account deletion cleanup',
      () {
    final source =
        File('lib/features/profile/profile_screen_v2.dart').readAsStringSync();

    expect(
      source,
      contains('() => SessionNotificationCleanup.signOut(widget.client)'),
    );
    expect(
      source,
      contains('await notificationService.clearForLogout();'),
    );
  });

  test('unexpected logout, startup and identity change clear local push',
      () {
    final gate = File('lib/features/auth/auth_gate.dart').readAsStringSync();

    expect(gate, contains('if (_session == null)'));
    expect(gate, contains('event.event == AuthChangeEvent.signedOut'));
    expect(gate, contains('previousUserId != nextUserId'));
    expect(
      gate,
      contains('SessionNotificationCleanup.clearAfterSessionLoss('),
    );
  });

  test('server token is still valid while normal logout deletes endpoint',
      () {
    final service = File(
      'lib/core/notifications/session_notification_cleanup.dart',
    ).readAsStringSync();
    final adapter = File(
      'lib/core/notifications/notification_adapter_web.dart',
    ).readAsStringSync();

    expect(service, contains('await cleanup();'));
    expect(
      service,
      contains('await createNotificationSchedulerAdapter(client).clearAll();'),
    );
    expect(adapter, contains('_folegoPushUnsubscribe()'));
    expect(adapter, contains(".from('web_push_subscriptions')"));
    // Logout runs under the FORMER signed-in identity, before Auth
    // invalidation. The current user getter may already be switching.
    expect(adapter, contains(".eq('user_id', formerUserId)"));
    expect(adapter, contains(".eq('endpoint', endpoint)"));
  });
}
