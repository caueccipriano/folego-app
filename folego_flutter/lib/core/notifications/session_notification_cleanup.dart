import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'notification_adapter_factory.dart';
import 'notification_runtime.dart';

/// Centralized logout sequencing for every Fôlego route, including the
/// bootstrap error screen and first-run onboarding.
abstract final class SessionNotificationCleanup {
  static Future<void> signOut(SupabaseClient client) async {
    await performSafeSignOut(
      cleanup: () => _clearBrowserOrRegisteredNotifications(client),
      signOut: client.auth.signOut,
    );
  }

  /// Covers forced expiry/external revocation, and removes an old device
  /// subscription when an unauthenticated PWA is reopened on shared hardware.
  /// There is no JWT after signOut: this can unsubscribe the local browser
  /// when supported, but cannot remove the old server row. Server-session-
  /// bound push delivery remains a separate launch acceptance gate.
  static Future<void> clearAfterSessionLoss(SupabaseClient client) async {
    try {
      await _clearBrowserOrRegisteredNotifications(client);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Notification session cleanup failed (${error.runtimeType})');
      }
    }
  }

  static Future<void> _clearBrowserOrRegisteredNotifications(
    SupabaseClient client,
  ) async {
    final service = NotificationServiceRegistry.current;
    if (service != null) {
      await service.clearForLogout();
      return;
    }
    await createNotificationSchedulerAdapter(client).clearAll();
  }

  /// Injectable sequencing tests that browser unsubscribe completes while
  /// the old identity still has its JWT. A cleanup failure must not trap
  /// someone in their signed-in session.
  @visibleForTesting
  static Future<void> performSafeSignOut({
    required Future<void> Function() cleanup,
    required Future<void> Function() signOut,
  }) async {
    try {
      await cleanup();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Pre-logout notification cleanup failed (${error.runtimeType})');
      }
    }
    await signOut();
  }
}
