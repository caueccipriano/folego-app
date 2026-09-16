import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/transaction_item.dart';
import 'folego_repository.dart';

extension FolegoRepositoryTransactionClassification on FolegoRepository {
  Future<List<TransactionItem>> listPendingTransactionClassifications(
    String spaceId, {
    int limit = 500,
  }) async {
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
        .order('occurred_at', ascending: false)
        .limit(limit);

    final rows = List<Map<String, dynamic>>.from(response);
    return rows
        .where((row) {
          final metadata = row['metadata'];
          if (metadata is! Map) return false;
          final value = metadata['needs_classification'];
          final pending = value == true || value?.toString().toLowerCase() == 'true';
          final hidden = metadata['hidden'] == true ||
              metadata['hidden']?.toString().toLowerCase() == 'true';
          return pending && !hidden;
        })
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
