import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web entry remains free while native Premium uses store billing', () {
    final upgrade = File(
      'lib/features/premium/premium_screen.dart',
    ).readAsStringSync();
    final app = File('lib/app.dart').readAsStringSync();
    final main = File('lib/main.dart').readAsStringSync();

    expect(upgrade, contains('if (kIsWeb) return true;'));
    expect(app, contains('kIsWeb'));
    expect(app, contains('const FreeEntitlementProvider()'));
    expect(app, contains('SubscriptionEntitlementProvider(access)'));
    expect(main, contains('if (kIsWeb)'));
    expect(main, contains('localStorage: SecureSessionStorage()'));
    expect(main, contains('addPostFrameCallback'));
    expect(main.indexOf('runApp('), lessThan(main.indexOf('unawaited(_refreshPremiumAfterLaunch')));
  });

  test('native paywalls gate only advanced features, not core money entry', () {
    final plan = File('lib/features/plan/plan_screen.dart').readAsStringSync();
    final transactions =
        File('lib/features/transactions/transactions_screen.dart')
            .readAsStringSync();
    final profile =
        File('lib/features/profile/profile_screen_v2.dart').readAsStringSync();

    expect(plan, contains("feature: 'projeções e cenários futuros'"));
    expect(transactions, contains("feature: 'importação de extratos CSV e OFX'"));
    expect(profile, contains("feature: 'automações inteligentes'"));
    expect(profile, contains("feature: 'exportação dos seus dados em CSV'"));
    expect(profile, contains('if (!kIsWeb)'));
    expect(profile, contains("title: 'privacidade e termos'"));
  });
}
