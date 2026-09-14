enum CardInvoicePaymentType {
  payment,
  advance,
}

extension CardInvoicePaymentTypeX on CardInvoicePaymentType {
  String get backendValue => switch (this) {
    CardInvoicePaymentType.payment => 'payment',
    CardInvoicePaymentType.advance => 'advance',
  };

  String get label => switch (this) {
    CardInvoicePaymentType.payment => 'Pagamento',
    CardInvoicePaymentType.advance => 'Adiantamento',
  };
}

class CardInvoicePaymentState {
  const CardInvoicePaymentState({
    this.type = CardInvoicePaymentType.payment,
    this.accountId,
    this.amount = 0,
  });

  final CardInvoicePaymentType type;
  final String? accountId;
  final num amount;

  String? validate({required num outstanding}) {
    if (accountId == null || accountId!.isEmpty) {
      return 'selecione a conta que fará o pagamento';
    }

    if (amount <= 0) {
      return 'informe um valor maior que zero';
    }

    if (amount > outstanding + 0.01) {
      return 'o valor não pode ser maior que o saldo da fatura';
    }

    return null;
  }
}
