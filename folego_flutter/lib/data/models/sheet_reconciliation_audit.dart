/// Read-only audit of Fôlego records linked to a Google Sheet.
///
/// This is NOT a bidirectional per-row reconciliation: the backend does not
/// receive a sheet-side acknowledgement after a pulled row is applied.
final class SheetAuditItem {
  const SheetAuditItem({
    required this.id,
    required this.description,
    required this.amount,
    required this.occurredAt,
    required this.eventType,
    required this.categoryId,
    required this.needsClassification,
    required this.hidden,
    required this.sheetLinked,
  });

  final String id;
  final String description;
  final double amount;
  final DateTime occurredAt;
  final String eventType;
  final String? categoryId;
  final bool needsClassification;
  final bool hidden;
  final bool sheetLinked;

  static bool _flag(dynamic value) =>
      value == true || value?.toString().toLowerCase() == 'true';

  factory SheetAuditItem.fromJson(Map<String, dynamic> data) {
    final metadata = data['metadata'];
    final meta = metadata is Map
        ? Map<String, dynamic>.from(metadata)
        : const <String, dynamic>{};
    return SheetAuditItem(
      id: data['id'] as String,
      description: (data['description'] as String?) ?? 'Sem descrição',
      amount: (data['amount'] as num).toDouble(),
      occurredAt: DateTime.parse(data['occurred_at'] as String),
      eventType: (data['event_type'] as String?) ?? '',
      categoryId: data['category_id'] as String?,
      needsClassification: _flag(meta['needs_classification']),
      hidden: _flag(meta['hidden']),
      sheetLinked: _flag(meta['sheet_linked']),
    );
  }

  bool get needsReview => needsClassification && !hidden;

  /// Only the flagged economic classification is actionable from this audit.
  /// A nonflagged row is not necessarily matched in the spreadsheet.
  String get reviewLabel {
    if (needsReview && (categoryId == null || categoryId!.isEmpty)) {
      return 'Categoria pendente';
    }
    if (needsReview) return 'Conferir categoria';
    return 'Sem confirmação de retorno da planilha';
  }
}

/// Recent records are a sample; pending records get their own server-side
/// query so they are not lost behind newer, already classified transactions.
List<SheetAuditItem> mergeSheetAuditSamples({
  required Iterable<SheetAuditItem> recent,
  required Iterable<SheetAuditItem> pending,
}) {
  final byId = <String, SheetAuditItem>{};
  for (final row in recent.followedBy(pending)) {
    if (!row.hidden && row.sheetLinked) byId[row.id] = row;
  }
  final items = byId.values.toList(growable: false);
  items.sort((a, b) {
    if (a.needsReview != b.needsReview) return a.needsReview ? -1 : 1;
    return b.occurredAt.compareTo(a.occurredAt);
  });
  return items;
}
