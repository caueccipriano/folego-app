import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/intelligence/intelligence_plan.dart';
import 'package:folego/core/subscriptions/subscription_access.dart';

void main() {
  const free = SubscriptionAccess(kind: SubscriptionAccessKind.free);
  const premium = SubscriptionAccess(kind: SubscriptionAccessKind.premium);

  test('free simulations stop at three', () {
    expect(IntelligencePlan.maySimulate(access: free, simulationsThisMonth: 2), true);
    expect(IntelligencePlan.maySimulate(access: free, simulationsThisMonth: 3), false);
    expect(IntelligencePlan.mayAskAi(access: free, questionsThisMonth: 0), false);
  });
  test('premium AI questions stop at thirty', () {
    expect(IntelligencePlan.maySimulate(access: premium, simulationsThisMonth: 100), true);
    expect(IntelligencePlan.mayAskAi(access: premium, questionsThisMonth: 29), true);
    expect(IntelligencePlan.mayAskAi(access: premium, questionsThisMonth: 30), false);
  });
}
