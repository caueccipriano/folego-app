class DebtDetail {
  const DebtDetail({
    required this.debt,
    required this.installments,
    required this.payments,
    required this.today,
  });

  final DebtRecord debt;
  final List<DebtInstallmentRecord> installments;
  final List<DebtPaymentRecord> payments;
  final DateTime today;

  double get paidAmount {
    final paid = debt.originalAmount - debt.remainingBalance;
    return paid.clamp(0, debt.originalAmount).toDouble();
  }

  double get progress {
    if (debt.originalAmount <= 0) return 0;
    return (paidAmount / debt.originalAmount).clamp(0.0, 1.0).toDouble();
  }

  bool get hasPayments => payments.isNotEmpty ||
      installments.any((item) => item.paidAmount > 0);

  bool get canRestructure => !hasPayments;

  factory DebtDetail.fromJson(Map<String, dynamic> json) {
    final debtJson = Map<String, dynamic>.from(json['debt'] as Map);
    final installments = ((json['installments'] as List?) ?? const [])
        .map((item) => DebtInstallmentRecord.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList(growable: false);
    final payments = ((json['payments'] as List?) ?? const [])
        .map((item) => DebtPaymentRecord.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList(growable: false);
    return DebtDetail(
      debt: DebtRecord.fromJson(debtJson),
      installments: installments,
      payments: payments,
      today: DateTime.parse(json['today'] as String),
    );
  }
}

class DebtRecord {
  const DebtRecord({
    required this.id,
    required this.name,
    required this.creditor,
    required this.debtType,
    required this.originalAmount,
    required this.openingBalance,
    required this.remainingBalance,
    required this.totalInstallments,
    required this.status,
    this.notes,
    this.interestRateMonthly,
    this.paymentAccountId,
    this.startedOn,
    this.firstDueDate,
    this.archivedAt,
    this.closedAt,
  });

  final String id;
  final String name;
  final String creditor;
  final String debtType;
  final String? notes;
  final double originalAmount;
  final double openingBalance;
  final double remainingBalance;
  final double? interestRateMonthly;
  final int totalInstallments;
  final String? paymentAccountId;
  final String status;
  final DateTime? startedOn;
  final DateTime? firstDueDate;
  final DateTime? archivedAt;
  final DateTime? closedAt;

  bool get isArchived => archivedAt != null;
  bool get isPaid => status == 'paid' || remainingBalance <= 0;
  bool get isActive => status == 'active' && !isArchived;

  factory DebtRecord.fromJson(Map<String, dynamic> json) {
    final original = _number(json['original_amount'] ?? json['opening_balance']);
    return DebtRecord(
      id: json['id'] as String,
      name: json['name'] as String,
      creditor: json['creditor'] as String? ?? json['name'] as String,
      debtType: json['debt_type'] as String? ?? 'other',
      notes: json['notes'] as String?,
      originalAmount: original,
      openingBalance: _number(json['opening_balance']),
      remainingBalance: _number(json['remaining_balance']),
      interestRateMonthly: _nullableNumber(json['interest_rate_monthly']),
      totalInstallments: (json['total_installments'] as num?)?.toInt() ?? 0,
      paymentAccountId: json['payment_account_id'] as String?,
      status: json['status'] as String? ?? 'active',
      startedOn: _date(json['started_on']),
      firstDueDate: _date(json['first_due_date']),
      archivedAt: _date(json['archived_at']),
      closedAt: _date(json['closed_at']),
    );
  }
}

class DebtInstallmentRecord {
  const DebtInstallmentRecord({
    required this.id,
    required this.installmentNumber,
    required this.dueDate,
    required this.plannedAmount,
    required this.paidAmount,
    required this.remainingAmount,
    required this.status,
    required this.isOverdue,
  });

  final String id;
  final int installmentNumber;
  final DateTime dueDate;
  final double plannedAmount;
  final double paidAmount;
  final double remainingAmount;
  final String status;
  final bool isOverdue;

  bool get isPaid => status == 'paid' || remainingAmount <= 0;
  bool get canPay => !isPaid && status != 'cancelled' && remainingAmount > 0;

  factory DebtInstallmentRecord.fromJson(Map<String, dynamic> json) {
    return DebtInstallmentRecord(
      id: json['id'] as String,
      installmentNumber: (json['installment_number'] as num).toInt(),
      dueDate: DateTime.parse(json['due_date'] as String),
      plannedAmount: _number(json['planned_amount']),
      paidAmount: _number(json['paid_amount']),
      remainingAmount: _number(json['remaining_amount']),
      status: json['status'] as String,
      isOverdue: json['is_overdue'] as bool? ?? false,
    );
  }
}

class DebtPaymentRecord {
  const DebtPaymentRecord({
    required this.id,
    required this.eventId,
    required this.installmentId,
    required this.installmentNumber,
    required this.amount,
    required this.paidAt,
    required this.accountId,
    required this.accountName,
    required this.status,
  });

  final String id;
  final String eventId;
  final String installmentId;
  final int installmentNumber;
  final double amount;
  final DateTime paidAt;
  final String accountId;
  final String accountName;
  final String status;

  factory DebtPaymentRecord.fromJson(Map<String, dynamic> json) {
    return DebtPaymentRecord(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      installmentId: json['installment_id'] as String,
      installmentNumber: (json['installment_number'] as num).toInt(),
      amount: _number(json['amount']),
      paidAt: DateTime.parse(json['paid_at'] as String),
      accountId: json['account_id'] as String,
      accountName: json['account_name'] as String,
      status: json['status'] as String? ?? 'confirmed',
    );
  }
}

class DebtDraft {
  const DebtDraft({
    required this.name,
    required this.creditor,
    required this.originalAmount,
    required this.totalInstallments,
    required this.firstDueDate,
    required this.debtType,
    this.paymentAccountId,
    this.startedOn,
    this.interestRateMonthly,
    this.notes,
  });

  final String name;
  final String creditor;
  final double originalAmount;
  final int totalInstallments;
  final DateTime firstDueDate;
  final String debtType;
  final String? paymentAccountId;
  final DateTime? startedOn;
  final double? interestRateMonthly;
  final String? notes;

  String? validate() {
    if (name.trim().isEmpty) return 'informe um nome para a dívida';
    if (creditor.trim().isEmpty) return 'informe o credor';
    if (originalAmount <= 0) return 'o valor precisa ser maior que zero';
    if (totalInstallments < 1 || totalInstallments > 360) {
      return 'use entre 1 e 360 parcelas';
    }
    if (!debtTypes.contains(debtType)) return 'tipo de dívida inválido';
    if (interestRateMonthly != null && interestRateMonthly! < 0) {
      return 'a taxa não pode ser negativa';
    }
    return null;
  }

  List<double> installmentSchedule() {
    final totalCents = (originalAmount * 100).round();
    final baseCents = totalCents ~/ totalInstallments;
    final result = <double>[];
    for (var index = 0; index < totalInstallments; index += 1) {
      final cents = index == totalInstallments - 1
          ? totalCents - (baseCents * (totalInstallments - 1))
          : baseCents;
      result.add(cents / 100);
    }
    return result;
  }

  bool get hasLastInstallmentAdjustment {
    final values = installmentSchedule();
    return values.length > 1 && values.first != values.last;
  }
}

const debtTypes = <String>{
  'loan',
  'financing',
  'installment',
  'personal',
  'other',
};

String debtTypeLabel(String type) => switch (type) {
  'loan' => 'empréstimo',
  'financing' => 'financiamento',
  'installment' => 'parcelamento',
  'personal' => 'pessoal',
  _ => 'outro',
};

double _number(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

double? _nullableNumber(dynamic value) {
  if (value == null) return null;
  return _number(value);
}

DateTime? _date(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
