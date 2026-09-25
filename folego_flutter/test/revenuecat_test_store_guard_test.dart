import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/subscriptions/subscription_service.dart';

void main() {
  test('Test Store keys are distinguished from real store keys', () {
    expect(SubscriptionService.isTestStoreKey('test_example'), isTrue);
    expect(SubscriptionService.isTestStoreKey('goog_example'), isFalse);
    expect(SubscriptionService.isTestStoreKey('appl_example'), isFalse);
    expect(SubscriptionService.isTestStoreKey('sk_example'), isFalse);
  });
}
