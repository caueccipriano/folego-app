import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/monthly_money_summary.dart';
import 'folego_repository.dart';

extension FolegoRepositoryMonthlyMoney on FolegoRepository {
  Future<MonthlyMoneySummary> getMonthlyMoneySummary({
    required String spaceId,
    DateTime? periodMonth,
  }) async {
    final reference = periodMonth ?? DateTime.now();
    final month = DateTime(reference.year, reference.month);

    final data = await Supabase.instance.client.rpc(
      'get_monthly_money_summary',
      params: {
        'p_space_id': spaceId,
        'p_period_month': _date(month),
      },
    );

    final row = data is List
        ? Map<String, dynamic>.from(data.first as Map)
        : Map<String, dynamic>.from(data as Map);

    return MonthlyMoneySummary.fromJson(row);
  }
}

String _date(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
