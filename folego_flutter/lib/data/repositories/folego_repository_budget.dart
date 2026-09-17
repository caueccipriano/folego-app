import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/budget_overview_item.dart';
import 'folego_repository.dart';

extension FolegoRepositoryBudget on FolegoRepository {
  Future<FlexibleBudgetOverview> getFlexibleBudgetOverview({
    required String spaceId,
    required DateTime periodMonth,
  }) async {
    final month = DateTime(periodMonth.year, periodMonth.month);
    final result = await Supabase.instance.client.rpc(
      'get_flexible_budget_overview',
      params: {
        'p_space_id': spaceId,
        'p_period_month': _date(month),
      },
    );

    final rows = List<Map<String, dynamic>>.from(result as List<dynamic>);
    if (rows.isEmpty) {
      return FlexibleBudgetOverview(
        periodMonth: month,
        configured: false,
        explicitLimit: false,
        limitAmount: 0,
        usedAmount: 0,
        remainingAmount: 0,
        exceededAmount: 0,
        categoryLimitsTotal: 0,
      );
    }
    return FlexibleBudgetOverview.fromJson(rows.first);
  }

  Future<void> setFlexibleBudgetLimit({
    required String spaceId,
    required DateTime periodMonth,
    required num limitAmount,
  }) async {
    if (limitAmount < 0) {
      throw ArgumentError.value(
        limitAmount,
        'limitAmount',
        'O teto flexível não pode ser negativo.',
      );
    }

    final month = DateTime(periodMonth.year, periodMonth.month);
    final result = await Supabase.instance.client.rpc(
      'set_flexible_budget_limit',
      params: {
        'p_space_id': spaceId,
        'p_period_month': _date(month),
        'p_limit': limitAmount,
      },
    );

    if (result != true) {
      throw StateError('Não foi possível atualizar o orçamento flexível.');
    }
  }

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
