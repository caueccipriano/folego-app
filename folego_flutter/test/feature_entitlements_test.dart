import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/entitlements/feature_entitlements.dart';

void main() {
  test('free keeps essential notifications and premium-only capabilities closed', () {
    const provider = FreeEntitlementProvider();
    final entitlements = provider.entitlements;

    expect(entitlements.essentialNotifications, isTrue);
    expect(entitlements.automationRules, isFalse);
    expect(entitlements.bankSync, isFalse);
    expect(entitlements.automaticTransactionProcessing, isFalse);
    expect(entitlements.advancedNotifications, isFalse);
  });

  test('mock premium is explicit composition and never enables bank sync', () {
    const provider = MockPremiumEntitlementProvider();
    final entitlements = provider.entitlements;

    expect(entitlements.essentialNotifications, isTrue);
    expect(entitlements.automationRules, isTrue);
    expect(entitlements.advancedNotifications, isTrue);
    expect(entitlements.bankSync, isFalse);
    expect(entitlements.automaticTransactionProcessing, isFalse);
  });
}
