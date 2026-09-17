import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/realtime/realtime_invalidation.dart';

void main() {
  test('debt tables map to Home, Wallet and notifications domains', () {
    const expected = {
      AppRealtimeDomain.home,
      AppRealtimeDomain.wallet,
      AppRealtimeDomain.notifications,
    };
    expect(domainsForRealtimeTable('debts'), expected);
    expect(domainsForRealtimeTable('debt_installments'), expected);
  });

  testWidgets(
    'debt change refreshes Home, Agenda, Wallet and notifications after shared debounce',
    (tester) async {
      final coordinator = RealtimeInvalidationCoordinator();
      var homeRefreshes = 0;
      var agendaRefreshes = 0;
      var walletRefreshes = 0;
      var notificationRefreshes = 0;
      final home = coordinator.bind(
        domain: AppRealtimeDomain.home,
        onRefresh: () async => homeRefreshes += 1,
      );
      final agenda = coordinator.bind(
        domain: AppRealtimeDomain.home,
        onRefresh: () async => agendaRefreshes += 1,
      );
      final wallet = coordinator.bind(
        domain: AppRealtimeDomain.wallet,
        onRefresh: () async => walletRefreshes += 1,
      );
      final notifications = coordinator.bind(
        domain: AppRealtimeDomain.notifications,
        onRefresh: () async => notificationRefreshes += 1,
      );

      coordinator.invalidateDomains(domainsForRealtimeTable('debts'));
      await tester.pump(const Duration(milliseconds: 249));
      expect(
        (homeRefreshes, agendaRefreshes, walletRefreshes, notificationRefreshes),
        (0, 0, 0, 0),
      );
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(
        (homeRefreshes, agendaRefreshes, walletRefreshes, notificationRefreshes),
        (1, 1, 1, 1),
      );

      coordinator.invalidateDomains(
        domainsForRealtimeTable('debt_installments'),
      );
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();
      expect(
        (homeRefreshes, agendaRefreshes, walletRefreshes, notificationRefreshes),
        (2, 2, 2, 2),
      );

      home.dispose();
      agenda.dispose();
      wallet.dispose();
      notifications.dispose();
      coordinator.dispose();
    },
  );
}
