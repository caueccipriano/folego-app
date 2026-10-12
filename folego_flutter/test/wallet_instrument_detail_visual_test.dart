import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:folego/data/models/wallet_overview.dart';
import 'package:folego/data/repositories/folego_repository.dart';
import 'package:folego/features/wallet/wallet_instrument_detail_screen.dart';

class _AccountDetailRepository implements FolegoRepository {
  const _AccountDetailRepository(this.account);

  final WalletAccount account;

  @override
  Future<WalletOverview> getWalletOverview({required String spaceId}) async {
    return WalletOverview(
      summary: const WalletSummary(
        totalCash: 360,
        availableCash: 0,
        totalCardInvoice: 0,
        totalDebtRemaining: 0,
      ),
      accounts: [account],
      cards: const [],
      debts: const [],
      installments: const [],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('long account names keep edit and archive actions visible on iPhone', (
    tester,
  ) async {
    const account = WalletAccount(
      id: 'visual-account',
      name: 'Acerto de terceiros — mãe',
      type: 'other',
      availableForSpending: false,
      balance: 360,
    );

    for (final width in <double>[320, 375, 390, 430]) {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;

      await tester.pumpWidget(
        MaterialApp(
          home: WalletAccountDetailScreen(
            repository: _AccountDetailRepository(account),
            spaceId: 'visual-qa',
            account: account,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final title = find.byKey(const ValueKey('wallet-detail-title'));
      final edit = find.byKey(const ValueKey('wallet-detail-edit'));
      final archive = find.byKey(const ValueKey('wallet-detail-archive'));
      final back = find.byKey(const ValueKey('wallet-detail-back'));

      expect(title, findsOneWidget, reason: 'title at $width');
      expect(edit, findsOneWidget, reason: 'edit at $width');
      expect(archive, findsOneWidget, reason: 'archive at $width');
      expect(back, findsOneWidget, reason: 'back at $width');
      expect(
        tester.getTopLeft(title).dy,
        greaterThan(tester.getBottomLeft(edit).dy),
        reason: 'title starts beneath top actions at $width',
      );
      expect(find.text('R\$ 360,00'), findsOneWidget);
      expect(
        find.text('calculado pelas movimentações · sem edição direta'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull, reason: 'layout at $width');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
