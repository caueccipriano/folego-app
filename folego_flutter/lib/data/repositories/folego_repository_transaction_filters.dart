import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/category_item.dart';
import '../models/transaction_filters.dart';
import '../models/transaction_item.dart';
import '../models/transaction_page.dart';
import 'folego_repository.dart';
import 'folego_repository_payment_instruments.dart';

extension FolegoRepositoryTransactionFilters on FolegoRepository {
  Future<TransactionPage> getTransactionsFilteredPage(
    String spaceId, {
    required TransactionFilters filters,
    TransactionCursor? cursor,
    int pageSize = transactionPageSize,
  }) async {
    if (pageSize <= 0 || pageSize > 100) {
      throw ArgumentError.value(
        pageSize,
        'pageSize',
        'Deve estar entre 1 e 100.',
      );
    }

    final eventTypes = filters.eventTypes.toList()..sort();
    final response = await Supabase.instance.client.rpc(
      'list_transactions_filtered',
      params: {
        'p_space_id': spaceId,
        'p_date_from': _transactionFilterDate(filters.startDate),
        'p_date_to': _transactionFilterDate(filters.endDate),
        'p_event_types': eventTypes.isEmpty ? null : eventTypes,
        'p_category_id': filters.categoryId,
        'p_account_id': filters.accountId,
        'p_card_id': filters.cardId,
        'p_benefit_account_id': filters.benefitAccountId,
        'p_search': filters.normalizedSearch.isEmpty
            ? null
            : filters.normalizedSearch,
        'p_cursor_occurred_at': cursor?.occurredAt.toUtc().toIso8601String(),
        'p_cursor_id': cursor?.id,
        'p_limit': pageSize + 1,
      },
    );

    final rows = List<Map<String, dynamic>>.from(response as List);
    final fetched = rows.map(TransactionItem.fromJson).toList(growable: false);
    return TransactionPage.fromFetched(fetched, pageSize: pageSize);
  }

  Future<TransactionFilterOptions> getTransactionFilterOptions(
    String spaceId,
  ) async {
    final values = await Future.wait<dynamic>([
      listExpenseCategories(spaceId),
      listIncomeCategories(spaceId),
      listPaymentAccounts(spaceId),
      listActiveCreditCards(spaceId),
      listBenefitAccounts(spaceId),
    ]);

    final categoriesById = <String, CategoryItem>{};
    for (final category in <CategoryItem>[
      ...(values[0] as List<CategoryItem>),
      ...(values[1] as List<CategoryItem>),
    ]) {
      categoriesById[category.id] = category;
    }

    final categories = categoriesById.values.toList(growable: false)
      ..sort((a, b) => a.breadcrumb.toLowerCase().compareTo(
            b.breadcrumb.toLowerCase(),
          ));

    return TransactionFilterOptions(
      categories: categories,
      accounts: values[2] as List,
      cards: values[3] as List,
      benefits: values[4] as List,
    );
  }
}

String? _transactionFilterDate(DateTime? value) {
  if (value == null) return null;
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}
