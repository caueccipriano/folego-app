import 'dart:convert';
import 'dart:js_interop';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'notification_models.dart';
import 'notification_service.dart';

@JS('folegoPushGetStatus')
external JSPromise<JSString> _folegoPushGetStatus();

@JS('folegoPushRequestAndSubscribe')
external JSPromise<JSString> _folegoPushRequestAndSubscribe();

@JS('folegoPushUnsubscribe')
external JSPromise<JSString> _folegoPushUnsubscribe();

NotificationSchedulerAdapter createNotificationSchedulerAdapter(
  SupabaseClient client,
) => WebPushNotificationAdapter(client);

class WebPushNotificationAdapter implements NotificationSchedulerAdapter {
  WebPushNotificationAdapter(this.client);

  final SupabaseClient client;

  NotificationPermissionStatus _mapStatus(String? value) {
    switch (value) {
      case 'granted':
        return NotificationPermissionStatus.granted;
      case 'denied':
        return NotificationPermissionStatus.denied;
      case 'notDetermined':
        return NotificationPermissionStatus.notDetermined;
      default:
        return NotificationPermissionStatus.unsupported;
    }
  }

  @override
  Future<NotificationPermissionStatus> getPermissionStatus() async {
    try {
      final value = await _folegoPushGetStatus().toDart;
      return _mapStatus(value.toDart);
    } catch (_) {
      return NotificationPermissionStatus.unsupported;
    }
  }

  @override
  Future<NotificationPermissionStatus> requestPermission() async {
    try {
      final value = await _folegoPushRequestAndSubscribe().toDart;
      final result = Map<String, dynamic>.from(
        jsonDecode(value.toDart) as Map,
      );
      final status = _mapStatus(result['status'] as String?);
      if (status != NotificationPermissionStatus.granted) return status;

      final user = client.auth.currentUser;
      final subscription = result['subscription'];
      if (user == null || subscription is! Map) {
        return NotificationPermissionStatus.notDetermined;
      }
      final subscriptionMap = Map<String, dynamic>.from(subscription);
      final keysRaw = subscriptionMap['keys'];
      if (keysRaw is! Map) return NotificationPermissionStatus.notDetermined;
      final keys = Map<String, dynamic>.from(keysRaw);
      final endpoint = subscriptionMap['endpoint'] as String?;
      final p256dh = keys['p256dh'] as String?;
      final auth = keys['auth'] as String?;
      if (endpoint == null || p256dh == null || auth == null) {
        return NotificationPermissionStatus.notDetermined;
      }

      await client.from('web_push_subscriptions').upsert(
        <String, dynamic>{
          'user_id': user.id,
          'endpoint': endpoint,
          'p256dh': p256dh,
          'auth_secret': auth,
          'user_agent': result['userAgent'] as String?,
          'disabled_at': null,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'endpoint',
      );
      return NotificationPermissionStatus.granted;
    } catch (_) {
      return NotificationPermissionStatus.notDetermined;
    }
  }

  @override
  Future<List<FinancialNotificationIntent>> pendingForSpace(String spaceId) async =>
      const <FinancialNotificationIntent>[];

  @override
  Future<void> schedule(FinancialNotificationIntent intent) async {
    // Web Push is scheduled server-side. The browser adapter owns permission
    // and subscription registration only.
  }

  @override
  Future<void> cancel(String stableKey) async {
    // Delivery dedupe lives server-side for Web Push.
  }

  @override
  Future<void> cancelForEntity({
    required String spaceId,
    required String entityType,
    required String entityId,
  }) async {
    // No local schedule exists on Web Push.
  }

  @override
  Future<void> clearForSpace(String spaceId) async {
    // The subscription is user-scoped and can serve another financial space.
  }

  @override
  Future<void> clearAll() async {
    try {
      final value = await _folegoPushUnsubscribe().toDart;
      final result = Map<String, dynamic>.from(
        jsonDecode(value.toDart) as Map,
      );
      final endpoint = result['endpoint'] as String?;
      final user = client.auth.currentUser;
      if (endpoint != null && user != null) {
        await client
            .from('web_push_subscriptions')
            .delete()
            .eq('user_id', user.id)
            .eq('endpoint', endpoint);
      }
    } catch (_) {
      // Logout must not be blocked if browser subscription cleanup fails.
    }
  }
}
