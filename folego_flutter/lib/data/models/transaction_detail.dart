class TransactionDetailAccountImpact {
  const TransactionDetailAccountImpact({
    required this.dimension,
    required this.amount,
    this.accountId,
    this.accountName,
    this.accountType,
  });

  final String dimension;
  final double amount;
  final String? accountId;
  final String? accountName;
  final String? accountType;
}

class TransactionDetailInstallment {
  const TransactionDetailInstallment({
    required this.id,
    required this.number,
    required this.total,
    required this.amount,
    required this.competenceDate,
    required this.status,
    this.invoiceId,
    this.invoiceReferenceMonth,
    this.invoiceClosingDate,
    this.invoiceDueDate,
    this.invoiceStatus,
  });

  final String id;
  final int number;
  final int total;
  final double amount;
  final DateTime competenceDate;
  final String status;
  final String? invoiceId;
  final DateTime? invoiceReferenceMonth;
  final DateTime? invoiceClosingDate;
  final DateTime? invoiceDueDate;
  final String? invoiceStatus;
}

class TransactionDetail {
  const TransactionDetail({
    required this.id,
    required this.spaceId,
    required this.eventType,
    required this.description,
    required this.amount,
    required this.occurredAt,
    required this.status,
    required this.source,
    required this.impacts,
    this.competenceDate,
    this.categoryId,
    this.categoryName,
    this.categoryParentName,
    this.legacyException = false,
    this.legacyKind,
    this.legacyTitle,
    this.legacyMessage,
    this.cardPurchaseId,
    this.cardId,
    this.cardName,
    this.cardMerchant,
    this.cardPurchaseAt,
    this.cardInstallmentsCount,
    this.cardPurchaseStatus,
    this.installments = const [],
    this.cardPurchaseFinancialEditable = false,
    this.cardPurchaseReversible = false,
    this.cardPurchaseRestriction,
    this.cardPaymentId,
    this.cardPaymentInvoiceId,
    this.cardPaymentAccountId,
    this.cardPaymentAccountName,
    this.cardPaymentType,
    this.cardPaymentStatus,
    this.cardPaymentPaidAt,
    this.cardPaymentInvoiceStatus,
    this.cardPaymentInvoiceDueDate,
    this.cardPaymentReversible = false,
    this.cardPaymentRestriction,
    this.recurringItemId,
    this.recurringItemName,
    this.recurringOccurrenceId,
    this.recurringDueDate,
    this.reflectionType,
    this.reflectionNote,
    this.debtName,
    this.debtCreditor,
  });

  final String id;
  final String spaceId;
  final String eventType;
  final String description;
  final double amount;
  final DateTime occurredAt;
  final DateTime? competenceDate;
  final String status;
  final String source;
  final String? categoryId;
  final String? categoryName;
  final String? categoryParentName;
  final List<TransactionDetailAccountImpact> impacts;

  final bool legacyException;
  final String? legacyKind;
  final String? legacyTitle;
  final String? legacyMessage;

  final String? cardPurchaseId;
  final String? cardId;
  final String? cardName;
  final String? cardMerchant;
  final DateTime? cardPurchaseAt;
  final int? cardInstallmentsCount;
  final String? cardPurchaseStatus;
  final List<TransactionDetailInstallment> installments;
  final bool cardPurchaseFinancialEditable;
  final bool cardPurchaseReversible;
  final String? cardPurchaseRestriction;

  final String? cardPaymentId;
  final String? cardPaymentInvoiceId;
  final String? cardPaymentAccountId;
  final String? cardPaymentAccountName;
  final String? cardPaymentType;
  final String? cardPaymentStatus;
  final DateTime? cardPaymentPaidAt;
  final String? cardPaymentInvoiceStatus;
  final DateTime? cardPaymentInvoiceDueDate;
  final bool cardPaymentReversible;
  final String? cardPaymentRestriction;

  final String? recurringItemId;
  final String? recurringItemName;
  final String? recurringOccurrenceId;
  final DateTime? recurringDueDate;

  final String? reflectionType;
  final String? reflectionNote;

  final String? debtName;
  final String? debtCreditor;

  bool get isSimple => eventType == 'income' || eventType == 'expense';
  bool get isCardPurchase => eventType == 'card_purchase';
  bool get isBenefitExpense => eventType == 'benefit_expense';
  bool get isCanonicalTransfer =>
      eventType == 'transfer' && !legacyException && sourceAccountId != null && destinationAccountId != null;
  bool get isCardPayment => eventType == 'card_payment';

  TransactionDetailAccountImpact? get sourceImpact {
    for (final impact in impacts) {
      if (impact.dimension == 'cash' && impact.amount < 0) return impact;
    }
    return null;
  }

  TransactionDetailAccountImpact? get destinationImpact {
    for (final impact in impacts) {
      if (impact.dimension == 'cash' && impact.amount > 0) return impact;
    }
    return null;
  }

  TransactionDetailAccountImpact? get benefitImpact {
    for (final impact in impacts) {
      if (impact.dimension == 'benefit') return impact;
    }
    return null;
  }

  String? get sourceAccountId => sourceImpact?.accountId;
  String? get sourceAccountName => sourceImpact?.accountName;
  String? get destinationAccountId => destinationImpact?.accountId;
  String? get destinationAccountName => destinationImpact?.accountName;
  String? get benefitAccountId => benefitImpact?.accountId;
  String? get benefitAccountName => benefitImpact?.accountName;

  bool get canEdit {
    if (legacyException || status != 'confirmed') return false;
    return isSimple || isCardPurchase || isBenefitExpense || isCanonicalTransfer;
  }

  bool get canReverse {
    if (legacyException || status != 'confirmed') return false;
    if (isSimple) return true;
    if (isCardPurchase) return cardPurchaseReversible;
    if (isBenefitExpense) return true;
    if (isCanonicalTransfer) return true;
    if (isCardPayment) return cardPaymentReversible;
    return false;
  }

  String get typeLabel {
    switch (eventType) {
      case 'income': return 'receita';
      case 'expense': return 'gasto';
      case 'card_purchase': return 'compra no cartão';
      case 'card_payment': return 'pagamento de fatura';
      case 'benefit_expense': return 'gasto com benefício';
      case 'benefit_credit': return 'crédito de benefício';
      case 'transfer': return legacyKind == 'financing_inflow_missing_liability_details'
          ? 'entrada de financiamento'
          : 'transferência';
      case 'debt_payment': return 'pagamento de dívida';
      case 'opening_balance': return 'saldo inicial';
      case 'refund': return 'estorno';
      case 'reimbursement': return 'reembolso';
      case 'reserve_transfer': return 'movimento de reserva';
      case 'adjustment': return 'ajuste';
      default: return eventType.replaceAll('_', ' ');
    }
  }
}
