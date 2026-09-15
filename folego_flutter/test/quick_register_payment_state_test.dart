import 'package:flutter_test/flutter_test.dart';
import 'package:folego/features/home/quick_register_payment_state.dart';

void main() {
  group('QuickExpensePaymentState', () {
    test('defaults to account and one installment', () {
      const state = QuickExpensePaymentState(accountId: 'account-1');

      expect(state.type, QuickExpensePaymentType.account);
      expect(state.installmentsCount, 1);
      expect(state.supportsRecurring, isTrue);
      expect(state.recurringAccountId, 'account-1');
      expect(state.recurringCardId, isNull);
      expect(state.saveTarget, QuickExpenseSaveTarget.expense);
    });

    test('switching account to card clears incompatible account id', () {
      const state = QuickExpensePaymentState(accountId: 'account-1');

      final next = state.select(QuickExpensePaymentType.creditCard);

      expect(next.accountId, isNull);
      expect(next.benefitAccountId, isNull);
      expect(next.type, QuickExpensePaymentType.creditCard);
      expect(next.saveTarget, QuickExpenseSaveTarget.cardPurchase);
      expect(next.supportsRecurring, isTrue);
    });

    test('card recurrence exposes card id and keeps account id null', () {
      final state = const QuickExpensePaymentState()
          .select(QuickExpensePaymentType.creditCard)
          .withCardId('card-1');

      expect(state.recurringAccountId, isNull);
      expect(state.recurringCardId, 'card-1');
      expect(state.supportsRecurring, isTrue);
    });

    test('switching card to benefit clears card id', () {
      final state = const QuickExpensePaymentState()
          .select(QuickExpensePaymentType.creditCard)
          .withCardId('card-1')
          .withInstallmentsCount(6);

      final next = state.select(QuickExpensePaymentType.benefit);

      expect(next.cardId, isNull);
      expect(next.accountId, isNull);
      expect(next.installmentsCount, 1);
      expect(next.type, QuickExpensePaymentType.benefit);
      expect(next.saveTarget, QuickExpenseSaveTarget.benefitExpense);
      expect(next.supportsRecurring, isFalse);
      expect(next.recurringAccountId, isNull);
      expect(next.recurringCardId, isNull);
    });

    test('card installments can be changed without selecting another source', () {
      final state = const QuickExpensePaymentState()
          .select(QuickExpensePaymentType.creditCard)
          .withCardId('card-1')
          .withInstallmentsCount(12);

      expect(state.cardId, 'card-1');
      expect(state.installmentsCount, 12);
      expect(state.accountId, isNull);
      expect(state.benefitAccountId, isNull);
    });

    test('each payment type exposes only its compatible selected id', () {
      final account = const QuickExpensePaymentState().withAccountId('a');
      final card = account
          .select(QuickExpensePaymentType.creditCard)
          .withCardId('c');
      final benefit = card
          .select(QuickExpensePaymentType.benefit)
          .withBenefitAccountId('b');

      expect(account.selectedInstrumentId, 'a');
      expect(card.selectedInstrumentId, 'c');
      expect(benefit.selectedInstrumentId, 'b');
    });
  });
}
