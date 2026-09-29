import 'dart:convert';
import 'dart:js_interop';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'notification_models.dart';
import 'notification_service.dart';
import 'push_recovery.dart';

@JS('folegoPushGetStatus')
external JSPromise<JSString> _folegoPushGetStatus();

@JS('folegoPushRequestAndSubscribe')
external JSPromise<JSString> _folegoPushRequestAndSubscribe();

@JS('folegoPushPeekExistingSubscription')
external JSPromise<JSString> _folegoPushPeekExistingSubscription();

@JS('folegoPushUnsubscribe')
external JSPromise<JSString> _folegoPushUnsubscribe();

NotificationSchedulerAdapter createNotificationSchedulerAdapter(
  SupabaseClient client,
) => WebPushNotificationAdapter(client);

class WebPushNotificationAdapter
    implements NotificationSchedulerAdapter, PushDeviceRecovery {
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

  /// Reads an already-created Push subscription only. No permission prompt,
  /// subscribe(), registration write, or lookup of other users' server rows.
  Future<({
    bool granted,
    String? endpoint,
    String? p256dh,
    String? authSecret,
    String? userAgent,
  })> _peekExisting() async {
    final value = await _folegoPushPeekExistingSubscription().toDart;
    final parsed = jsonDecode(value.toDart);
    if (parsed is! Map) throw const FormatException('invalid_push_probe');
    final result = Map<String, dynamic>.from(parsed);
    final granted = result['status'] == 'granted';
    if (!granted) {
      return (
        granted: false,
        endpoint: null,
        p256dh: null,
        authSecret: null,
        userAgent: null,
      );
    }

    final subscriptionRaw = result['subscription'];
    if (subscriptionRaw == null) {
      return (
        granted: true,
        endpoint: null,
        p256dh: null,
        authSecret: null,
        userAgent: result['userAgent'] as String?,
      );
    }
    if (subscriptionRaw is! Map) {
      throw const FormatException('invalid_existing_subscription');
    }
    final subscription = Map<String, dynamic>.from(subscriptionRaw);
    final keysRaw = subscription['keys'];
    if (keysRaw is! Map) throw const FormatException('missing_push_keys');
    final keys = Map<String, dynamic>.from(keysRaw);
    final endpoint = subscription['endpoint'] as String?;
    final p256dh = keys['p256dh'] as String?;
    final authSecret = keys['auth'] as String?;
    if (endpoint == null ||
        !endpoint.startsWith('https://') ||
        p256dh == null ||
        p256dh.isEmpty ||
        authSecret == null ||
        authSecret.isEmpty) {
      throw const FormatException('invalid_existing_push_keys');
    }
    return (
      granted: true,
      endpoint: endpoint,
      p256dh: p256dh,
      authSecret: authSecret,
      userAgent: result['userAgent'] as String?,
    );
  }

  /// Exists only after the new session-bound SQL and same-user RLS recovery
  /// migration. Prior versions fail closed: the UI cannot re-enable an
  /// unverified historical endpoint before the safe server is deployed.
  Future<String> _serverOwnershipStatus(String endpoint) async {
    final response = await client.rpc(
      'get_my_push_device_recovery_status',
      params: <String, dynamic>{'p_endpoint': endpoint},
    );
    if (response is String &&
        const <String>{
          'new_device',
          'owned_active',
          'owned_rebind',
          'not_eligible',
        }.contains(response)) {
      return response;
    }
    throw const FormatException('invalid_push_ownership_status');
  }

  @override
  Future<ExistingPushRecoveryStatus> inspectExistingPush() =>
      PushBrowserOperationQueue.run(() async {
        final userId = client.auth.currentUser?.id;
        if (userId == null) return ExistingPushRecoveryStatus.unavailable;
        try {
          final existing = await _peekExisting();
          if (!existing.granted) {
            return ExistingPushRecoveryStatus.unavailable;
          }
          if (client.auth.currentUser?.id != userId) {
            return ExistingPushRecoveryStatus.unavailable;
          }
          if (existing.endpoint == null) {
            // Confirm the safe RPC is deployed even for a device with no
            // existing Push subscription. Missing migration => no CTA.
            final state = await _serverOwnershipStatus('');
            if (client.auth.currentUser?.id != userId ||
                state != 'new_device') {
              return ExistingPushRecoveryStatus.unavailable;
            }
            return ExistingPushRecoveryStatus.needsEnrollment;
          }
          final state = await _serverOwnershipStatus(existing.endpoint!);
          if (client.auth.currentUser?.id != userId) {
            return ExistingPushRecoveryStatus.unavailable;
          }
          return switch (state) {
            'owned_rebind' => ExistingPushRecoveryStatus.needsRebind,
            'owned_active' => ExistingPushRecoveryStatus.alreadyActive,
            'new_device' => ExistingPushRecoveryStatus.needsEnrollment,
            'not_eligible' => ExistingPushRecoveryStatus.needsEnrollment,
            _ => ExistingPushRecoveryStatus.unavailable,
          };
        } catch (_) {
          return ExistingPushRecoveryStatus.lookupFailed;
        }
      });

  @override
  Future<NotificationPermissionStatus> rebindPreviouslyOwnedPush() =>
      PushBrowserOperationQueue.run(() async {
        final userId = client.auth.currentUser?.id;
        if (userId == null) {
          return NotificationPermissionStatus.notDetermined;
        }

        try {
          final existing = await _peekExisting();
          if (!existing.granted || existing.endpoint == null) {
            return NotificationPermissionStatus.notDetermined;
          }
          final ownership = await _serverOwnershipStatus(existing.endpoint!);
          if (client.auth.currentUser?.id != userId) {
            return NotificationPermissionStatus.notDetermined;
          }
          if (ownership == 'owned_active') {
            return NotificationPermissionStatus.granted;
          }
          // An identical browser subscription belonging to ANOTHER
          // user returns new_device, so it is never reactivated here.
          if (ownership != 'owned_rebind') {
            return NotificationPermissionStatus.notDetermined;
          }

          final updated = await client
              .from('web_push_subscriptions')
              .update(<String, dynamic>{
                'p256dh': existing.p256dh,
                'auth_secret': existing.authSecret,
                'user_agent': existing.userAgent,
                'disabled_at': null,
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              })
              .eq('user_id', userId)
              .eq('endpoint', existing.endpoint!)
              .select('id')
              .maybeSingle();

          if (updated == null || client.auth.currentUser?.id != userId) {
            return NotificationPermissionStatus.notDetermined;
          }
          // A server BEFORE trigger verifies the signed live session and
          // binds its session_id; a zero-row update is NOT fake success.
          return NotificationPermissionStatus.granted;
        } catch (_) {
          return NotificationPermissionStatus.notDetermined;
        }
      });

  /// User-initiated opt-in only. If the existing browser endpoint was NOT
  /// registered by this Fôlego identity, remove the old local subscription
  /// before creating a new endpoint. Never upsert B onto A's endpoint.
  @override
  Future<NotificationPermissionStatus> requestPermission() =>
      PushBrowserOperationQueue.run(() async {
        final userId = client.auth.currentUser?.id;
        if (userId == null) {
          return NotificationPermissionStatus.notDetermined;
        }
        try {
          final existing = await _peekExisting();
          if (existing.granted && existing.endpoint != null) {
            final ownership =
                await _serverOwnershipStatus(existing.endpoint!);
            if (client.auth.currentUser?.id != userId) {
              return NotificationPermissionStatus.notDetermined;
            }
            if (ownership == 'new_device') {
              // This browser endpoint is NOT associated with the current
              // signed-in user. They pressed the explicit opt-in control:
              // unsubscribe locally rather than silently inheriting it.
              final removed = jsonDecode(
                (await _folegoPushUnsubscribe().toDart).toDart,
              );
              if (removed is! Map ||
                  removed['endpoint'] != existing.endpoint) {
                return NotificationPermissionStatus.notDetermined;
              }
            }
          } else {
            // Fail closed on pre-migration clients; do not prompt for
            // browser permission while backend ownership is unverifiable.
            await _serverOwnershipStatus('');
          }

          if (client.auth.currentUser?.id != userId) {
            return NotificationPermissionStatus.notDetermined;
          }
          final value = await _folegoPushRequestAndSubscribe().toDart;
          final parsed = jsonDecode(value.toDart);
          if (parsed is! Map) return NotificationPermissionStatus.notDetermined;
          final result = Map<String, dynamic>.from(parsed);
          final status = _mapStatus(result['status'] as String?);
          if (status != NotificationPermissionStatus.granted) return status;

          final subscriptionRaw = result['subscription'];
          if (subscriptionRaw is! Map) {
            return NotificationPermissionStatus.notDetermined;
          }
          final subscription = Map<String, dynamic>.from(subscriptionRaw);
          final keysRaw = subscription['keys'];
          if (keysRaw is! Map) {
            return NotificationPermissionStatus.notDetermined;
          }
          final keys = Map<String, dynamic>.from(keysRaw);
          final endpoint = subscription['endpoint'] as String?;
          final p256dh = keys['p256dh'] as String?;
          final authSecret = keys['auth'] as String?;
          if (endpoint == null ||
              !endpoint.startsWith('https://') ||
              p256dh == null ||
              authSecret == null ||
              client.auth.currentUser?.id != userId) {
            return NotificationPermissionStatus.notDetermined;
          }

          // The authoritative trigger sets the session_id from the signed
          // current JWT. A different user's row cannot be stolen through
          // the existing endpoint UNIQUE key and own-user RLS.
          await client.from('web_push_subscriptions').upsert(
            <String, dynamic>{
              'user_id': userId,
              'endpoint': endpoint,
              'p256dh': p256dh,
              'auth_secret': authSecret,
              'user_agent': result['userAgent'] as String?,
              'disabled_at': null,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            },
            onConflict: 'endpoint',
          );
          if (client.auth.currentUser?.id != userId) {
            return NotificationPermissionStatus.notDetermined;
          }
          return NotificationPermissionStatus.granted;
        } catch (_) {
          // A missing RPC, missing session, error or malformed browser
          // probe cannot give a false success or inherit another identity.
          return NotificationPermissionStatus.notDetermined;
        }
      });

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
  Future<void> clearAll() => PushBrowserOperationQueue.run(() async {
    final formerUserId = client.auth.currentUser?.id;
    try {
      final parsed = jsonDecode(
        (await _folegoPushUnsubscribe().toDart).toDart,
      );
      if (parsed is! Map) return;
      final endpoint = parsed['endpoint'] as String?;
      if (endpoint != null &&
          formerUserId != null &&
          client.auth.currentUser?.id == formerUserId) {
        await client
            .from('web_push_subscriptions')
            .delete()
            .eq('user_id', formerUserId)
            .eq('endpoint', endpoint);
      }
    } catch (_) {
      // Logout must not be blocked if browser cleanup or RLS fails.
    }
  });

}
