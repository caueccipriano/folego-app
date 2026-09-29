import 'dart:convert';
import 'dart:js_interop';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'notification_models.dart';
import 'notification_service.dart';
import 'push_recovery.dart';

@JS('folegoPushGetStatus')
external JSPromise<JSString> _folegoPushGetStatus();

@JS('folegoPushPrepareTap')
external JSPromise<JSString> _folegoPushPrepareTap();

@JS('folegoPushPermissionFromTap')
external JSPromise<JSString> _folegoPushPermissionFromTap();

@JS('folegoPushSubscribeFromTap')
external JSPromise<JSString> _folegoPushSubscribeFromTap();

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

  // A successful owner-status RPC and warm worker must finish BEFORE any
  // user gesture. A refreshed JWT or different account invalidates it.
  String? _readyUserId;
  String? _readyAccessToken;
  String? _readyOwnership;
  String? _readyEndpoint;
  bool _readyGranted = false;

  void _clearPreparedGesture() {
    _readyUserId = null;
    _readyAccessToken = null;
    _readyOwnership = null;
    _readyEndpoint = null;
    _readyGranted = false;
  }

  bool _preparedFor(String userId, String accessToken) =>
      _readyUserId == userId && _readyAccessToken == accessToken;


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
        _clearPreparedGesture();
        final userId = client.auth.currentUser?.id;
        final accessToken = client.auth.currentSession?.accessToken;
        if (userId == null || accessToken == null) {
          return ExistingPushRecoveryStatus.unavailable;
        }
        try {
          // Registration + exact endpoint inspection happen here, well
          // BEFORE the future iOS touch/notification permission gesture.
          final raw = await _folegoPushPrepareTap().toDart;
          final prepared = jsonDecode(raw.toDart);
          if (prepared is! Map ||
              prepared['status'] == 'unsupported' ||
              prepared['status'] == 'denied') {
            return ExistingPushRecoveryStatus.unavailable;
          }
          if (prepared['ready'] != true) {
            return ExistingPushRecoveryStatus.lookupFailed;
          }
          final existing = await _peekExisting();
          final ownership =
              await _serverOwnershipStatus(existing.endpoint ?? '');
          if (client.auth.currentUser?.id != userId ||
              client.auth.currentSession?.accessToken != accessToken) {
            return ExistingPushRecoveryStatus.unavailable;
          }
          _readyUserId = userId;
          _readyAccessToken = accessToken;
          _readyOwnership = ownership;
          _readyEndpoint = existing.endpoint;
          _readyGranted = existing.granted;

          // This still checks the server before a FIRST permission prompt.
          // Only the future explicit tap may invoke the browser API.
          if (!existing.granted) {
            return ExistingPushRecoveryStatus.unavailable;
          }
          if (existing.endpoint == null) {
            return ownership == 'new_device'
                ? ExistingPushRecoveryStatus.needsEnrollment
                : ExistingPushRecoveryStatus.unavailable;
          }
          return switch (ownership) {
            'owned_rebind' => ExistingPushRecoveryStatus.needsRebind,
            'owned_active' => ExistingPushRecoveryStatus.alreadyActive,
            'new_device' => ExistingPushRecoveryStatus.needsEnrollment,
            'not_eligible' => ExistingPushRecoveryStatus.needsEnrollment,
            _ => ExistingPushRecoveryStatus.unavailable,
          };
        } catch (_) {
          _clearPreparedGesture();
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

  Future<NotificationPermissionStatus> _finishGesturePermission(
    JSPromise<JSString> pending,
    String userId,
    String accessToken,
  ) async {
    try {
      final decoded = jsonDecode((await pending.toDart).toDart);
      if (decoded is! Map ||
          client.auth.currentUser?.id != userId ||
          client.auth.currentSession?.accessToken != accessToken) {
        return NotificationPermissionStatus.notDetermined;
      }
      // Permission is not a push subscription. An iPhone owner makes a
      // SECOND deliberate tap after the UI re-inspects the fresh state.
      if (decoded['status'] == 'denied') {
        return NotificationPermissionStatus.denied;
      }
      if (decoded['status'] == 'unsupported') {
        return NotificationPermissionStatus.unsupported;
      }
      return NotificationPermissionStatus.notDetermined;
    } catch (_) {
      return NotificationPermissionStatus.notDetermined;
    } finally {
      _clearPreparedGesture();
    }
  }

  Future<NotificationPermissionStatus> _finishGestureSubscribe(
    JSPromise<JSString> pending,
    String userId,
    String accessToken,
  ) async {
    try {
      final decoded = jsonDecode((await pending.toDart).toDart);
      if (decoded is! Map ||
          decoded['status'] != 'granted' ||
          client.auth.currentUser?.id != userId ||
          client.auth.currentSession?.accessToken != accessToken) {
        return NotificationPermissionStatus.notDetermined;
      }
      final subscription = decoded['subscription'];
      if (subscription is! Map) {
        return NotificationPermissionStatus.notDetermined;
      }
      final keys = subscription['keys'];
      if (keys is! Map) {
        return NotificationPermissionStatus.notDetermined;
      }
      final endpoint = subscription['endpoint'];
      final p256dh = keys['p256dh'];
      final auth = keys['auth'];
      if (endpoint is! String ||
          !endpoint.startsWith('https://') ||
          p256dh is! String ||
          p256dh.isEmpty ||
          auth is! String ||
          auth.isEmpty ||
          client.auth.currentUser?.id != userId ||
          client.auth.currentSession?.accessToken != accessToken) {
        return NotificationPermissionStatus.notDetermined;
      }

      // The database trigger binds the live signed Auth session.
      await client.from('web_push_subscriptions').upsert(
        <String, dynamic>{
          'user_id': userId,
          'endpoint': endpoint,
          'p256dh': p256dh,
          'auth_secret': auth,
          'user_agent': decoded['userAgent'] as String?,
          'disabled_at': null,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'endpoint',
      );
      if (client.auth.currentUser?.id != userId ||
          client.auth.currentSession?.accessToken != accessToken) {
        return NotificationPermissionStatus.notDetermined;
      }
      return NotificationPermissionStatus.granted;
    } catch (_) {
      return NotificationPermissionStatus.notDetermined;
    } finally {
      _clearPreparedGesture();
    }
  }

  /// Every network authorization and service-worker await finishes in
  /// inspectExistingPush, before the tap. A busy queue refuses the gesture
  /// instead of postponing it and losing WebKit transient user activation.
  @override
  Future<NotificationPermissionStatus> requestPermission() {
    final userId = client.auth.currentUser?.id;
    final accessToken = client.auth.currentSession?.accessToken;
    if (userId == null ||
        accessToken == null ||
        !_preparedFor(userId, accessToken)) {
      return Future<NotificationPermissionStatus>.value(
        NotificationPermissionStatus.notDetermined,
      );
    }

    if (!_readyGranted) {
      // This JS function invokes Notification.requestPermission() BEFORE
      // yielding control to the event loop, directly in Flutter onTap.
      return PushBrowserOperationQueue.tryRunGesture(() {
        final pending = _folegoPushPermissionFromTap();
        return _finishGesturePermission(pending, userId, accessToken);
      }).then((result) =>
          result ?? NotificationPermissionStatus.notDetermined);
    }

    if (_readyEndpoint != null &&
        (_readyOwnership == 'new_device' ||
            _readyOwnership == 'not_eligible')) {
      // Another browser account may have owned this endpoint. One tap
      // unbinds it locally; a SECOND tap is needed for the new user's
      // own session. Never steal the old globally UNIQUE DB endpoint.
      final oldEndpoint = _readyEndpoint!;
      _clearPreparedGesture();
      return PushBrowserOperationQueue.run(() async {
        try {
          if (client.auth.currentUser?.id != userId ||
              client.auth.currentSession?.accessToken != accessToken) {
            return NotificationPermissionStatus.notDetermined;
          }
          final decoded =
              jsonDecode((await _folegoPushUnsubscribe().toDart).toDart);
          if (decoded is! Map || decoded['endpoint'] != oldEndpoint) {
            return NotificationPermissionStatus.notDetermined;
          }
          return NotificationPermissionStatus.notDetermined;
        } catch (_) {
          return NotificationPermissionStatus.notDetermined;
        }
      });
    }

    if (_readyEndpoint != null && _readyOwnership == 'owned_active') {
      return Future<NotificationPermissionStatus>.value(
        NotificationPermissionStatus.granted,
      );
    }

    if (_readyEndpoint != null ||
        _readyOwnership != 'new_device') {
      return Future<NotificationPermissionStatus>.value(
        NotificationPermissionStatus.notDetermined,
      );
    }

    // The pre-warmed worker already has NO local browser subscription.
    // PushManager.subscribe() starts synchronously before the first await.
    return PushBrowserOperationQueue.tryRunGesture(() {
      final pending = _folegoPushSubscribeFromTap();
      return _finishGestureSubscribe(pending, userId, accessToken);
    }).then((result) =>
        result ?? NotificationPermissionStatus.notDetermined);
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
