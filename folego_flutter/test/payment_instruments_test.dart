import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/account_item.dart';
import 'package:folego/data/models/credit_card_item.dart';

void main() {
  group('AccountItem', () {
    test('parses checking as a normal payment account', () {
      final account = AccountItem.fromJson({
        'id': 'checking-1',
        'name': 'Santander',
        'type': 'checking',
      });

      expect(account.type, 'checking');
      expect(account.isBenefit, isFalse);
      expect(account.isPaymentAccount, isTrue);
    });

    test('parses benefit and exposes the centralized helper', () {
      final account = AccountItem.fromJson({
        'id': 'benefit-1',
        'name': 'Flash Alimentação',
        'type': 'benefit',
      });

      expect(account.type, AccountItem.benefitType);
      expect(account.isBenefit, isTrue);
      expect(account.isPaymentAccount, isFalse);
    });

    test('payment-account filtering excludes benefit accounts', () {
      final accounts = [
        const AccountItem(id: '1', name: 'Santander', type: 'checking'),
        const AccountItem(id: '2', name: 'Flash', type: 'benefit'),
        const AccountItem(id: '3', name: 'Reserva', type: 'reserve'),
      ];

      final paymentAccounts = accounts
          .where((account) => account.isPaymentAccount)
          .toList();

      expect(paymentAccounts.map((account) => account.id), ['1', '3']);
      expect(paymentAccounts.any((account) => account.isBenefit), isFalse);
    });

    test('benefit filtering contains only benefit accounts', () {
      final accounts = [
        const AccountItem(id: '1', name: 'Santander', type: 'checking'),
        const AccountItem(id: '2', name: 'Flash', type: 'benefit'),
      ];

      final benefits = accounts.where((account) => account.isBenefit).toList();

      expect(benefits, hasLength(1));
      expect(benefits.single.id, '2');
    });

    test('legacy parsing remains compatible when type was not selected', () {
      final account = AccountItem.fromJson({
        'id': 'legacy-1',
        'name': 'Conta antiga',
      });

      expect(account.type, isNull);
      expect(account.hasKnownType, isFalse);
      expect(account.isBenefit, isFalse);
      expect(account.isPaymentAccount, isFalse);
    });
  });

  group('CreditCardItem', () {
    test('parses an active credit card independently from accounts', () {
      final card = CreditCardItem.fromJson({
        'id': 'card-1',
        'name': 'AMEX Gold',
        'issuer': 'Bradesco',
        'brand': 'American Express',
        'last_four': '5568',
        'active': true,
      });

      expect(card.id, 'card-1');
      expect(card.name, 'AMEX Gold');
      expect(card.issuer, 'Bradesco');
      expect(card.brand, 'American Express');
      expect(card.lastFour, '5568');
      expect(card.active, isTrue);
    });

    test('parsing tolerates optional card metadata', () {
      final card = CreditCardItem.fromJson({
        'id': 'card-2',
        'name': 'Cartão',
        'issuer': null,
        'brand': '',
        'last_four': null,
      });

      expect(card.issuer, isNull);
      expect(card.brand, isNull);
      expect(card.lastFour, isNull);
      expect(card.active, isTrue);
    });
  });
}
