enum StatementImportFileType { csv, ofx }

enum StatementImportSourceKind { account, card, benefit }

enum StatementImportDirection { debit, credit }

enum StatementImportCandidateType {
  expense,
  income,
  cardPurchase,
  benefitExpense,
  benefitCredit,
  transferCandidate,
  cardPaymentCandidate,
  refundCandidate,
  unknown,
}

enum StatementImportFinalType {
  expense,
  income,
  cardPurchase,
  benefitExpense,
  benefitCredit,
  transfer,
  cardPayment,
}

enum StatementImportDuplicateState {
  unique,
  exactDuplicate,
  possibleDuplicate,
  alreadyImported,
}

enum StatementImportDecision { include, ignore, review }

enum StatementImportRowStatus { staged, imported, ignored, error }

extension StatementImportEnumKeys on Enum {
  String get dbKey => switch (this) {
        StatementImportFileType.csv => 'csv',
        StatementImportFileType.ofx => 'ofx',
        StatementImportSourceKind.account => 'account',
        StatementImportSourceKind.card => 'card',
        StatementImportSourceKind.benefit => 'benefit',
        StatementImportDirection.debit => 'debit',
        StatementImportDirection.credit => 'credit',
        StatementImportCandidateType.expense => 'expense',
        StatementImportCandidateType.income => 'income',
        StatementImportCandidateType.cardPurchase => 'card_purchase',
        StatementImportCandidateType.benefitExpense => 'benefit_expense',
        StatementImportCandidateType.benefitCredit => 'benefit_credit',
        StatementImportCandidateType.transferCandidate => 'transfer_candidate',
        StatementImportCandidateType.cardPaymentCandidate => 'card_payment_candidate',
        StatementImportCandidateType.refundCandidate => 'refund_candidate',
        StatementImportCandidateType.unknown => 'unknown',
        StatementImportFinalType.expense => 'expense',
        StatementImportFinalType.income => 'income',
        StatementImportFinalType.cardPurchase => 'card_purchase',
        StatementImportFinalType.benefitExpense => 'benefit_expense',
        StatementImportFinalType.benefitCredit => 'benefit_credit',
        StatementImportFinalType.transfer => 'transfer',
        StatementImportFinalType.cardPayment => 'card_payment',
        StatementImportDuplicateState.unique => 'unique',
        StatementImportDuplicateState.exactDuplicate => 'exact_duplicate',
        StatementImportDuplicateState.possibleDuplicate => 'possible_duplicate',
        StatementImportDuplicateState.alreadyImported => 'already_imported',
        StatementImportDecision.include => 'include',
        StatementImportDecision.ignore => 'ignore',
        StatementImportDecision.review => 'review',
        StatementImportRowStatus.staged => 'staged',
        StatementImportRowStatus.imported => 'imported',
        StatementImportRowStatus.ignored => 'ignored',
        StatementImportRowStatus.error => 'error',
        _ => name,
      };
}

class StatementImportCandidate {
  const StatementImportCandidate({
    required this.rowNumber,
    required this.occurredAt,
    required this.dateOnly,
    required this.amountMinor,
    required this.description,
    required this.direction,
    required this.candidateType,
    this.localDate,
    this.merchant,
    this.externalId,
    this.finalType,
    this.categoryId,
    this.confidence,
    this.reason,
    this.originalFields = const <String, dynamic>{},
  });

  final int rowNumber;
  final DateTime occurredAt;
  final bool dateOnly;
  final String? localDate;
  final int amountMinor;
  final String description;
  final String? merchant;
  final StatementImportDirection direction;
  final String? externalId;
  final StatementImportCandidateType candidateType;
  final StatementImportFinalType? finalType;
  final String? categoryId;
  final double? confidence;
  final String? reason;
  final Map<String, dynamic> originalFields;

  String get amountDecimal {
    final whole = amountMinor ~/ 100;
    final cents = (amountMinor % 100).abs().toString().padLeft(2, '0');
    return '$whole.$cents';
  }

  Map<String, dynamic> toStageJson() => <String, dynamic>{
        'row_number': rowNumber,
        'occurred_at': occurredAt.toIso8601String(),
        'date_only': dateOnly,
        'local_date': localDate,
        'amount': amountDecimal,
        'description': description,
        'merchant': merchant,
        'direction': direction.dbKey,
        'external_id': externalId,
        'candidate_type': candidateType.dbKey,
        'final_type': finalType?.dbKey,
        'category_id': categoryId,
        'confidence': confidence,
        'reason': reason,
        'original_fields': originalFields,
      };
}

class StatementImportBatch {
  const StatementImportBatch({
    required this.id,
    required this.spaceId,
    required this.filename,
    required this.fileType,
    required this.sourceKind,
    required this.status,
    required this.totalRows,
    required this.importedRows,
    required this.ignoredRows,
    required this.duplicateRows,
    required this.errorRows,
    this.sourceAccountId,
    this.sourceCardId,
    this.sourceInstitution,
  });

