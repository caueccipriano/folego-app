import 'package:flutter/widgets.dart';

enum AppCapability {
  essentialNotifications,
  automationRules,
  bankSync,
  automaticTransactionProcessing,
  advancedNotifications,
}

class FeatureEntitlements {
  const FeatureEntitlements({
    required this.essentialNotifications,
    required this.automationRules,
    required this.bankSync,
    required this.automaticTransactionProcessing,
    required this.advancedNotifications,
  });

  final bool essentialNotifications;
  final bool automationRules;
  final bool bankSync;
  final bool automaticTransactionProcessing;
  final bool advancedNotifications;

  bool allows(AppCapability capability) => switch (capability) {
        AppCapability.essentialNotifications => essentialNotifications,
        AppCapability.automationRules => automationRules,
        AppCapability.bankSync => bankSync,
        AppCapability.automaticTransactionProcessing =>
          automaticTransactionProcessing,
        AppCapability.advancedNotifications => advancedNotifications,
      };
}

abstract interface class FeatureEntitlementProvider {
  FeatureEntitlements get entitlements;
}

class FreeEntitlementProvider implements FeatureEntitlementProvider {
  const FreeEntitlementProvider();

  @override
  FeatureEntitlements get entitlements => const FeatureEntitlements(
        essentialNotifications: true,
        automationRules: false,
        bankSync: false,
        automaticTransactionProcessing: false,
        advancedNotifications: false,
      );
}

/// Development/test-only entitlement provider.
///
/// It is deliberately injected by composition and is never persisted or read from
/// a client-editable account flag. Production defaults to [FreeEntitlementProvider].
class MockPremiumEntitlementProvider implements FeatureEntitlementProvider {
  const MockPremiumEntitlementProvider();

  @override
  FeatureEntitlements get entitlements => const FeatureEntitlements(
        essentialNotifications: true,
        automationRules: true,
        bankSync: false,
        automaticTransactionProcessing: false,
        advancedNotifications: true,
      );
}

class FeatureEntitlementsScope extends InheritedWidget {
  const FeatureEntitlementsScope({
    super.key,
    required this.provider,
    required super.child,
  });

  final FeatureEntitlementProvider provider;

  static FeatureEntitlementProvider of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<FeatureEntitlementsScope>()
            ?.provider ??
        const FreeEntitlementProvider();
  }

  @override
  bool updateShouldNotify(FeatureEntitlementsScope oldWidget) {
    return !identical(provider, oldWidget.provider);
  }
}
