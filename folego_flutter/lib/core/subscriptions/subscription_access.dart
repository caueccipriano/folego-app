import '../entitlements/feature_entitlements.dart';

enum SubscriptionAccessKind { free, trial, premium, complimentary, lifetime }

class SubscriptionAccess {
  const SubscriptionAccess({required this.kind, this.expiresAt});
  final SubscriptionAccessKind kind;
  final DateTime? expiresAt;

  bool get hasPremium => kind != SubscriptionAccessKind.free;

  String get label => switch (kind) {
        SubscriptionAccessKind.free => 'Fôlego Free',
        SubscriptionAccessKind.trial => 'Premium · teste grátis',
        SubscriptionAccessKind.premium => 'Fôlego Premium',
        SubscriptionAccessKind.complimentary => 'Premium · cortesia',
        SubscriptionAccessKind.lifetime => 'Premium · vitalício',
      };
}

class SubscriptionEntitlementProvider implements FeatureEntitlementProvider {
  const SubscriptionEntitlementProvider(this.access);
  final SubscriptionAccess access;

  @override
  FeatureEntitlements get entitlements => access.hasPremium
      ? const FeatureEntitlements(
          essentialNotifications: true,
          automationRules: true,
          bankSync: false,
          automaticTransactionProcessing: false,
          advancedNotifications: true,
        )
      : const FreeEntitlementProvider().entitlements;
}