  final String id;
  final String spaceId;
  final String filename;
  final StatementImportFileType fileType;
  final StatementImportSourceKind sourceKind;
  final String? sourceAccountId;
  final String? sourceCardId;
  final String? sourceInstitution;
  final String status;
  final int totalRows;
  final int importedRows;
  final int ignoredRows;
  final int duplicateRows;
  final int errorRows;

  factory StatementImportBatch.fromJson(Map<String, dynamic> json) {
    return StatementImportBatch(
      id: json['id'] as String,
      spaceId: json['space_id'] as String,
      filename: json['filename'] as String,
      fileType: _fileType(json['file_type'] as String?),
      sourceKind: _sourceKind(json['source_kind'] as String?),
      sourceAccountId: json['source_account_id'] as String?,
      sourceCardId: json['source_card_id'] as String?,
      sourceInstitution: json['source_institution'] as String?,
      status: json['status'] as String? ?? 'reviewing',
      totalRows: (json['total_rows'] as num?)?.toInt() ?? 0,
      importedRows: (json['imported_rows'] as num?)?.toInt() ?? 0,
      ignoredRows: (json['ignored_rows'] as num?)?.toInt() ?? 0,
      duplicateRows: (json['duplicate_rows'] as num?)?.toInt() ?? 0,
      errorRows: (json['error_rows'] as num?)?.toInt() ?? 0,
    );
  }
}

class StatementImportRow {
  const StatementImportRow({
    required this.id,
    required this.batchId,
    required this.rowNumber,
    required this.occurredAt,
    required this.description,
    required this.amount,
    required this.direction,
    required this.candidateType,
    required this.duplicateState,
    required this.decision,
    required this.status,
    this.merchant,
    this.externalId,
    this.finalType,
    this.categoryId,
    this.counterpartAccountId,
    this.invoiceId,
    this.reason,
    this.errorText,
    this.importedEventId,
  });

  final String id;
  final String batchId;
  final int rowNumber;
  final DateTime occurredAt;
  final String description;
  final String? merchant;
  final num amount;
  final StatementImportDirection direction;
  final String? externalId;
  final StatementImportCandidateType candidateType;
  final StatementImportFinalType? finalType;
  final String? categoryId;
  final String? counterpartAccountId;
  final String? invoiceId;
  final StatementImportDuplicateState duplicateState;
  final StatementImportDecision decision;
  final StatementImportRowStatus status;
  final String? reason;
  final String? errorText;
  final String? importedEventId;

  bool get selected => decision == StatementImportDecision.include;
  bool get needsReview =>
      decision == StatementImportDecision.review || finalType == null || status == StatementImportRowStatus.error;

  StatementImportRow copyWith({
    StatementImportFinalType? finalType,
    bool clearFinalType = false,
    String? categoryId,
    bool clearCategory = false,
    String? counterpartAccountId,
    bool clearCounterpart = false,
    String? invoiceId,
    bool clearInvoice = false,
    StatementImportDecision? decision,
  }) {
    return StatementImportRow(
      id: id,
      batchId: batchId,
      rowNumber: rowNumber,
      occurredAt: occurredAt,
      description: description,
      amount: amount,
      direction: direction,
      candidateType: candidateType,
      duplicateState: duplicateState,
      status: status,
      merchant: merchant,
      externalId: externalId,
      finalType: clearFinalType ? null : finalType ?? this.finalType,
      categoryId: clearCategory ? null : categoryId ?? this.categoryId,
      counterpartAccountId: clearCounterpart ? null : counterpartAccountId ?? this.counterpartAccountId,
      invoiceId: clearInvoice ? null : invoiceId ?? this.invoiceId,
      decision: decision ?? this.decision,
      reason: reason,
      errorText: errorText,
      importedEventId: importedEventId,
    );
  }

  Map<String, dynamic> toReviewPatch() => <String, dynamic>{
        'id': id,
        'final_type': finalType?.dbKey,
        'category_id': categoryId,
        'counterpart_account_id': counterpartAccountId,
        'invoice_id': invoiceId,
        'user_decision': decision.dbKey,
      };

