import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/notifications/push_recovery.dart';

void main() {
  test('a clean iPhone gesture starts in the ORIGINAL synchronous tap stack',
      () async {
    var insideTapStack = true;
    var executed = false;

    final pending = PushBrowserOperationQueue.tryRunGesture<int>(() async {
      expect(insideTapStack, isTrue);
      executed = true;
      return 42;
    });
    insideTapStack = false;

    expect(await pending, 42);
    expect(executed, isTrue);
  });

  test('queued signout must NEVER postpone a transient browser gesture',
      () async {
    final firstStarted = Completer<void>();
    final releaseSignOut = Completer<void>();
    final logout = PushBrowserOperationQueue.run(() async {
      firstStarted.complete();
      await releaseSignOut.future;
    });
    await firstStarted.future;

    var wronglyStarted = false;
    final delayedAttempt = PushBrowserOperationQueue.tryRunGesture<int>(() async {
      wronglyStarted = true;
      return 1;
    });
    expect(await delayedAttempt, isNull);
    expect(wronglyStarted, isFalse);

    releaseSignOut.complete();
    await logout;

    var stillInTap = true;
    final validAttempt = PushBrowserOperationQueue.tryRunGesture<int>(() async {
      expect(stillInTap, isTrue);
      return 2;
    });
    stillInTap = false;
    expect(await validAttempt, 2);
  });

  test('throwing synchronously frees the gesture queue for a later tap',
      () async {
    await expectLater(
      PushBrowserOperationQueue.tryRunGesture<int>(
        () => throw StateError('fictional browser error'),
      ),
      throwsStateError,
    );

    final next = PushBrowserOperationQueue.tryRunGesture<int>(() async => 3);
    expect(await next, 3);
  });

  test('Flutter calls permission and subscribe INSIDE a gesture callback',
      () {
    final adapter = File(
      'lib/core/notifications/notification_adapter_web.dart',
    ).readAsStringSync();
    final source = adapter.substring(
      adapter.indexOf('Future<NotificationPermissionStatus> requestPermission()'),
    );

    expect(source, contains('PushBrowserOperationQueue.tryRunGesture(() {'));
    expect(
      source,
      contains('final pending = _folegoPushPermissionFromTap();'),
    );
    expect(
      source,
      contains('final pending = _folegoPushSubscribeFromTap();'),
    );
    expect(
      source,
      contains('_preparedFor(userId, accessToken)'),
    );
    expect(source, contains('_readyEndpoint != null'));
    expect(source, contains('_folegoPushUnsubscribe()'));
  });

  test('WebKit JS prepares the worker before the tap, never auto-consents',
      () {
    final bridge = File('web/folego_push_bridge.js').readAsStringSync();

    expect(bridge, contains('window.folegoPushPrepareTap ='));
    expect(bridge, contains('window.folegoPushPermissionFromTap ='));
    expect(bridge, contains('window.folegoPushSubscribeFromTap ='));
    expect(bridge, contains('Notification.requestPermission()'));
    expect(
      bridge,
      contains('readyRegistration.pushManager.subscribe({'),
    );
    expect(bridge, contains('needsHomeScreenInstall()'));
    expect(bridge, contains('permissionGrantedNeedsActivation'));
  });
}
