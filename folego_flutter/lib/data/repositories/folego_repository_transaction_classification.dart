import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/transaction_item.dart';
import 'folego_repository.dart';

extension FolegoRepositoryTransactionClassification on FolegoRepository {
  Future<List<TransactionItem>> listPendingTransactionClassifications(
    String spaceId, {
    int limit = 500,
  }) async {
    // Resolve the system inbox category instead of hardcoding a space ID.
    // A category may be "A classificar" even when its import flag is missing.
    final unclassified = await Supabase.instance.client
        .from('categories')
        .select('id')
        .eq('space_id', spaceId)
        .eq('name', 'A classificar')
        .limit(1);
    final unclassifiedId = unclassified.isEmpty
        ? null
        : unclassified.first['id']?.toString();
    final pendingFilter = [
      'metadata->>needs_classification.eq.true',
      'category_id.is.null',
      if (unclassifiedId != null) 'category_id.eq.$unclassifiedId',
    ].join(',');

    final response = await Supabase.instance.client
        .from('financial_events')
        .select('''
          id,
          event_type,
          description,
          amount,
          occurred_at,
          competence_date,
          category_id,
          status,
          source,
          metadata,
          category:categories(
            id,
            name,
            color_hex,
            parent_id
          ),
          financial_impacts(
            dimension,
            account_id,
            account:accounts(
              id,
              name
            )
          )
        ''')
        .eq('space_id', spaceId)
        .eq('status', 'confirmed')
        .inFilter('event_type', const <String>[
          'income',
          'benefit_credit',
          'reimbursement',
          'expense',
          'card_purchase',
          'benefit_expense',
          'refund',
          'debt_payment',
        ])
        // Filter *before* pagination. Filtering a page of the 500 newest
        // general transactions can hide older pending classifications.
        .or(pendingFilter)
        .order('occurred_at', ascending: false)
        .limit(limit);

    final rows = List<Map<String, dynamic>>.from(response);
    return rows
        .where(
          (row) => isVisiblePendingClassificationRow(
            row,
            unclassifiedId: unclassifiedId,
          ),
        )
        .map(TransactionItem.fromJson)
        .toList(growable: false);
  }

  Future<void> classifyFinancialEvent({
    required String spaceId,
    required String eventId,
    required String categoryId,
  }) async {
    final result = await Supabase.instance.client.rpc(
      'classify_financial_event',
      params: {
        'p_space_id': spaceId,
        'p_event_id': eventId,
        'p_category_id': categoryId,
      },
    );

    if (result != true) {
      throw StateError('classification_failed');
    }
  }
}

String? transactionClassificationKind(String eventType) {
  if (const <String>{
    'income',
    'benefit_credit',
    'reimbursement',
  }.contains(eventType)) {
    return 'income';
  }

  if (const <String>{
    'expense',
    'card_purchase',
    'benefit_expense',
    'refund',
    'debt_payment',
  }.contains(eventType)) {
    return 'expense';
  }

  return null;
}


/// Include real economic entries that have no selected category, even when
/// a bank import failed to set the legacy review flag. Never classify silently.
bool isVisiblePendingClassificationRow(
  Map<String, dynamic> row, {
  String? unclassifiedId,
}) {
  if (row['status'] != 'confirmed' ||
      transactionClassificationKind(row['event_type']?.toString() ?? '') ==
          null) {
    return false;
  }
  final metadata = row['metadata'];
  if (metadata is Map &&
      (metadata['hidden'] == true ||
          metadata['hidden']?.toString().toLowerCase() == 'true')) {
    return false;
  }
  if (isVisiblePendingClassificationMetadata(metadata)) return true;
  final categoryId = row['category_id']?.toString();
  return categoryId == null ||
      categoryId.isEmpty ||
      (unclassifiedId != null && categoryId == unclassifiedId);
}

/// Defense-in-depth after the database's JSON filter. Hidden or malformed
/// entries are never displayed for classification.
bool isVisiblePendingClassificationMetadata(dynamic metadata) {
  if (metadata is! Map) return false;
  final value = metadata['needs_classification'];
  final pending =
      value == true || value?.toString().toLowerCase() == 'true';
  final hidden = metadata['hidden'] == true ||
      metadata['hidden']?.toString().toLowerCase() == 'true';
  return pending && !hidden;
}
