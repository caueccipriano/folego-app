class ImportCsvMapping {
  const ImportCsvMapping({
    required this.dateColumn,
    required this.descriptionColumn,
    this.valueColumn,
    this.debitColumn,
    this.creditColumn,
    this.merchantColumn,
    this.categoryColumn,
    this.externalIdColumn,
    this.documentColumn,
    this.balanceColumn,
    this.typeColumn,
    this.noteColumn,
    this.dateFormat = 'auto',
    this.decimalFormat = 'auto',
  });

  final int dateColumn;
  final int descriptionColumn;
  final int? valueColumn;
  final int? debitColumn;
  final int? creditColumn;
  final int? merchantColumn;
  final int? categoryColumn;
  final int? externalIdColumn;
  final int? documentColumn;
  final int? balanceColumn;
  final int? typeColumn;
  final int? noteColumn;
  final String dateFormat;
  final String decimalFormat;

  bool get usesSplitDebitCredit => debitColumn != null || creditColumn != null;

  bool get isValid =>
      dateColumn >= 0 &&
      descriptionColumn >= 0 &&
      (valueColumn != null || (debitColumn != null && creditColumn != null));

  ImportCsvMapping copyWith({
    int? dateColumn,
    int? descriptionColumn,
    int? valueColumn,
    bool clearValueColumn = false,
    int? debitColumn,
    bool clearDebitColumn = false,
    int? creditColumn,
    bool clearCreditColumn = false,
    int? merchantColumn,
    bool clearMerchantColumn = false,
    int? categoryColumn,
    bool clearCategoryColumn = false,
    int? externalIdColumn,
    bool clearExternalIdColumn = false,
    int? documentColumn,
    bool clearDocumentColumn = false,
    int? balanceColumn,
    bool clearBalanceColumn = false,
    int? typeColumn,
    bool clearTypeColumn = false,
    int? noteColumn,
    bool clearNoteColumn = false,
    String? dateFormat,
    String? decimalFormat,
  }) {
    return ImportCsvMapping(
      dateColumn: dateColumn ?? this.dateColumn,
      descriptionColumn: descriptionColumn ?? this.descriptionColumn,
      valueColumn: clearValueColumn ? null : valueColumn ?? this.valueColumn,
      debitColumn: clearDebitColumn ? null : debitColumn ?? this.debitColumn,
      creditColumn: clearCreditColumn ? null : creditColumn ?? this.creditColumn,
      merchantColumn: clearMerchantColumn ? null : merchantColumn ?? this.merchantColumn,
      categoryColumn: clearCategoryColumn ? null : categoryColumn ?? this.categoryColumn,
      externalIdColumn: clearExternalIdColumn ? null : externalIdColumn ?? this.externalIdColumn,
      documentColumn: clearDocumentColumn ? null : documentColumn ?? this.documentColumn,
      balanceColumn: clearBalanceColumn ? null : balanceColumn ?? this.balanceColumn,
      typeColumn: clearTypeColumn ? null : typeColumn ?? this.typeColumn,
      noteColumn: clearNoteColumn ? null : noteColumn ?? this.noteColumn,
      dateFormat: dateFormat ?? this.dateFormat,
      decimalFormat: decimalFormat ?? this.decimalFormat,
    );
  }
}

class CsvInspection {
  const CsvInspection({
    required this.delimiter,
    required this.encoding,
    required this.hasHeader,
    required this.headers,
    required this.rows,
    required this.suggestedMapping,
  });

  final String delimiter;
  final String encoding;
  final bool hasHeader;
  final List<String> headers;
  final List<List<String>> rows;
  final ImportCsvMapping? suggestedMapping;

  List<String> examplesFor(int? column, {int limit = 5}) {
    if (column == null || column < 0 || column >= headers.length) {
      return const <String>[];
    }
    final values = <String>[];
    for (final row in rows) {
      if (column >= row.length) continue;
      final value = row[column].trim();
      if (value.isEmpty) continue;
      values.add(value);
      if (values.length >= limit) break;
    }
    return values;
  }
}

class OfxStatement {
  const OfxStatement({
    required this.transactions,
    this.bankId,
    this.accountId,
    this.accountType,
    this.currency,
    this.start,
    this.end,
    this.cardStatement = false,
  });

