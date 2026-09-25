import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'subscription_access.dart';

class SubscriptionService {
  SubscriptionService(this._client);

  final SupabaseClient _client;

  static const entitlementId = 'premium';
  static const monthlyPriceLabel = 'R\$ 9,90/mês';
  static const trialLabel = '7 dias grátis';
  static const androidApiKey =
      String.fromEnvironment('REVENUECAT_ANDROID_API_KEY');
  static const iosApiKey =
      String.fromEnvironment('REVENUECAT_IOS_API_KEY');

  static final ValueNotifier<SubscriptionAccess> accessNotifier =
      ValueNotifier<SubscriptionAccess>(
    const SubscriptionAccess(kind: SubscriptionAccessKind.free),
  );

  static bool _configured = false;

  // The RevenueCat Test Store is only for locally installed debug APKs.
  // Never allow its public SDK key in a production/release binary.
  static bool isTestStoreKey(String key) => key.startsWith('test_');
  static bool get isTestStoreBuild =>
      supportsNativeStore &&
      isTestStoreKey(defaultTargetPlatform == TargetPlatform.android
          ? androidApiKey
          : iosApiKey);

  static bool get supportsNativeStore =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  static bool get isConfigured => _configured;

  static Future<void> initialize(SupabaseClient client) async {
    if (!supportsNativeStore || _configured) return;
    final apiKey = defaultTargetPlatform == TargetPlatform.android
        ? androidApiKey
        : iosApiKey;
    if (apiKey.trim().isEmpty) return;
    if (apiKey.startsWith('sk_')) {
      throw StateError('RevenueCat secret API keys must not be embedded in apps.');
    }
    if (kReleaseMode && isTestStoreKey(apiKey)) {
      throw StateError('Never ship a RevenueCat Test Store key in a release.');
    }

    if (kDebugMode) await Purchases.setLogLevel(LogLevel.debug);
    final configuration = PurchasesConfiguration(apiKey)
      ..appUserID = client.auth.currentUser?.id;
    await Purchases.configure(configuration);
    _configured = true;
  }

  static Future<void> syncUser(String? userId) async {
    if (!_configured) return;
    if (userId == null) {
      if (!await Purchases.isAnonymous) await Purchases.logOut();
      return;
    }
    await Purchases.logIn(userId);
  }

  Future<SubscriptionAccess> refreshAccess() async {
    final value = await getAccess();
    accessNotifier.value = value;
    return value;
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
        // Ainda tentamos a concessão controlada pelo backend.
      }
    }

    if (_client.auth.currentUser == null) {
      return const SubscriptionAccess(kind: SubscriptionAccessKind.free);
    }

    try {
      final row = _firstRow(await _client.rpc('get_my_premium_grant'));
      if (row != null) {
        final grantType = row['grant_type'] as String?;
        final validUntil = _parseDate(row['valid_until'] as String?);
        final valid = validUntil == null || validUntil.isAfter(DateTime.now());
        if (valid && grantType == 'lifetime') {
          return const SubscriptionAccess(kind: SubscriptionAccessKind.lifetime);
        }
        if (valid && grantType == 'complimentary') {
          return SubscriptionAccess(
            kind: SubscriptionAccessKind.complimentary,
            expiresAt: validUntil,
          );
        }
      }
    } catch (_) {
      // Falha de backend não deve derrubar o app.
    }

    return const SubscriptionAccess(kind: SubscriptionAccessKind.free);
  }

  Future<SubscriptionAccess> presentPremiumPaywall() async {
    if (!_configured) {
      throw StateError(
        'A assinatura será ativada quando esta versão estiver conectada à loja.',
      );
    }
    await RevenueCatUI.presentPaywallIfNeeded(entitlementId);
    return refreshAccess();
  }

  Future<SubscriptionAccess> restorePurchases() async {
    if (!_configured) {
      throw StateError(
        'A restauração de compras estará disponível na versão da loja.',
      );
    }
    await Purchases.restorePurchases();
    return refreshAccess();
  }

  Future<SubscriptionAccess> presentCustomerCenter() async {
    if (!_configured) {
      throw StateError(
        'O gerenciamento da assinatura estará disponível na versão da loja.',
      );
    }
    await RevenueCatUI.presentCustomerCenter();
    return refreshAccess();
  }

  static Map<String, dynamic>? _firstRow(dynamic payload) {
    if (payload is List && payload.isNotEmpty && payload.first is Map) {
      return Map<String, dynamic>.from(payload.first as Map);
    }
    if (payload is Map) return Map<String, dynamic>.from(payload);
    return null;
  }

  static DateTime? _parseDate(String? value) =>
      value == null || value.isEmpty ? null : DateTime.tryParse(value)?.toLocal();
}
