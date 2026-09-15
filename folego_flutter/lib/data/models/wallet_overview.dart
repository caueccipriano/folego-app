class WalletOverview {
  const WalletOverview({
    required this.summary,
    required this.accounts,
    required this.cards,
    required this.debts,
    required this.installments,
  });

  final WalletSummary summary;
  final List<WalletAccount> accounts;
  final List<WalletCard> cards;
  final List<WalletDebt> debts;
  final List<WalletInstallment> installments;

  List<WalletAccount> get paymentAccounts => accounts
      .where((account) => !account.isBenefit)
      .toList(growable: false);

  List<WalletAccount> get benefits => accounts
      .where((account) => account.isBenefit)
      .toList(growable: false);

  factory WalletOverview.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> list(String key) {
      final value = json[key];
      if (value is! List) return [];
      return value
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }

    return WalletOverview(
      summary: WalletSummary.fromJson(
        Map<String, dynamic>.from((json['summary'] as Map?) ?? {}),
      ),
      accounts: list('accounts').map(WalletAccount.fromJson).toList(),
      cards: list('cards').map(WalletCard.fromJson).toList(),
      debts: list('debts').map(WalletDebt.fromJson).toList(),
      installments: list('installments')
          .map(WalletInstallment.fromJson)
          .toList(),
    );
  }
}

class WalletSummary {
  const WalletSummary({
    required this.totalCash,
    required this.availableCash,
    required this.totalCardInvoice,
    required this.totalDebtRemaining,
    this.totalBenefit = 0,
  });

  final double totalCash;
  final double availableCash;
  final double totalBenefit;
  final double totalCardInvoice;
  final double totalDebtRemaining;

  factory WalletSummary.fromJson(Map<String, dynamic> json) {
    return WalletSummary(
      totalCash: _number(json['total_cash']),
      availableCash: _number(json['available_cash']),
      totalBenefit: _number(json['total_benefit']),
      totalCardInvoice: _number(json['total_card_invoice']),
      totalDebtRemaining: _number(json['total_debt_remaining']),
    );
  }
}

class WalletAccount {
  const WalletAccount({
    required this.id,
    required this.name,
    required this.type,
    required this.availableForSpending,
    required this.balance,
    this.institution,
  });

  static const benefitType = 'benefit';

  final String id;
  final String name;
  final String? institution;
  final String type;
  final bool availableForSpending;
  final double balance;

  bool get isBenefit => type == benefitType;
  bool get isCashAccount => !isBenefit;

  factory WalletAccount.fromJson(Map<String, dynamic> json) {
    return WalletAccount(
      id: json['id'] as String,
      name: json['name'] as String,
      institution: json['institution'] as String?,
      type: json['type'] as String,
      availableForSpending:
          json['available_for_spending'] as bool? ?? false,
      balance: _number(json['balance']),
    );
  }
}

class WalletCard {
  const WalletCard({
    required this.id,
    required this.name,
    required this.closingDay,
    required this.dueDay,
    required this.invoiceBalance,
    this.issuer,
    this.brand,
    this.lastFour,
    this.personalLimit,
    this.issuerLimit,
    this.paymentAccountId,
    this.invoiceId,
    this.invoiceDueDate,
    this.availableLimit,
  });

  final String id;
  final String name;
  final String? issuer;
  final String? brand;
  final String? lastFour;
  final int closingDay;
  final int dueDay;
  final double? personalLimit;
  final double? issuerLimit;
  final double? availableLimit;
  final String? paymentAccountId;
  final String? invoiceId;
  final DateTime? invoiceDueDate;
  final double invoiceBalance;

  double? get effectiveLimit => personalLimit ?? issuerLimit;

  double? get usedLimit {
    if (effectiveLimit == null) return null;
    return invoiceBalance;
  }

  double? get limitUsageRatio {
    final limit = effectiveLimit;
    if (limit == null || limit <= 0) return null;
    return invoiceBalance / limit;
  }

  bool get canPayInvoice => invoiceId != null && invoiceBalance > 0;

