import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/realtime/realtime_invalidation.dart';

void main() {
  test('debt tables map to the existing Home/Agenda and Wallet domains', () {
    expect(domainsForRealtimeTable('debts'), {AppRealtimeDomain.home, AppRealtimeDomain.wallet});
    expect(domainsForRealtimeTable('debt_installments'), {AppRealtimeDomain.home, AppRealtimeDomain.wallet});
  });

  testWidgets('debt change refreshes Home, Agenda and Wallet after shared debounce', (tester) async {
    final coordinator = RealtimeInvalidationCoordinator();
    var homeRefreshes = 0;
    var agendaRefreshes = 0;
    var walletRefreshes = 0;
    final home = coordinator.bind(domain: AppRealtimeDomain.home, onRefresh: () async => homeRefreshes += 1);
    final agenda = coordinator.bind(domain: AppRealtimeDomain.home, onRefresh: () async => agendaRefreshes += 1);
    final wallet = coordinator.bind(domain: AppRealtimeDomain.wallet, onRefresh: () async => walletRefreshes += 1);

    coordinator.invalidateDomains(domainsForRealtimeTable('debts'));
    await tester.pump(const Duration(milliseconds: 249));
    expect((homeRefreshes, agendaRefreshes, walletRefreshes), (0, 0, 0));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect((homeRefreshes, agendaRefreshes, walletRefreshes), (1, 1, 1));

    coordinator.invalidateDomains(domainsForRealtimeTable('debt_installments'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    expect((homeRefreshes, agendaRefreshes, walletRefreshes), (2, 2, 2));

    home.dispose();
    agenda.dispose();
    wallet.dispose();
    coordinator.dispose();
  });
}
