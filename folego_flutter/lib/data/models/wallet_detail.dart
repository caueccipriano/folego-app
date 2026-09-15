import '../../core/utils/financial_display_text.dart';

class WalletMovement {
  const WalletMovement({required this.id, required this.eventType, required this.description, required this.amount, required this.occurredAt, this.categoryName});
  final String id;
  final String eventType;
  final String description;
  final double amount;
  final DateTime occurredAt;
  final String? categoryName;

  factory WalletMovement.fromEventJson(Map<String, dynamic> json) {
    final category = _map(json['category'] ?? json['categories']);
    final impacts = _maps(json['financial_impacts']);
    final impact = impacts.isEmpty ? null : impacts.first;
    return WalletMovement(
      id: json['id'] as String,
      eventType: json['event_type'] as String,
      description: financialDisplayDescription(json['description'] as String),
      amount: _number(impact?['amount'] ?? json['amount']),
      occurredAt: DateTime.parse(json['occurred_at'] as String),
      categoryName: category?['name'] as String?,
    );
  }
}

class WalletCardPurchaseLine {
  const WalletCardPurchaseLine({required this.id, required this.purchaseId, required this.description, required this.purchaseAt, required this.amount, required this.installmentNumber, required this.totalInstallments, this.merchant, this.categoryName});
  final String id;
  final String purchaseId;
  final String description;
  final String? merchant;
  final String? categoryName;
  final DateTime purchaseAt;
  final double amount;
  final int installmentNumber;
  final int totalInstallments;
  String get displayName {
    final value = merchant?.trim();
    return value == null || value.isEmpty ? financialDisplayDescription(description) : value;
  }
  factory WalletCardPurchaseLine.fromInstallmentJson(Map<String, dynamic> json) {
    final purchase = _map(json['purchase']) ?? const <String, dynamic>{};
    final category = _map(purchase['category'] ?? purchase['categories']);
    return WalletCardPurchaseLine(
      id: json['id'] as String,
      purchaseId: purchase['id'] as String,
      description: purchase['description'] as String,
      merchant: purchase['merchant'] as String?,
      categoryName: category?['name'] as String?,
      purchaseAt: DateTime.parse(purchase['purchase_at'] as String),
      amount: _number(json['amount']),
      installmentNumber: (json['installment_number'] as num).toInt(),
      totalInstallments: (json['total_installments'] as num).toInt(),
    );
  }
}

class WalletCardInstallmentLine {
  const WalletCardInstallmentLine({required this.id, required this.purchaseId, required this.description, required this.amount, required this.installmentNumber, required this.totalInstallments, required this.competenceDate, required this.status, this.merchant, this.categoryName, this.invoiceDueDate, this.invoiceStatus});
  final String id;
  final String purchaseId;
  final String description;
  final String? merchant;
  final String? categoryName;
  final double amount;
  final int installmentNumber;
  final int totalInstallments;
  final DateTime competenceDate;
  final String status;
  final DateTime? invoiceDueDate;
  final String? invoiceStatus;
  String get displayName {
    final value = merchant?.trim();
    return value == null || value.isEmpty ? financialDisplayDescription(description) : value;
  }
  bool get isOutstanding {
    const closedInstallment = {'paid', 'cancelled', 'refunded'};
    const closedInvoice = {'paid', 'cancelled'};
    return !closedInstallment.contains(status) && !closedInvoice.contains(invoiceStatus);
  }
  factory WalletCardInstallmentLine.fromJson(Map<String, dynamic> json) {
    final purchase = _map(json['purchase']) ?? const <String, dynamic>{};
    final category = _map(purchase['category'] ?? purchase['categories']);
    final invoice = _map(json['invoice']);
    return WalletCardInstallmentLine(
      id: json['id'] as String,
      purchaseId: purchase['id'] as String,
      description: purchase['description'] as String,
      merchant: purchase['merchant'] as String?,
      categoryName: category?['name'] as String?,
      amount: _number(json['amount']),
      installmentNumber: (json['installment_number'] as num).toInt(),
      totalInstallments: (json['total_installments'] as num).toInt(),
      competenceDate: DateTime.parse(json['competence_date'] as String),
      status: json['status'] as String,
      invoiceDueDate: _date(invoice?['due_date']),
      invoiceStatus: invoice?['status'] as String?,
    );
  }
}

class WalletDebtInstallment {
  const WalletDebtInstallment({required this.id, required this.installmentNumber, required this.dueDate, required this.plannedAmount, required this.paidAmount, required this.status});
  final String id;
  final int installmentNumber;
  final DateTime dueDate;
  final double plannedAmount;
  final double paidAmount;
  final String status;
  double get remainingAmount { final remaining = plannedAmount - paidAmount; return remaining < 0 ? 0 : remaining; }
  bool get isOverdue => status == 'overdue';
  factory WalletDebtInstallment.fromJson(Map<String, dynamic> json) => WalletDebtInstallment(
    id: json['id'] as String,
    installmentNumber: (json['installment_number'] as num).toInt(),
    dueDate: DateTime.parse(json['due_date'] as String),
    plannedAmount: _number(json['planned_amount']),
    paidAmount: _number(json['paid_amount']),
    status: json['status'] as String,
  );
}

