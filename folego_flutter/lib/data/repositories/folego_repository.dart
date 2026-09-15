import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/account_item.dart';
import '../models/budget_item.dart';
import '../models/category_item.dart';
import '../models/financial_space.dart';
import '../models/folego_snapshot.dart';
import '../models/onboarding_state.dart';

class FolegoRepository {
  FolegoRepository(this._client);

  final SupabaseClient _client;

  Future<FinancialSpace> getPrimarySpace() async {
    final response = await _client
        .from('financial_spaces')
        .select('id,name')
        .order('created_at')
        .limit(1);
    final rows = List<Map<String, dynamic>>.from(response);
    if (rows.isEmpty) {
      throw StateError('Nenhum espaço financeiro foi encontrado.');
    }
    return FinancialSpace.fromJson(rows.first);
  }

  Future<String> getProfileName() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 'Você';
    final response = await _client
        .from('profiles')
        .select('full_name')
        .eq('id', userId)
        .limit(1);
    final rows = List<Map<String, dynamic>>.from(response);
    final fullName = rows.isEmpty ? null : rows.first['full_name'] as String?;
    if (fullName == null || fullName.trim().isEmpty) return 'Você';
    return fullName.trim().split(RegExp(r'\s+')).first;
  }

  Future<OnboardingState> getOnboardingState(String spaceId) async {
    final data = await _client.rpc(
      'get_onboarding_state',
      params: {'p_space_id': spaceId},
    );
    return OnboardingState.fromJson(_firstMap(data));
  }

  Future<FolegoSnapshot> getSnapshot(
    String spaceId, {
    DateTime? asOfDate,
  }) async {
    final params = <String, dynamic>{'p_space_id': spaceId};
    if (asOfDate != null) {
      params['p_as_of_date'] = _date(asOfDate);
    }
    final data = await _client.rpc('get_folego_snapshot', params: params);
    return FolegoSnapshot.fromJson(_firstMap(data));
  }

  Future<List<AccountItem>> listAccounts(String spaceId) async {
    final response = await _client
        .from('accounts')
        .select('id,name')
        .eq('space_id', spaceId)
        .eq('active', true)
        .order('name');
    return List<Map<String, dynamic>>.from(response)
        .map(AccountItem.fromJson)
        .toList();
  }

  Future<List<CategoryItem>> listExpenseCategories(String spaceId) {
    return _listCategories(spaceId, 'expense');
  }

  Future<List<CategoryItem>> listIncomeCategories(String spaceId) {
    return _listCategories(spaceId, 'income');
  }

  Future<List<CategoryItem>> _listCategories(String spaceId, String kind) async {
    final response = await _client
        .from('categories')
        .select(
          'id,name,essential,parent_id,is_selectable,category_role,sort_order',
        )
        .eq('space_id', spaceId)
        .eq('kind', kind)
        .eq('active', true)
        .eq('category_role', 'economic')
        .order('sort_order')
        .order('name');

    final rows = List<Map<String, dynamic>>.from(response);
    final namesById = <String, String>{
      for (final row in rows)
        if (row['id'] != null && row['name'] != null)
          row['id'] as String: row['name'] as String,
    };

    return rows
        .where((row) => row['is_selectable'] as bool? ?? true)
        .map(
          (row) => CategoryItem(
            id: row['id'] as String,
            name: row['name'] as String,
            essential: row['essential'] as bool? ?? false,
            parentId: row['parent_id'] as String?,
            parentName: namesById[row['parent_id']],
          ),
        )
        .toList();
  }

  Future<List<BudgetItem>> listBudgetItems({
    required String spaceId,
    required DateTime periodMonth,
  }) async {
    final month = DateTime(periodMonth.year, periodMonth.month);
    final budgetResponse = await _client
        .from('budgets')
        .select('id')
        .eq('space_id', spaceId)
        .eq('period_month', _date(month))
        .limit(1);
    final budgetRows = List<Map<String, dynamic>>.from(budgetResponse);
    if (budgetRows.isEmpty) return const [];

    final categoryResponse = await _client
        .from('categories')
        .select('id,name,parent_id')
        .eq('space_id', spaceId)
        .eq('active', true);
    final categoryRows = List<Map<String, dynamic>>.from(categoryResponse);
    final categoryById = <String, Map<String, dynamic>>{
      for (final row in categoryRows) row['id'] as String: row,
    };

    String categoryPath(String id) {
      final row = categoryById[id];
      if (row == null) return 'Categoria';
      final name = row['name'] as String? ?? 'Categoria';
      final parentId = row['parent_id'] as String?;
      if (parentId == null) return name;
      final parent = categoryById[parentId];
      final parentName = parent?['name'] as String?;
      if (parentName == null || parentName.isEmpty) return name;
      return '$parentName > $name';
    }

    final itemResponse = await _client
        .from('budget_items')
        .select(
          'category_id,planned_amount,warning_threshold,critical_threshold',
        )
        .eq('space_id', spaceId)
        .eq('budget_id', budgetRows.first['id'] as String);
    final itemRows = List<Map<String, dynamic>>.from(itemResponse);

    final items = itemRows
        .map(
          (row) => BudgetItem(
            categoryId: row['category_id'] as String,
            categoryPath: categoryPath(row['category_id'] as String),
            plannedAmount: row['planned_amount'] as num? ?? 0,
            warningThreshold: row['warning_threshold'] as num? ?? 0.70,
            criticalThreshold: row['critical_threshold'] as num? ?? 0.90,
          ),
        )
        .toList();
    items.sort((a, b) => a.categoryPath.compareTo(b.categoryPath));
    return items;
  }

  Future<String> createOnboardingAccount({
    required String spaceId,
    required String name,
    required num openingBalance,
    required DateTime balanceDate,
    String? institution,
    String type = 'checking',
    bool availableForSpending = true,
  }) async {
    final data = await _client.rpc(
      'onboarding_create_account',
      params: {
        'p_space_id': spaceId,
        'p_name': name,
        'p_opening_balance': openingBalance,
        'p_balance_date': _date(balanceDate),
        'p_institution': institution,
        'p_type': type,
        'p_available_for_spending': availableForSpending,
      },
    );
    return data as String;
  }

  Future<String> configureIncome({
    required String spaceId,
    required String name,
    required num amount,
    required int dayOfMonth,
    required String accountId,
    required DateTime startsOn,
    String? categoryId,
  }) async {
    final data = await _client.rpc(
      'onboarding_configure_income',
      params: {
        'p_space_id': spaceId,
        'p_name': name,
        'p_amount': amount,
        'p_day_of_month': dayOfMonth,
        'p_account_id': accountId,
        'p_starts_on': _date(startsOn),
        'p_category_id': categoryId,
      },
    );
    return data as String;
  }

  Future<String> configureRecurringExpense({
    required String spaceId,
    required String name,
    required num amount,
    required int dayOfMonth,
    required String categoryId,
    required String accountId,
    required DateTime startsOn,
    String certainty = 'confirmed',
  }) async {
    final data = await _client.rpc(
      'onboarding_configure_recurring_expense',
      params: {
        'p_space_id': spaceId,
        'p_name': name,
        'p_amount': amount,
        'p_day_of_month': dayOfMonth,
        'p_category_id': categoryId,
        'p_account_id': accountId,
        'p_starts_on': _date(startsOn),
        'p_certainty': certainty,
      },
    );
    return data as String;
  }

  Future<String> createCard({
    required String spaceId,
    required String name,
    required int closingDay,
    required int dueDay,
    required String paymentAccountId,
    String? issuer,
    String? brand,
    String? lastFour,
    num? personalLimit,
    num? issuerLimit,
    num currentInvoiceBalance = 0,
    DateTime? currentInvoiceDueDate,
  }) async {
    final data = await _client.rpc(
      'onboarding_create_card',
      params: {
        'p_space_id': spaceId,
        'p_name': name,
        'p_closing_day': closingDay,
        'p_due_day': dueDay,
        'p_payment_account_id': paymentAccountId,
        'p_issuer': issuer,
        'p_brand': brand,
        'p_last_four': lastFour,
        'p_personal_limit': personalLimit,
        'p_issuer_limit': issuerLimit,
        'p_current_invoice_balance': currentInvoiceBalance,
        'p_current_invoice_due_date': currentInvoiceDueDate == null
            ? null
            : _date(currentInvoiceDueDate),
      },
    );
    return data as String;
  }

  Future<String> setBudgetItem({
    required String spaceId,
    required DateTime periodMonth,
    required String categoryId,
    required num plannedAmount,
    num warningThreshold = 0.70,
    num criticalThreshold = 0.90,
  }) async {
    final month = DateTime(periodMonth.year, periodMonth.month);
    final data = await _client.rpc(
      'onboarding_set_budget_item',
      params: {
        'p_space_id': spaceId,
        'p_period_month': _date(month),
        'p_category_id': categoryId,
        'p_planned_amount': plannedAmount,
        'p_warning_threshold': warningThreshold,
        'p_critical_threshold': criticalThreshold,
      },
    );
    return data as String;
  }

  Future<bool> completeOnboarding(String spaceId) async {
    final data = await _client.rpc(
      'onboarding_complete',
      params: {'p_space_id': spaceId},
    );
    return data as bool;
  }

  Future<String> registerExpense({
    required String spaceId,
    required String accountId,
    required num amount,
    required String description,
    String? categoryId,
    DateTime? occurredAt,
  }) async {
    final at = occurredAt ?? DateTime.now();
    final data = await _client.rpc(
      'register_expense',
      params: {
        'p_space_id': spaceId,
        'p_account_id': accountId,
        'p_amount': amount,
        'p_description': description,
        'p_category_id': categoryId,
        'p_occurred_at': at.toIso8601String(),
        'p_competence_date': _date(at),
        'p_source': 'app',
        'p_external_id': null,
      },
    );
    return data as String;
  }

  Future<String> registerIncome({
    required String spaceId,
    required String accountId,
    required num amount,
    required String description,
    String? categoryId,
    DateTime? occurredAt,
  }) async {
    final at = occurredAt ?? DateTime.now();
    final data = await _client.rpc(
      'register_income',
      params: {
        'p_space_id': spaceId,
        'p_account_id': accountId,
        'p_amount': amount,
        'p_description': description,
        'p_category_id': categoryId,
        'p_occurred_at': at.toIso8601String(),
        'p_competence_date': _date(at),
        'p_source': 'app',
        'p_external_id': null,
      },
    );
    return data as String;
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Map<String, dynamic> _firstMap(dynamic data) {
    if (data is List && data.isNotEmpty) {
      return Map<String, dynamic>.from(data.first as Map);
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    throw StateError('Resposta inesperada do Supabase.');
  }

  String _date(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
