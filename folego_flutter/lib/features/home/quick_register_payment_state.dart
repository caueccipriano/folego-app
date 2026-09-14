enum QuickExpensePaymentType {
  account,
  creditCard,
  benefit,
}

enum QuickExpenseSaveTarget {
  expense,
  cardPurchase,
  benefitExpense,
}

class QuickExpensePaymentState {
  const QuickExpensePaymentState({
    this.type = QuickExpensePaymentType.account,
    this.accountId,
    this.cardId,
    this.benefitAccountId,
    this.installmentsCount = 1,
  });

  final QuickExpensePaymentType type;
  final String? accountId;
  final String? cardId;
  final String? benefitAccountId;
  final int installmentsCount;

  bool get supportsRecurring => type == QuickExpensePaymentType.account;

  QuickExpenseSaveTarget get saveTarget => switch (type) {
    QuickExpensePaymentType.account => QuickExpenseSaveTarget.expense,
    QuickExpensePaymentType.creditCard => QuickExpenseSaveTarget.cardPurchase,
    QuickExpensePaymentType.benefit => QuickExpenseSaveTarget.benefitExpense,
  };

  String? get selectedInstrumentId => switch (type) {
    QuickExpensePaymentType.account => accountId,
    QuickExpensePaymentType.creditCard => cardId,
    QuickExpensePaymentType.benefit => benefitAccountId,
  };

  QuickExpensePaymentState select(QuickExpensePaymentType next) {
    return switch (next) {
      QuickExpensePaymentType.account => QuickExpensePaymentState(
          type: next,
          accountId: accountId,
        ),
      QuickExpensePaymentType.creditCard => QuickExpensePaymentState(
          type: next,
          cardId: cardId,
          installmentsCount: installmentsCount,
        ),
      QuickExpensePaymentType.benefit => QuickExpensePaymentState(
          type: next,
          benefitAccountId: benefitAccountId,
        ),
    };
  }

  QuickExpensePaymentState withAccountId(String? value) {
    return QuickExpensePaymentState(
      type: QuickExpensePaymentType.account,
      accountId: value,
    );
  }

  QuickExpensePaymentState withCardId(String? value) {
    return QuickExpensePaymentState(
      type: QuickExpensePaymentType.creditCard,
      cardId: value,
      installmentsCount: installmentsCount,
    );
  }

  QuickExpensePaymentState withBenefitAccountId(String? value) {
    return QuickExpensePaymentState(
      type: QuickExpensePaymentType.benefit,
      benefitAccountId: value,
    );
  }

  QuickExpensePaymentState withInstallmentsCount(int value) {
    return QuickExpensePaymentState(
      type: QuickExpensePaymentType.creditCard,
      cardId: cardId,
      installmentsCount: value,
    );
  }
}
