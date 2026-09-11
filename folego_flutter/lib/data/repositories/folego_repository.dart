import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/upcoming_events.dart';
import '../models/account_item.dart';
import '../models/category_item.dart';
import '../models/financial_space.dart';
import '../models/folego_snapshot.dart';
import '../models/onboarding_state.dart';
import '../models/recurring_item.dart';
import '../models/transaction_item.dart';
import '../models/budget_overview_item.dart';
import '../models/wallet_overview.dart';

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

    if (userId == null) {
      return 'Você';
    }

    final response = await _client
        .from('profiles')
        .select('full_name')
        .eq('id', userId)
        .limit(1);

    final rows = List<Map<String, dynamic>>.from(response);

    final fullName = rows.isEmpty ? null : rows.first['full_name'] as String?;

    if (fullName == null || fullName.trim().isEmpty) {
      return 'Você';
    }

    return fullName.trim().split(RegExp(r'\s+')).first;
  }

  Future<List<UpcomingEvent>> getUpcomingEvents(
    String spaceId, {
    DateTime? from,
    int days = 30,
  }) async {
    final now = from ?? DateTime.now();

    final startDate = DateTime(now.year, now.month, now.day);

    final endDate = startDate.add(Duration(days: days - 1));

    final response = await _client.rpc(
      'get_upcoming_events',
      params: {
        'p_space_id': spaceId,
        'p_from': _date(startDate),
        'p_until': _date(endDate),
      },
    );

    final rows = response as List<dynamic>;

    return rows
        .map(
          (row) =>
              UpcomingEvent.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  // ---------------------------------------------------------------------------
  // TRANSAÇÕES
  // ---------------------------------------------------------------------------

  Future<List<TransactionItem>> getTransactions(String spaceId) async {
    final response = await _client
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
          color_hex
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
        .neq('status', 'ignored')
        .neq('status', 'cancelled')
        .order('occurred_at', ascending: false)
        .limit(100);

    final rows = List<Map<String, dynamic>>.from(response);

    return rows.map(TransactionItem.fromJson).toList();
  }

  Future<void> updateSimpleTransaction({
    required String spaceId,
    required String eventId,
    required String accountId,
    required num amount,
    required String description,
    required String? categoryId,
    required DateTime occurredAt,
  }) async {
    String dateOnly(DateTime date) {
      final year = date.year.toString().padLeft(4, '0');

      final month = date.month.toString().padLeft(2, '0');

      final day = date.day.toString().padLeft(2, '0');

      return '$year-$month-$day';
    }

    await _client.rpc(
      'update_simple_transaction',
      params: {
        'p_space_id': spaceId,
        'p_event_id': eventId,
        'p_account_id': accountId,
        'p_amount': amount,
        'p_description': description.trim(),
        'p_category_id': categoryId,
        'p_occurred_at': occurredAt.toIso8601String(),
        'p_competence_date': dateOnly(occurredAt),
      },
    );
  }

  // ---------------------------------------------------------------------------
  // RECORRÊNCIAS
  // ---------------------------------------------------------------------------

  Future<List<RecurringItem>> listRecurringItems(String spaceId) async {
    final response = await _client
        .from('recurring_items')
        .select(
          'id,space_id,name,item_type,amount,frequency,'
          'day_of_month,weekday,month_of_year,category_id,'
          'account_id,card_id,starts_on,ends_on,certainty,active,'
          'category:categories(name),'
          'account:accounts(name)',
        )
        .eq('space_id', spaceId)
        .order('active', ascending: false)
        .order('name', ascending: true);

    final rows = List<Map<String, dynamic>>.from(response);

    return rows.map(RecurringItem.fromJson).toList();
  }

  Future<String> createRecurringItem({
    required String spaceId,
    required String name,
    required String itemType,
    required num amount,
    required String frequency,
    String? accountId,
    String? cardId,
    String? categoryId,
    int? dayOfMonth,
    List<int>? monthlyDays,
    bool monthlyLastDay = false,
    int? weekday,
    int? monthOfYear,
    required DateTime startsOn,
    DateTime? endsOn,
    String certainty = 'confirmed',
  }) async {
    final normalizedMonthlyDays = _normalizeMonthlyDays(
      monthlyDays,
      fallbackDay: frequency == 'monthly' ? dayOfMonth : null,
    );

    _validateRecurring(
      name: name,
      itemType: itemType,
      amount: amount,
      frequency: frequency,
      accountId: accountId,
      cardId: cardId,
      dayOfMonth: dayOfMonth,
      monthlyDays: normalizedMonthlyDays,
      monthlyLastDay: monthlyLastDay,
      weekday: weekday,
      monthOfYear: monthOfYear,
      startsOn: startsOn,
      endsOn: endsOn,
    );

    final response = await _client
        .from('recurring_items')
        .insert({
          'space_id': spaceId,
          'name': name.trim(),
          'item_type': itemType,
          'amount': amount,
          'frequency': frequency,
          'category_id': categoryId,
          'account_id': accountId,
          'card_id': cardId,

          'day_of_month': frequency == 'monthly'
              ? (normalizedMonthlyDays.isEmpty
                    ? null
                    : normalizedMonthlyDays.first)
              : dayOfMonth,

          'monthly_days': frequency == 'monthly'
              ? normalizedMonthlyDays
              : <int>[],

          'monthly_last_day': frequency == 'monthly' ? monthlyLastDay : false,

          'weekday': weekday,
          'month_of_year': monthOfYear,
          'starts_on': _date(startsOn),
          'ends_on': endsOn == null ? null : _date(endsOn),
          'certainty': certainty,
          'active': true,
        })
        .select('id')
        .single();

    return response['id'] as String;
  }

  Future<void> updateRecurringItem({
    required String spaceId,
    required String itemId,
    required String name,
    required String itemType,
    required num amount,
    required String frequency,
    String? accountId,
    String? cardId,
    String? categoryId,
    int? dayOfMonth,
    List<int>? monthlyDays,
    bool monthlyLastDay = false,
    int? weekday,
    int? monthOfYear,
    required DateTime startsOn,
    DateTime? endsOn,
    String certainty = 'confirmed',
    required bool active,
  }) async {
    final normalizedMonthlyDays = _normalizeMonthlyDays(
      monthlyDays,
      fallbackDay: frequency == 'monthly' ? dayOfMonth : null,
    );

    _validateRecurring(
      name: name,
      itemType: itemType,
      amount: amount,
      frequency: frequency,
      accountId: accountId,
      cardId: cardId,
      dayOfMonth: dayOfMonth,
      monthlyDays: normalizedMonthlyDays,
      monthlyLastDay: monthlyLastDay,
      weekday: weekday,
      monthOfYear: monthOfYear,
      startsOn: startsOn,
      endsOn: endsOn,
    );

    await _client
        .from('recurring_items')
        .update({
          'name': name.trim(),
          'item_type': itemType,
          'amount': amount,
          'frequency': frequency,
          'category_id': categoryId,
          'account_id': accountId,
          'card_id': cardId,

          'day_of_month': frequency == 'monthly'
              ? (normalizedMonthlyDays.isEmpty
                    ? null
                    : normalizedMonthlyDays.first)
              : dayOfMonth,

          'monthly_days': frequency == 'monthly'
              ? normalizedMonthlyDays
              : <int>[],

          'monthly_last_day': frequency == 'monthly' ? monthlyLastDay : false,

          'weekday': weekday,
          'month_of_year': monthOfYear,
          'starts_on': _date(startsOn),
          'ends_on': endsOn == null ? null : _date(endsOn),
          'certainty': certainty,
          'active': active,
        })
        .eq('space_id', spaceId)
        .eq('id', itemId);
  }

  Future<void> setRecurringActive({
    required String spaceId,
    required String itemId,
    required bool active,
  }) async {
    await _client
        .from('recurring_items')
        .update({'active': active})
        .eq('id', itemId)
        .eq('space_id', spaceId);
  }

  Future<void> deleteRecurringItem({
    required String spaceId,
    required String itemId,
  }) async {
    await _client
        .from('recurring_items')
        .delete()
        .eq('id', itemId)
        .eq('space_id', spaceId);
  }

  Future<String> realizeRecurring({
    required String spaceId,
    required String itemId,
    required DateTime dueDate,
    num? amount,
  }) async {
    final params = <String, dynamic>{
      'p_space_id': spaceId,
      'p_item_id': itemId,
      'p_due_date': _date(dueDate),
    };

    if (amount != null) {
      params['p_amount'] = amount;
    }

    final data = await _client.rpc('realize_recurring', params: params);

    return data as String;
  }

  void _validateRecurring({
    required String name,
    required String itemType,
    required num amount,
    required String frequency,
    required String? accountId,
    required String? cardId,
    required int? dayOfMonth,
    required List<int> monthlyDays,
    required bool monthlyLastDay,
    required int? weekday,
    required int? monthOfYear,
    required DateTime startsOn,
    required DateTime? endsOn,
  }) {
    if (name.trim().isEmpty) {
      throw ArgumentError('Informe o nome da recorrência.');
    }

    if (itemType != 'expense' && itemType != 'income') {
      throw ArgumentError('Tipo de recorrência inválido.');
    }

    if (amount <= 0) {
      throw ArgumentError('O valor deve ser maior que zero.');
    }

    if (accountId == null && cardId == null) {
      throw ArgumentError('Selecione uma conta.');
    }

    const validFrequencies = {'weekly', 'biweekly', 'monthly', 'yearly'};

    if (!validFrequencies.contains(frequency)) {
      throw ArgumentError('Frequência inválida.');
    }

    if (endsOn != null && endsOn.isBefore(startsOn)) {
      throw ArgumentError('A data final não pode ser anterior à inicial.');
    }

    if (frequency == 'weekly' || frequency == 'biweekly') {
      if (weekday == null || weekday < 0 || weekday > 6) {
        throw ArgumentError('Selecione um dia da semana.');
      }
    }

    if (frequency == 'monthly') {
      if (monthlyDays.isEmpty && !monthlyLastDay) {
        throw ArgumentError('Selecione pelo menos um dia do mês.');
      }

      for (final day in monthlyDays) {
        if (day < 1 || day > 31) {
          throw ArgumentError('O dia do mês deve estar entre 1 e 31.');
        }
      }
    }

    if (frequency == 'yearly') {
      if (dayOfMonth == null || dayOfMonth < 1 || dayOfMonth > 31) {
        throw ArgumentError('Informe um dia válido.');
      }

      if (monthOfYear == null || monthOfYear < 1 || monthOfYear > 12) {
        throw ArgumentError('Informe um mês válido.');
      }
    }
  }

  List<int> _normalizeMonthlyDays(List<int>? days, {int? fallbackDay}) {
    final normalized = <int>{
      ...?days,
      if ((days == null || days.isEmpty) && fallbackDay != null) fallbackDay,
    }.where((day) => day >= 1 && day <= 31).toList()..sort();

    return normalized;
  }

  // ---------------------------------------------------------------------------
  // HOME / ONBOARDING
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // CONTAS E CATEGORIAS
  // ---------------------------------------------------------------------------

  Future<List<AccountItem>> listAccounts(String spaceId) async {
    final response = await _client
        .from('accounts')
        .select('id,name')
        .eq('space_id', spaceId)
        .eq('active', true)
        .order('name', ascending: true);

    return List<Map<String, dynamic>>.from(
      response,
    ).map(AccountItem.fromJson).toList();
  }

  Future<List<CategoryItem>> listExpenseCategories(String spaceId) async {
    final response = await _client
        .from('categories')
        .select('id,name,essential')
        .eq('space_id', spaceId)
        .eq('kind', 'expense')
        .eq('active', true)
        .order('name', ascending: true);

    return List<Map<String, dynamic>>.from(
      response,
    ).map(CategoryItem.fromJson).toList();
  }

  // Já deixamos preparado para quando criarmos
  // as categorias próprias de receita.
  Future<List<CategoryItem>> listIncomeCategories(String spaceId) async {
    final response = await _client
        .from('categories')
        .select('id,name,essential')
        .eq('space_id', spaceId)
        .eq('kind', 'income')
        .eq('active', true)
        .order('name', ascending: true);

    return List<Map<String, dynamic>>.from(
      response,
    ).map(CategoryItem.fromJson).toList();
  }

  // ---------------------------------------------------------------------------
  // ONBOARDING
  // ---------------------------------------------------------------------------

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

Future<WalletOverview> getWalletOverview({
  required String spaceId,
}) async {
  final data = await _client.rpc(
    'get_wallet_overview',
    params: {
      'p_space_id': spaceId,
    },
  );

  return WalletOverview.fromJson(
    Map<String, dynamic>.from(
      data as Map,
    ),
  );
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

  Future<List<BudgetOverviewItem>> getBudgetOverview({
    required String spaceId,
    required DateTime periodMonth,
  }) async {
    final month = DateTime(periodMonth.year, periodMonth.month);

    final data = await _client.rpc(
      'get_budget_overview',
      params: {'p_space_id': spaceId, 'p_period_month': _date(month)},
    );

    final rows = data as List<dynamic>;

    return rows
        .map(
          (row) => BudgetOverviewItem.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
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

  // ---------------------------------------------------------------------------
  // REGISTRO RÁPIDO
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // AUTENTICAÇÃO
  // ---------------------------------------------------------------------------

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

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
