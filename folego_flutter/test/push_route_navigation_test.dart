import 'package:flutter_test/flutter_test.dart';

import 'package:folego/core/navigation/push_route.dart';
import 'package:folego/features/shell/home_shell.dart';

void main() {
  test('notification routes preserve the requested financial detail', () {
    expect(pushWalletDebtId('/wallet/debt/debt-1'), 'debt-1');
    expect(pushWalletDebtId('/wallet'), isNull);

    final invoice = pushWalletInvoiceTarget(
      '/wallet/card/card-1/invoice/invoice-1',
    );
    expect(invoice, isNotNull);
    expect(invoice!.cardId, 'card-1');
    expect(invoice.invoiceId, 'invoice-1');

    final subscription = pushRecurringRouteTarget(
      '/transactions/subscriptions/sub-1',
    );
    expect(subscription, isNotNull);
    expect(subscription!.itemId, 'sub-1');
    expect(subscription.subscription, isTrue);

    final recurring = pushRecurringRouteTarget(
      '/transactions/recurring/rec-1',
    );
    expect(recurring, isNotNull);
    expect(recurring!.itemId, 'rec-1');
    expect(recurring.subscription, isFalse);

    expect(pushRecurringRouteTarget('/transactions'), isNull);
    expect(pushWalletInvoiceTarget('/wallet/card/card-1'), isNull);
  });

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
