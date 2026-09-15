import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/budget_overview_item.dart';
import 'folego_repository.dart';

extension FolegoRepositoryBudget on FolegoRepository {
  Future<void> setBudgetLimit({
    required String spaceId,
    required DateTime periodMonth,
    required String categoryId,
    required num plannedAmount,
    required BudgetLimitScope scope,
    num warningThreshold = 0.70,
    num criticalThreshold = 0.90,
  }) async {
    final month = DateTime(periodMonth.year, periodMonth.month);

    final result = await Supabase.instance.client.rpc(
      'set_budget_limit',
      params: {
        'p_space_id': spaceId,
        'p_period_month': _date(month),
        'p_category_id': categoryId,
        'p_planned_amount': plannedAmount,
        'p_scope': scope.rpcValue,
        'p_warning_threshold': warningThreshold,
        'p_critical_threshold': criticalThreshold,
      },
    );

    if (result != true) {
      throw StateError('Não foi possível atualizar o limite mensal.');
    }
  }

  String _date(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