  final List<ImportCandidate> transactions;
  final String? bankId;
  final String? accountId;
  final String? accountType;
  final String? currency;
  final DateTime? start;
  final DateTime? end;
  final bool cardStatement;
}

class ImportCandidate {
  const ImportCandidate({
    required this.rowNumber,
    required this.occurredAt,
    required this.dateOnly,
    required this.description,
    required this.amountCents,
    required this.direction,
    required this.candidateType,
    required this.finalType,
    this.localDate,
    this.merchant,
    this.externalId,
    this.categoryId,
    this.confidence,
    this.reason,
    this.originalFields = const <String, dynamic>{},
  });

  final int rowNumber;
  final DateTime occurredAt;
  final bool dateOnly;
  final String? localDate;
  final String description;
  final int amountCents;
  double get amount => amountCents / 100;
  String get amountDecimal => '${amountCents ~/ 100}.${(amountCents % 100).toString().padLeft(2, '0')}';
  final String direction;
  final String candidateType;
  final String? finalType;
  final String? merchant;
  final String? externalId;
  final String? categoryId;
  final double? confidence;
  final String? reason;
  final Map<String, dynamic> originalFields;

  Map<String, dynamic> toStagingJson() => <String, dynamic>{
        'row_number': rowNumber,
        'occurred_at': occurredAt.toUtc().toIso8601String(),
        'date_only': dateOnly,
        if (localDate != null) 'local_date': localDate,
        'description': description,
        'merchant': merchant,
        'amount': amountDecimal,
        'direction': direction,
        'candidate_type': candidateType,
        'final_type': finalType,
        'external_id': externalId,
        'category_id': categoryId,
        'confidence': confidence,
        'reason': reason,
        'original_fields': originalFields,
      };
}

class ImportBatch {
  const ImportBatch({
    required this.id,
    required this.spaceId,
    required this.filename,
    required this.fileType,
    required this.sourceKind,
    required this.status,
    required this.totalRows,
    required this.selectedRows,
    required this.importedRows,
    required this.ignoredRows,
    required this.duplicateRows,
    required this.errorRows,
    this.sourceAccountId,
    this.sourceCardId,
  });

  final String id;
  final String spaceId;
  final String filename;
  final String fileType;
  final String sourceKind;
  final String? sourceAccountId;
  final String? sourceCardId;
  final String status;
  final int totalRows;
  final int selectedRows;
  final int importedRows;
  final int ignoredRows;
  final int duplicateRows;
  final int errorRows;

  factory ImportBatch.fromJson(Map<String, dynamic> json) => ImportBatch(
        id: json['id'] as String,
        spaceId: json['space_id'] as String,
        filename: json['filename'] as String,
        fileType: json['file_type'] as String,
        sourceKind: json['source_kind'] as String,
        sourceAccountId: json['source_account_id'] as String?,
        sourceCardId: json['source_card_id'] as String?,
        status: json['status'] as String,
        totalRows: (json['total_rows'] as num?)?.toInt() ?? 0,
        selectedRows: (json['selected_rows'] as num?)?.toInt() ?? 0,
        importedRows: (json['imported_rows'] as num?)?.toInt() ?? 0,
        ignoredRows: (json['ignored_rows'] as num?)?.toInt() ?? 0,
        duplicateRows: (json['duplicate_rows'] as num?)?.toInt() ?? 0,
        errorRows: (json['error_rows'] as num?)?.toInt() ?? 0,
      );
}

class ImportRow {
  const ImportRow({
    required this.id,
    required this.rowNumber,
    required this.occurredAt,
    required this.description,
    required this.amount,
    required this.direction,
    required this.candidateType,
    required this.finalType,
    required this.duplicateState,
    required this.userDecision,
    required this.status,
    this.merchant,
    this.externalId,
    this.categoryId,
    this.counterpartAccountId,
    this.invoiceId,
    this.reason,
    this.errorText,
    this.importedEventId,
  });

  final String id;
  final int rowNumber;
  final DateTime occurredAt;
  final String description;
  final double amount;
  final String direction;
  final String candidateType;
  final String? finalType;
  final String duplicateState;
  final String userDecision;
  final String status;
  final String? merchant;
  final String? externalId;
  final String? categoryId;
  final String? counterpartAccountId;
  final String? invoiceId;
  final String? reason;
  final String? errorText;
  final String? importedEventId;

