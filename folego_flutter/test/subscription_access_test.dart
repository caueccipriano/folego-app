import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/subscriptions/subscription_access.dart';

void main() {
  test('free access keeps premium capabilities disabled', () {
    const provider = SubscriptionEntitlementProvider(
      SubscriptionAccess(kind: SubscriptionAccessKind.free),
    );
    expect(provider.entitlements.automationRules, isFalse);
    expect(provider.entitlements.advancedNotifications, isFalse);
  });

  test('paid, trial and granted access unlock premium capabilities', () {
    for (final kind in <SubscriptionAccessKind>[
      SubscriptionAccessKind.trial,
      SubscriptionAccessKind.premium,
      SubscriptionAccessKind.complimentary,
      SubscriptionAccessKind.lifetime,
    ]) {
      final provider = SubscriptionEntitlementProvider(
        SubscriptionAccess(kind: kind),
      );
      expect(provider.entitlements.automationRules, isTrue);
      expect(provider.entitlements.advancedNotifications, isTrue);
    }
  });
}