class WalletInstallmentPosition {
  const WalletInstallmentPosition({required this.purchaseId, required this.description, required this.cardId, required this.cardName, required this.installmentAmount, required this.currentInstallment, required this.totalInstallments, required this.completed, this.merchant, this.categoryName, this.nextDueDate});
  final String purchaseId;
  final String description;
  final String? merchant;
  final String? categoryName;
  final String cardId;
  final String cardName;
  final double installmentAmount;
  final int currentInstallment;
  final int totalInstallments;
  final DateTime? nextDueDate;
  final bool completed;
  String get displayName {
    final value = merchant?.trim();
    return value == null || value.isEmpty ? financialDisplayDescription(description) : value;
  }
  double get progress {
    if (totalInstallments <= 0) return 0;
    final rawCompleted = currentInstallment - 1;
    final completedCount = completed ? totalInstallments : rawCompleted < 0 ? 0 : rawCompleted > totalInstallments ? totalInstallments : rawCompleted;
    return (completedCount / totalInstallments).clamp(0.0, 1.0).toDouble();
  }
  factory WalletInstallmentPosition.fromPurchaseJson(Map<String, dynamic> json) {
    final card = _map(json['card']) ?? const <String, dynamic>{};
    final category = _map(json['category'] ?? json['categories']);
    final installments = _maps(json['card_installments'])..sort((a,b)=>(a['installment_number'] as num).toInt().compareTo((b['installment_number'] as num).toInt()));
    bool isOutstanding(Map<String,dynamic> item) {
      final status = item['status'] as String?;
      final invoice = _map(item['invoice']);
      final invoiceStatus = invoice?['status'] as String?;
      const closedInstallment = {'paid','cancelled','refunded'};
      const closedInvoice = {'paid','cancelled'};
      return !closedInstallment.contains(status) && !closedInvoice.contains(invoiceStatus);
    }
    final valid = installments.where((item) { final status=item['status'] as String?; return status!='cancelled'&&status!='refunded'; }).toList(growable:false);
    final outstanding = valid.where(isOutstanding).toList(growable:false);
    final completed = outstanding.isEmpty && valid.isNotEmpty;
    final selected = outstanding.isNotEmpty ? outstanding.first : valid.isNotEmpty ? valid.last : null;
    final total = (json['installments_count'] as num).toInt();
    final current = selected == null ? total : (selected['installment_number'] as num).toInt();
    final invoice = selected == null ? null : _map(selected['invoice']);
    return WalletInstallmentPosition(
      purchaseId: json['id'] as String,
      description: json['description'] as String,
      merchant: json['merchant'] as String?,
      categoryName: category?['name'] as String?,
      cardId: card['id'] as String,
      cardName: card['name'] as String,
      installmentAmount: selected == null ? 0 : _number(selected['amount']),
      currentInstallment: current,
      totalInstallments: total,
      nextDueDate: completed ? null : _date(invoice?['due_date']),
      completed: completed,
    );
  }
}

List<WalletInstallmentPosition> sortWalletInstallmentPositions(Iterable<WalletInstallmentPosition> items) {
  final sorted = items.toList(growable:false);
  sorted.sort((a,b){
    if (a.completed != b.completed) return a.completed ? 1 : -1;
    final aDate=a.nextDueDate; final bDate=b.nextDueDate;
    if (!a.completed) {
      if (aDate==null&&bDate!=null) return 1;
      if (aDate!=null&&bDate==null) return -1;
      if (aDate!=null&&bDate!=null) { final c=aDate.compareTo(bDate); if(c!=0)return c; }
    } else {
      if (aDate==null&&bDate!=null) return 1;
      if (aDate!=null&&bDate==null) return -1;
      if (aDate!=null&&bDate!=null) { final c=bDate.compareTo(aDate); if(c!=0)return c; }
    }
    return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
  });
  return sorted;
}

List<Map<String,dynamic>> _maps(dynamic value) {
  if (value is! List) return <Map<String,dynamic>>[];
  return value.whereType<Map>().map((item)=>Map<String,dynamic>.from(item)).toList();
}
Map<String,dynamic>? _map(dynamic value) => value is Map ? Map<String,dynamic>.from(value) : null;
double _number(dynamic value) { if(value==null)return 0; if(value is num)return value.toDouble(); return double.tryParse(value.toString())??0; }
DateTime? _date(dynamic value) => value==null ? null : DateTime.tryParse(value.toString());