  bool get included => userDecision == 'include';
  bool get exactDuplicate =>
      duplicateState == 'exact_duplicate' || duplicateState == 'already_imported';
  bool get possibleDuplicate => duplicateState == 'possible_duplicate';
  bool get needsReview =>
      status == 'error' || userDecision == 'review' || finalType == null;

  ImportRow copyWith({
    String? finalType,
    bool clearFinalType = false,
    String? userDecision,
    String? categoryId,
    bool clearCategoryId = false,
    String? counterpartAccountId,
    bool clearCounterpartAccountId = false,
    String? invoiceId,
    bool clearInvoiceId = false,
  }) =>
      ImportRow(
        id: id,
        rowNumber: rowNumber,
        occurredAt: occurredAt,
        description: description,
        amount: amount,
        direction: direction,
        candidateType: candidateType,
        finalType: clearFinalType ? null : finalType ?? this.finalType,
        duplicateState: duplicateState,
        userDecision: userDecision ?? this.userDecision,
        status: status,
        merchant: merchant,
        externalId: externalId,
        categoryId: clearCategoryId ? null : categoryId ?? this.categoryId,
        counterpartAccountId: clearCounterpartAccountId
            ? null
            : counterpartAccountId ?? this.counterpartAccountId,
        invoiceId: clearInvoiceId ? null : invoiceId ?? this.invoiceId,
        reason: reason,
        errorText: errorText,
        importedEventId: importedEventId,
      );

  Map<String, dynamic> toReviewJson() => <String, dynamic>{
        'id': id,
        'user_decision': userDecision,
        'final_type': finalType,
        'category_id': categoryId,
        'counterpart_account_id': counterpartAccountId,
        'invoice_id': invoiceId,
      };

  factory ImportRow.fromJson(Map<String, dynamic> json) => ImportRow(
        id: json['id'] as String,
        rowNumber: (json['row_number'] as num).toInt(),
        occurredAt: DateTime.parse(json['occurred_at'] as String),
        description: json['description'] as String,
        amount: (json['amount'] as num).toDouble(),
        direction: json['direction'] as String,
        candidateType: json['candidate_type'] as String,
        finalType: json['final_type'] as String?,
        duplicateState: json['duplicate_state'] as String,
        userDecision: json['user_decision'] as String,
        status: json['status'] as String,
        merchant: json['merchant'] as String?,
        externalId: json['external_id'] as String?,
        categoryId: json['category_id'] as String?,
        counterpartAccountId: json['counterpart_account_id'] as String?,
        invoiceId: json['invoice_id'] as String?,
        reason: json['reason'] as String?,
        errorText: json['error_text'] as String?,
        importedEventId: json['imported_event_id'] as String?,
      );
}

class ImportInvoiceOption {
  const ImportInvoiceOption({
    required this.id,
    required this.cardId,
    required this.cardName,
    required this.dueDate,
    required this.status,
  });

  final String id;
  final String cardId;
  final String cardName;
  final DateTime dueDate;
  final String status;

  factory ImportInvoiceOption.fromJson(Map<String, dynamic> json) {
    final card = json['card'] as Map<String, dynamic>?;
    return ImportInvoiceOption(
      id: json['id'] as String,
      cardId: json['card_id'] as String,
      cardName: card?['name'] as String? ?? 'Cartão',
      dueDate: DateTime.parse(json['due_date'] as String),
      status: json['status'] as String,
    );
  }
}

class ImportConfirmationResult {
  const ImportConfirmationResult({
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

  factory ImportConfirmationResult.fromJson(Map<String, dynamic> json) =>
      ImportConfirmationResult(
        batchId: json['batch_id'] as String,
        status: json['status'] as String,
        imported: (json['imported'] as num?)?.toInt() ?? 0,
        ignored: (json['ignored'] as num?)?.toInt() ?? 0,
        duplicates: (json['duplicates'] as num?)?.toInt() ?? 0,
        errors: (json['errors'] as num?)?.toInt() ?? 0,
        pending: (json['pending'] as num?)?.toInt() ?? 0,
      );
}

class ImportSourceOption {
  const ImportSourceOption({
    required this.id,
    required this.name,
    required this.kind,
    this.institution,
  });

  final String id;
  final String name;
  final String kind;
  final String? institution;
}
