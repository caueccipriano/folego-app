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

  static Future<T> run<T>(Future<T> Function() action) async {
    final prior = _previous;
    final released = Completer<void>();
    _previous = released.future;
    await prior;
    try {
      return await action();
    } finally {
      released.complete();
    }
  }
}
