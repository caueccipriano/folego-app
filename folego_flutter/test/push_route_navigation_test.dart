import 'package:flutter_test/flutter_test.dart';

import 'package:folego/features/shell/home_shell.dart';

void main() {
  test('push routes open the related primary app tab', () {
    expect(homeIndexForPushRoute(null), 0);
    expect(homeIndexForPushRoute('/'), 0);
    expect(homeIndexForPushRoute('/agenda'), 0);

    expect(homeIndexForPushRoute('/transactions'), 1);
    expect(homeIndexForPushRoute('/transactions/recurring/rec-1'), 1);
    expect(homeIndexForPushRoute('/transactions/subscriptions/sub-1'), 1);

    expect(homeIndexForPushRoute('/plan'), 2);

    expect(homeIndexForPushRoute('/wallet'), 3);
    expect(homeIndexForPushRoute('/wallet/debt/debt-1'), 3);
    expect(homeIndexForPushRoute('/wallet/card/card-1/invoice/invoice-1'), 3);

    expect(homeIndexForPushRoute('/profile'), 4);
    expect(homeIndexForPushRoute('/unknown'), 0);
  });
}
