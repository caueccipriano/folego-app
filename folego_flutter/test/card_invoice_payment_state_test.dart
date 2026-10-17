import 'package:flutter_test/flutter_test.dart';
import 'package:folego/features/wallet/card_invoice_payment_state.dart';

void main() {
  group('CardInvoicePaymentType', () {
    test('normal payment uses backend payment type', () {
      expect(CardInvoicePaymentType.payment.backendValue, 'payment');
      expect(CardInvoicePaymentType.payment.label, 'Pagamento');
    });

    test('advance uses backend advance type', () {
      expect(CardInvoicePaymentType.advance.backendValue, 'advance');
      expect(CardInvoicePaymentType.advance.label, 'Adiantamento');
    });
  });

  group('CardInvoicePaymentState', () {
    test('accepts a valid full payment', () {
      const state = CardInvoicePaymentState(
        accountId: 'account-1',
        amount: 100,
      );

      expect(state.validate(outstanding: 100), isNull);
    });

    test('accepts a valid partial payment', () {
      const state = CardInvoicePaymentState(
        accountId: 'account-1',
        amount: 40,
      );

      expect(state.validate(outstanding: 100), isNull);
    });

    test('blocks save without a payment account', () {
      const state = CardInvoicePaymentState(amount: 100);

      expect(
        state.validate(outstanding: 100),
        'selecione a conta que fará o pagamento',
      );
    });

    test('blocks zero amount', () {
      const state = CardInvoicePaymentState(
        accountId: 'account-1',
        amount: 0,
      );

      expect(
        state.validate(outstanding: 100),
        'informe um valor maior que zero',
      );
    });

    test('blocks amount above outstanding balance', () {
      const state = CardInvoicePaymentState(
        accountId: 'account-1',
        amount: 101,
      );

      expect(
        state.validate(outstanding: 100),
        'o valor não pode ser maior que o saldo da fatura',
      );
    });

    test('advance keeps the same financial amount validation', () {
      const state = CardInvoicePaymentState(
        type: CardInvoicePaymentType.advance,
        accountId: 'account-1',
        amount: 50,
      );

      expect(state.type.backendValue, 'advance');
      expect(state.validate(outstanding: 100), isNull);
    });
  });
}
