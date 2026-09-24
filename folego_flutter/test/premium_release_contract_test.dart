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

  test('authentication does not log full errors or stack traces', () {
    final auth =
        File('lib/features/auth/auth_screen.dart').readAsStringSync();

    expect(auth, isNot(contains(r'Auth action failed: $error')));
    expect(auth, isNot(contains('stackTrace')));
    expect(auth, contains('error.runtimeType'));
  });
}
