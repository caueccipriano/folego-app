import 'dart:async';

import 'notification_models.dart';

/// The browser permission alone never proves that this Fôlego identity owns
/// the browser's Push endpoint. Recovery decisions also require an exact,
/// RLS-filtered server row for the currently signed-in user.
enum ExistingPushRecoveryStatus {
  unavailable,
  alreadyActive,
  needsRebind,
  needsEnrollment,
  lookupFailed,
}

abstract interface class PushDeviceRecovery {
  Future<ExistingPushRecoveryStatus> inspectExistingPush();
  Future<NotificationPermissionStatus> rebindPreviouslyOwnedPush();
}

ExistingPushRecoveryStatus classifyExistingPush({
  required bool browserPermissionGranted,
  required bool hasBrowserSubscription,
  required bool? ownEndpointIsEnabled,
  required bool lookupFailed,
}) {
  if (!browserPermissionGranted) {
    return ExistingPushRecoveryStatus.unavailable;
  }
  if (lookupFailed) {
    return ExistingPushRecoveryStatus.lookupFailed;
  }
  if (!hasBrowserSubscription || ownEndpointIsEnabled == null) {
    return ExistingPushRecoveryStatus.needsEnrollment;
  }
  return ownEndpointIsEnabled
      ? ExistingPushRecoveryStatus.alreadyActive
      : ExistingPushRecoveryStatus.needsRebind;
}

/// Serializes all local browser Push mutations, including explicit opt-in,
/// rebind and account signout cleanup. UI never restores on login implicitly.
abstract final class PushBrowserOperationQueue {
  static Future<void> _previous = Future<void>.value();
  static int _pending = 0;

  static Future<T> run<T>(Future<T> Function() action) async {
    _pending++;
    final prior = _previous;
    final released = Completer<void>();
    _previous = released.future;
    try {
      await prior;
      return await action();
    } finally {
      _pending--;
      released.complete();
    }
  }

  /// Safari/iPhone requires a Push API call from the ORIGINAL tap stack.
  /// Never put it behind an await, nor race it with logout/browser cleanup.
  /// Return null instead of delaying the gesture until it is no longer valid.
  static Future<T?> tryRunGesture<T>(Future<T> Function() action) {
    if (_pending != 0) return Future<T?>.value(null);
    _pending++;
    final released = Completer<void>();
    _previous = released.future;
    Future<T> started;
    try {
      started = action(); // intentionally synchronous, before the first await
    } catch (error, stack) {
      _pending--;
      released.complete();
      return Future<T?>.error(error, stack);
    }
    return started.whenComplete(() {
      _pending--;
      released.complete();
    });
  }
}
