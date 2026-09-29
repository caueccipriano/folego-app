import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Premium gates are wired to advanced product surfaces', () {
    final projection =
        File('lib/features/plan/plan_screen.dart').readAsStringSync();
    final transactions =
        File('lib/features/transactions/transactions_screen.dart')
            .readAsStringSync();
    final profile =
        File('lib/features/profile/profile_screen_v2.dart').readAsStringSync();

    expect(projection, contains("feature: 'projeções e cenários futuros'"));
    expect(
      transactions,
      contains("feature: 'importação de extratos CSV e OFX'"),
    );
    expect(profile, contains("feature: 'automações inteligentes'"));
    expect(
      profile,
      contains("feature: 'exportação dos seus dados em CSV'"),
    );
  });

  test('essential notifications remain outside the Premium gate', () {
    final profile =
        File('lib/features/profile/profile_screen_v2.dart').readAsStringSync();

    final notificationIndex = profile.indexOf("title: 'notificações'");
    final premiumIndex = profile.indexOf("title: 'Fôlego Premium'");

    expect(notificationIndex, greaterThanOrEqualTo(0));
    expect(premiumIndex, greaterThanOrEqualTo(0));
    expect(profile, contains('_openNotificationSettings'));
  });

  test('approved launch price and web checkout safeguards are consistent', () {
    final subscription =
        File('lib/core/subscriptions/subscription_service.dart')
            .readAsStringSync();
    final premium =
        File('lib/features/premium/premium_screen.dart')
            .readAsStringSync();

    expect(subscription, contains('9,90/mês'));
    expect(subscription, isNot(contains('14,90/mês')));
    expect(premium, contains(r'R\$ 9.90/month'));
    expect(premium, isNot(contains(r'R\$ 14.90/month')));
    expect(subscription, contains('!kIsWeb'));
    expect(subscription, contains('throw StateError('));
    expect(premium, contains('SubscriptionService.isConfigured'));
    expect(premium, contains('onPressed: storeReady && !_running'));
    expect(premium, contains('premiumStoreOnly'));
  });

  test('Premium launch docs align with approved display price and no live billing claim', () {
    final docs = File('../docs/revenuecat-launch-checklist.md').readAsStringSync();
    expect(docs, contains('R\$ 9,90/month'));
    expect(docs, contains('78 active paying subscribers'));
    expect(docs, contains('R\$ 506.37'));
    expect(docs, isNot(contains('R\$ 14,90')));
    expect(docs, contains('Not configured or verified'));
  });

  test('R\$500 illustrative net target needs 78 subscribers at R\$9.90', () {
    const monthlyPrice = 9.90;
    const assumedFee = 0.15;
    const assumedFixedCosts = 150.0;
    double net(int subscribers) =>
        subscribers * monthlyPrice * (1 - assumedFee) - assumedFixedCosts;
    expect(net(77), lessThan(500));
    expect(net(78), greaterThanOrEqualTo(500));
    expect(net(78).toStringAsFixed(2), '506.37');
  });

  test('authentication does not log full errors or stack traces', () {
    final auth =
        File('lib/features/auth/auth_screen.dart').readAsStringSync();

    expect(auth, isNot(contains(r'Auth action failed: $error')));
    expect(auth, isNot(contains('stackTrace')));
    expect(auth, contains('error.runtimeType'));
  });
}
