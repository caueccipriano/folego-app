import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'subscription_access.dart';

class SubscriptionService {
  SubscriptionService(this._client);

  final SupabaseClient _client;

  static const entitlementId = 'premium';
  static const androidApiKey = String.fromEnvironment(
    'REVENUECAT_ANDROID_API_KEY',
  );
  static const iosApiKey = String.fromEnvironment(
    'REVENUECAT_IOS_API_KEY',
  );

  static bool _configured = false;

  static bool get supportsNativeStore =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<void> initialize(SupabaseClient client) async {
    if (!supportsNativeStore || _configured) return;

    final apiKey = defaultTargetPlatform == TargetPlatform.android
        ? androidApiKey
        : iosApiKey;

    if (apiKey.trim().isEmpty) return;

    if (kDebugMode) {
      await Purchases.setLogLevel(LogLevel.debug);
    }

    final configuration = PurchasesConfiguration(apiKey)
      ..appUserID = client.auth.currentUser?.id;

    await Purchases.configure(configuration);
    _configured = true;
  }

  static Future<void> syncUser(String? userId) async {
    if (!_configured) return;

    if (userId == null) {
      if (!await Purchases.isAnonymous) {
        await Purchases.logOut();
      }
      return;
    }

    await Purchases.logIn(userId);
  }

  Future<SubscriptionAccess> getAccess() async {
    if (_configured) {
      try {
        final info = await Purchases.getCustomerInfo();
        final entitlement = info.entitlements.all[entitlementId];

        if (entitlement?.isActive == true) {
          if (entitlement!.periodType == PeriodType.trial) {
            return SubscriptionAccess(
              kind: SubscriptionAccessKind.trial,
              expiresAt: _parseDate(entitlement.expirationDate),
            );
          }

          return SubscriptionAccess(
            kind: SubscriptionAccessKind.premium,
            expiresAt: _parseDate(entitlement.expirationDate),
          );
        }
      } catch (_) {
        // If the store is temporarily unavailable, still check server grants.
      }
    }

    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return const SubscriptionAccess(kind: SubscriptionAccessKind.free);
    }

    try {
      final row = await _client
          .from('premium_grants')
          .select('grant_type,valid_until')
          .eq('user_id', userId)
          .maybeSingle();

      if (row != null) {
        final grantType = row['grant_type'] as String?;
        final validUntil = _parseDate(row['valid_until'] as String?);
        final stillValid =
            validUntil == null || validUntil.isAfter(DateTime.now());

        if (stillValid && grantType == 'lifetime') {
          return const SubscriptionAccess(
            kind: SubscriptionAccessKind.lifetime,
          );
        }

        if (stillValid && grantType == 'complimentary') {
          return SubscriptionAccess(
            kind: SubscriptionAccessKind.complimentary,
            expiresAt: validUntil,
          );
        }
      }
    } catch (_) {
      // A temporary backend failure should not crash the app.
    }

    return const SubscriptionAccess(kind: SubscriptionAccessKind.free);
  }

  Future<void> presentPremiumPaywall() async {
    if (!_configured) {
      throw StateError(
        'Assinaturas ainda não estão configuradas neste build.',
      );
    }

    await RevenueCatUI.presentPaywallIfNeeded(entitlementId);
  }

  Future<SubscriptionAccess> restorePurchases() async {
    if (!_configured) {
      throw StateError(
        'Assinaturas ainda não estão configuradas neste build.',
      );
    }

    await Purchases.restorePurchases();
    return getAccess();
  }

  Future<void> presentCustomerCenter() async {
    if (!_configured) {
      throw StateError(
        'Assinaturas ainda não estão configuradas neste build.',
      );
    }

    await RevenueCatUI.presentCustomerCenter();
  }

  static DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value)?.toLocal();
  }
}