  factory StatementImportRow.fromJson(Map<String, dynamic> json) {
    return StatementImportRow(
      id: json['id'] as String,
      batchId: json['batch_id'] as String,
      rowNumber: (json['row_number'] as num).toInt(),
      occurredAt: DateTime.parse(json['occurred_at'] as String),
      description: json['description'] as String,
      merchant: json['merchant'] as String?,
      amount: json['amount'] as num,
      direction: _direction(json['direction'] as String?),
      externalId: json['external_id'] as String?,
      candidateType: _candidateType(json['candidate_type'] as String?),
      finalType: _finalType(json['final_type'] as String?),
      categoryId: json['category_id'] as String?,
      counterpartAccountId: json['counterpart_account_id'] as String?,
      invoiceId: json['invoice_id'] as String?,
      duplicateState: _duplicateState(json['duplicate_state'] as String?),
      decision: _decision(json['user_decision'] as String?),
      status: _rowStatus(json['status'] as String?),
      reason: json['reason'] as String?,
      errorText: json['error_text'] as String?,
      importedEventId: json['imported_event_id'] as String?,
    );
  }
}

class StatementImportResult {
  const StatementImportResult({
    required this.batchId,
    required this.status,
    required this.imported,
    required this.ignored,
    required this.duplicates,
    required this.errors,
    required this.pending,
  });

  final String batchId;
  final String status;
  final int imported;
  final int ignored;
  final int duplicates;
  final int errors;
  final int pending;

  bool get completed => status == 'completed';

  factory StatementImportResult.fromJson(Map<String, dynamic> json) {
    int value(String key) => (json[key] as num?)?.toInt() ?? 0;
    return StatementImportResult(
      batchId: json['batch_id'] as String,
      status: json['status'] as String? ?? 'partially_completed',
      imported: value('imported'),
      ignored: value('ignored'),
      duplicates: value('duplicates'),
      errors: value('errors'),
      pending: value('pending'),
    );
  }
}

class StatementImportInvoiceOption {
  const StatementImportInvoiceOption({
    required this.id,
    required this.cardId,
    required this.cardName,
    required this.dueDate,
    required this.status,
  });

  final String id;
  final String cardId;
  final String cardName;
  final DateTime? dueDate;
  final String status;

  factory StatementImportInvoiceOption.fromJson(Map<String, dynamic> json) {
    final card = json['card'] as Map<String, dynamic>?;
    return StatementImportInvoiceOption(
      id: json['id'] as String,
      cardId: json['card_id'] as String,
      cardName: card?['name'] as String? ?? 'cartão',
      dueDate: json['due_date'] == null ? null : DateTime.parse(json['due_date'] as String),
      status: json['status'] as String? ?? 'open',
    );
  }
}

StatementImportFileType _fileType(String? value) =>
    value == 'ofx' ? StatementImportFileType.ofx : StatementImportFileType.csv;
StatementImportSourceKind _sourceKind(String? value) => switch (value) {
      'card' => StatementImportSourceKind.card,
      'benefit' => StatementImportSourceKind.benefit,
      _ => StatementImportSourceKind.account,
    };
StatementImportDirection _direction(String? value) =>
    value == 'credit' ? StatementImportDirection.credit : StatementImportDirection.debit;
StatementImportCandidateType _candidateType(String? value) => switch (value) {
      'expense' => StatementImportCandidateType.expense,
      'income' => StatementImportCandidateType.income,
      'card_purchase' => StatementImportCandidateType.cardPurchase,
      'benefit_expense' => StatementImportCandidateType.benefitExpense,
      'benefit_credit' => StatementImportCandidateType.benefitCredit,
      'transfer_candidate' => StatementImportCandidateType.transferCandidate,
      'card_payment_candidate' => StatementImportCandidateType.cardPaymentCandidate,
      'refund_candidate' => StatementImportCandidateType.refundCandidate,
      _ => StatementImportCandidateType.unknown,
    };
StatementImportFinalType? _finalType(String? value) => switch (value) {
      'expense' => StatementImportFinalType.expense,
      'income' => StatementImportFinalType.income,
      'card_purchase' => StatementImportFinalType.cardPurchase,
      'benefit_expense' => StatementImportFinalType.benefitExpense,
      'benefit_credit' => StatementImportFinalType.benefitCredit,
      'transfer' => StatementImportFinalType.transfer,
      'card_payment' => StatementImportFinalType.cardPayment,
      _ => null,
    };
StatementImportDuplicateState _duplicateState(String? value) => switch (value) {
      'exact_duplicate' => StatementImportDuplicateState.exactDuplicate,
      'possible_duplicate' => StatementImportDuplicateState.possibleDuplicate,
      'already_imported' => StatementImportDuplicateState.alreadyImported,
      _ => StatementImportDuplicateState.unique,
    };
StatementImportDecision _decision(String? value) => switch (value) {
      'include' => StatementImportDecision.include,
      'ignore' => StatementImportDecision.ignore,
      _ => StatementImportDecision.review,
    };
StatementImportRowStatus _rowStatus(String? value) => switch (value) {
      'imported' => StatementImportRowStatus.imported,
      'ignored' => StatementImportRowStatus.ignored,
      'error' => StatementImportRowStatus.error,
      _ => StatementImportRowStatus.staged,
    };
