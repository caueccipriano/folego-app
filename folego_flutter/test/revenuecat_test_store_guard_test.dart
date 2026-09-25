import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/subscriptions/subscription_service.dart';

void main() {
  test('Test Store keys are distinguished from real store keys', () {
    expect(SubscriptionService.isTestStoreKey('test_example'), isTrue);
    expect(SubscriptionService.isTestStoreKey('goog_example'), isFalse);
    expect(SubscriptionService.isTestStoreKey('appl_example'), isFalse);
    expect(SubscriptionService.isTestStoreKey('sk_example'), isFalse);
  });
  test('production releases refuse test and secret SDK keys', () {
    final service = File(
      'lib/core/subscriptions/subscription_service.dart',
    ).readAsStringSync();

    expect(service, contains('if (kReleaseMode && isTestStoreKey(apiKey))'));
    expect(service, contains("if (apiKey.startsWith('sk_'))"));
  });

  test('paywall does not promise an unconfigured trial in release', () {
    final screen = File(
      'lib/features/premium/premium_screen.dart',
    ).readAsStringSync();

    expect(screen, contains('SubscriptionService.isTestStoreBuild'));
    expect(screen, contains('disponibilidade do teste grátis no checkout'));
  });
}
