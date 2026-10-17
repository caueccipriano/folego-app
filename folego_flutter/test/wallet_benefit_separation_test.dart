import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/wallet_overview.dart';

void main() {
  group('Wallet benefit separation', () {
    test('separates normal accounts from benefits and parses totals', () {
      final overview = WalletOverview.fromJson({
        'summary': {
          'total_cash': 600,
          'available_cash': 600,
          'total_benefit': 300,
          'total_card_invoice': 100,
          'total_debt_remaining': 0,
        },
        'accounts': [
          {
            'id': 'checking-1',
            'name': 'Santander',
            'type': 'checking',
            'available_for_spending': true,
            'balance': 500,
          },
          {
            'id': 'checking-2',
            'name': 'Bradesco',
            'type': 'checking',
            'available_for_spending': true,
            'balance': 100,
          },
          {
            'id': 'benefit-1',
            'name': 'Flash Alimentação',
            'type': 'benefit',
            'available_for_spending': true,
            'balance': 300,
          },
        ],
        'cards': const [],
        'debts': const [],
        'installments': const [],
      });

      expect(overview.summary.totalCash, 600);
      expect(overview.summary.totalBenefit, 300);
      expect(overview.paymentAccounts.map((item) => item.name), [
        'Santander',
        'Bradesco',
      ]);
      expect(overview.paymentAccounts.any((item) => item.isBenefit), isFalse);
      expect(overview.benefits, hasLength(1));
      expect(overview.benefits.single.name, 'Flash Alimentação');
      expect(overview.benefits.single.balance, 300);
      expect(overview.benefits.single.isBenefit, isTrue);
    });

    test('benefit remains a WalletAccount and never becomes a credit card', () {
      const benefit = WalletAccount(
        id: 'benefit-1',
        name: 'Flash Alimentação',
        type: 'benefit',
        availableForSpending: true,
        balance: 220,
      );

      expect(benefit.isBenefit, isTrue);
      expect(benefit.isCashAccount, isFalse);
      expect(benefit.balance, 220);
    });

    test('credit card invoice remains payable independently from benefits', () {
      final overview = WalletOverview.fromJson({
        'summary': const {},
        'accounts': [
          {
            'id': 'benefit-1',
            'name': 'Flash',
            'type': 'benefit',
            'available_for_spending': true,
            'balance': 220,
          },
        ],
        'cards': [
          {
            'id': 'card-1',
            'name': 'AMEX Gold',
            'closing_day': 10,
            'due_day': 15,
            'invoice_id': 'invoice-1',
            'invoice_balance': 75,
          },
        ],
        'debts': const [],
        'installments': const [],
      });

      expect(overview.benefits.single.name, 'Flash');
      expect(overview.cards.single.name, 'AMEX Gold');
      expect(overview.cards.single.invoiceId, 'invoice-1');
      expect(overview.cards.single.invoiceBalance, 75);
      expect(overview.cards.single.canPayInvoice, isTrue);
    });

    test('card without outstanding invoice does not expose payment action', () {
      const card = WalletCard(
        id: 'card-1',
        name: 'Porto',
        closingDay: 5,
        dueDay: 10,
        invoiceBalance: 0,
        invoiceId: 'invoice-1',
      );

      expect(card.canPayInvoice, isFalse);
    });
  });
}
