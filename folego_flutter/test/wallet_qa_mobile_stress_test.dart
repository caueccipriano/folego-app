import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:folego/core/privacy/financial_privacy.dart';
import 'package:folego/data/models/wallet_overview.dart';
import 'package:folego/data/repositories/folego_repository.dart';
import 'package:folego/features/wallet/wallet_screen_base.dart';

class _WalletQaRepository implements FolegoRepository {
  @override
  Future<WalletOverview> getWalletOverview({required String spaceId}) async {
    return WalletOverview(
      summary: const WalletSummary(
        totalCash: 12345678.91,
        availableCash: -987654.32,
        totalBenefit: 12345.67,
        totalCardInvoice: 13500.90,
        totalDebtRemaining: 9876543.21,
      ),
      accounts: const [
        WalletAccount(
          id: 'acc-1',
          name: 'Conta principal com um nome propositalmente muito longo',
          institution: 'Instituição Financeira Extremamente Longa',
          type: 'checking',
          availableForSpending: true,
          balance: -987654.32,
        ),
        WalletAccount(
          id: 'benefit-1',
          name: 'Benefício alimentação corporativo com nome longo',
          institution: 'Flash',
          type: 'benefit',
          availableForSpending: false,
          balance: 12345.67,
        ),
      ],
      cards: [
        WalletCard(
          id: 'card-1',
          name: 'Cartão principal internacional nome muito longo',
          issuer: 'Banco emissor com nome longo',
          brand: 'Mastercard',
          lastFour: '1234',
          closingDay: 5,
          dueDay: 10,
          invoiceBalance: 13500.90,
          personalLimit: 10000,
          issuerLimit: 15000,
          availableLimit: -3500.90,
          invoiceId: 'invoice-1',
          invoiceDueDate: DateTime(2026, 10, 10),
        ),
      ],
      debts: [
        WalletDebt(
          id: 'debt-1',
          name: 'Empréstimo pessoal com descrição extremamente comprida',
          creditor: 'Instituição credora muito longa',
          originalAmount: 12000000,
          openingBalance: 12000000,
          remainingBalance: 9876543.21,
          nextAmount: 876543.21,
          paidInstallments: 3,
          totalInstallments: 24,
          nextDueDate: DateTime(2026, 10, 15),
        ),
      ],
      installments: const [],
    );
  }


  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  setUp(() {
    FinancialPrivacy.hidden.value = false;
  });

  testWidgets('wallet survives narrow iPhones and extreme values across sections', (
    tester,
  ) async {
    for (final width in <double>[320, 375, 390]) {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;

      await tester.pumpWidget(
        MaterialApp(
          home: WalletScreen(
            repository: _WalletQaRepository(),
            spaceId: 'space-qa',
            onAddRequested: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('carteira'), findsOneWidget, reason: 'width $width');
      expect(tester.takeException(), isNull, reason: 'accounts at $width');

      for (final section in <String>['cartões', 'benefícios', 'dívidas']) {
        await tester.tap(find.text(section).first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$section at $width');
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('over-limit card keeps usage visible instead of clipping the value', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: WalletScreen(
          repository: _WalletQaRepository(),
          spaceId: 'space-qa',
          onAddRequested: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('cartões').first);
    await tester.pumpAndSettle();

    expect(find.text('135%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