  factory WalletCard.fromJson(Map<String, dynamic> json) {
    return WalletCard(
      id: json['id'] as String,
      name: json['name'] as String,
      issuer: json['issuer'] as String?,
      brand: json['brand'] as String?,
      lastFour: json['last_four']?.toString(),
      closingDay: (json['closing_day'] as num).toInt(),
      dueDay: (json['due_day'] as num).toInt(),
      personalLimit: _nullableNumber(json['personal_limit']),
      issuerLimit: _nullableNumber(json['issuer_limit']),
      availableLimit: _nullableNumber(json['available_limit']),
      paymentAccountId: json['payment_account_id'] as String?,
      invoiceId: json['invoice_id'] as String?,
      invoiceDueDate: _nullableDate(json['due_date']),
      invoiceBalance: _number(json['invoice_balance']),
    );
  }
}

class WalletDebt {
  const WalletDebt({
    required this.id,
    required this.name,
    required this.openingBalance,
    required this.remainingBalance,
    required this.nextAmount,
    required this.paidInstallments,
    this.creditor,
    this.originalAmount,
    this.totalInstallments,
    this.paymentAccountId,
    this.nextDueDate,
  });

  final String id;
  final String name;
  final String? creditor;
  final double? originalAmount;
  final double openingBalance;
  final double remainingBalance;
  final int? totalInstallments;
  final int paidInstallments;
  final String? paymentAccountId;
  final DateTime? nextDueDate;
  final double nextAmount;

  double? get paidAmount {
    final original = originalAmount;
    if (original == null) return null;
    final paid = original - remainingBalance;
    if (paid < 0) return 0;
    if (paid > original) return original;
    return paid;
  }

  double? get progress {
    final original = originalAmount;
    final paid = paidAmount;
    if (original == null || original <= 0 || paid == null) return null;
    return (paid / original).clamp(0.0, 1.0).toDouble();
  }

  factory WalletDebt.fromJson(Map<String, dynamic> json) {
    return WalletDebt(
      id: json['id'] as String,
      name: json['name'] as String,
      creditor: json['creditor'] as String?,
      originalAmount: _nullableNumber(json['original_amount']),
      openingBalance: _number(json['opening_balance']),
      remainingBalance: _number(json['remaining_balance']),
      totalInstallments: (json['total_installments'] as num?)?.toInt(),
      paidInstallments:
          (json['paid_installments'] as num?)?.toInt() ?? 0,
      paymentAccountId: json['payment_account_id'] as String?,
      nextDueDate: _nullableDate(json['next_due_date']),
      nextAmount: _number(json['next_amount']),
    );
  }
}

class WalletInstallment {
  const WalletInstallment({
    required this.id,
    required this.description,
    required this.totalAmount,
    required this.installmentsCount,
    required this.cardId,
    required this.cardName,
    required this.remainingInstallments,
    required this.remainingAmount,
    this.merchant,
    this.nextDueDate,
  });

  final String id;
  final String description;
  final String? merchant;
  final double totalAmount;
  final int installmentsCount;
  final String cardId;
  final String cardName;
  final int remainingInstallments;
  final double remainingAmount;
  final DateTime? nextDueDate;

  int get paidInstallments {
    final paid = installmentsCount - remainingInstallments;
    if (paid < 0) return 0;
    if (paid > installmentsCount) return installmentsCount;
    return paid;
  }

  bool get isCompleted => remainingInstallments <= 0;

  double get progress {
    if (installmentsCount <= 0) return 0;
    return (paidInstallments / installmentsCount).clamp(0.0, 1.0).toDouble();
  }

  double? get installmentAmount {
    if (installmentsCount <= 0) return null;
    return totalAmount / installmentsCount;
  }

  factory WalletInstallment.fromJson(Map<String, dynamic> json) {
    return WalletInstallment(
      id: json['id'] as String,
      description: json['description'] as String,
      merchant: json['merchant'] as String?,
      totalAmount: _number(json['total_amount']),
      installmentsCount: (json['installments_count'] as num).toInt(),
      cardId: json['card_id'] as String,
      cardName: json['card_name'] as String,
      remainingInstallments:
          (json['remaining_installments'] as num?)?.toInt() ?? 0,
      remainingAmount: _number(json['remaining_amount']),
      nextDueDate: _nullableDate(json['next_due_date']),
    );
  }
}

double _number(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

double? _nullableNumber(dynamic value) {
  if (value == null) return null;
  return _number(value);
}

DateTime? _nullableDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
