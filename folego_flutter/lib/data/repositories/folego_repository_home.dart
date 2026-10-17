import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/home_expense_summary.dart';
import '../models/transaction_item.dart';
import 'folego_repository.dart';

export '../models/home_expense_summary.dart' show homeExpenseEventTypes;

extension FolegoRepositoryHome on FolegoRepository {
  Future<List<TransactionItem>> getHomeExpenseTransactions(
    String spaceId, {
    DateTime? referenceDate,
  }) async {
    final reference = referenceDate ?? DateTime.now();
    final monthStart = DateTime(reference.year, reference.month, 1);
    final nextMonth = DateTime(reference.year, reference.month + 1, 1);

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
          category:categories(
            id,
            name,
            color_hex,
            parent_id
          ),
          financial_impacts!inner(
            dimension,
            amount
          )
        ''')
        .eq('space_id', spaceId)
        .neq('status', 'ignored')
        .neq('status', 'cancelled')
        .eq('financial_impacts.dimension', 'economic')
        .lt('financial_impacts.amount', 0)
        .gte('competence_date', _homeDate(monthStart))
        .lt('competence_date', _homeDate(nextMonth))
        .order('occurred_at', ascending: false);

    return List<Map<String, dynamic>>.from(response)
        .map(TransactionItem.fromJson)
        .where((item) => isHomeExpenseEventType(item.eventType))
        .toList(growable: false);
  }
}

String _homeDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
