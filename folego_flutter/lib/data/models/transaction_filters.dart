import 'account_item.dart';
import 'category_item.dart';
import 'credit_card_item.dart';

const Object _transactionFilterUnset = Object();

class TransactionFilters {
  TransactionFilters({
    this.startDate,
    this.endDate,
    Set<String> eventTypes = const <String>{},
    this.categoryId,
    this.accountId,
    this.cardId,
    this.benefitAccountId,
    this.search = '',
  }) : eventTypes = Set<String>.unmodifiable(eventTypes);

  factory TransactionFilters.empty() => TransactionFilters();

  final DateTime? startDate;
  final DateTime? endDate;
  final Set<String> eventTypes;
  final String? categoryId;
  final String? accountId;
  final String? cardId;
  final String? benefitAccountId;
  final String search;

  String get normalizedSearch => search.trim();

  bool get hasPeriod => startDate != null || endDate != null;

  bool get hasFilters => activeFilterCount > 0;

  bool get hasQuery => hasFilters || normalizedSearch.isNotEmpty;

  int get activeFilterCount {
    var count = 0;
    if (hasPeriod) count += 1;
    if (eventTypes.isNotEmpty) count += 1;
    if (categoryId != null) count += 1;
    if (accountId != null) count += 1;
    if (cardId != null) count += 1;
    if (benefitAccountId != null) count += 1;
    return count;
  }

  TransactionFilters copyWith({
    Object? startDate = _transactionFilterUnset,
    Object? endDate = _transactionFilterUnset,
    Set<String>? eventTypes,
    Object? categoryId = _transactionFilterUnset,
    Object? accountId = _transactionFilterUnset,
    Object? cardId = _transactionFilterUnset,
    Object? benefitAccountId = _transactionFilterUnset,
    String? search,
  }) {
    return TransactionFilters(
      startDate: identical(startDate, _transactionFilterUnset)
          ? this.startDate
          : startDate as DateTime?,
      endDate: identical(endDate, _transactionFilterUnset)
          ? this.endDate
          : endDate as DateTime?,
      eventTypes: eventTypes ?? this.eventTypes,
      categoryId: identical(categoryId, _transactionFilterUnset)
          ? this.categoryId
          : categoryId as String?,
      accountId: identical(accountId, _transactionFilterUnset)
          ? this.accountId
          : accountId as String?,
      cardId: identical(cardId, _transactionFilterUnset)
          ? this.cardId
          : cardId as String?,
      benefitAccountId: identical(benefitAccountId, _transactionFilterUnset)
          ? this.benefitAccountId
          : benefitAccountId as String?,
      search: search ?? this.search,
    );
  }

  TransactionFilters clearNonSearch() {
    return TransactionFilters(search: search);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TransactionFilters &&
            _sameDate(startDate, other.startDate) &&
            _sameDate(endDate, other.endDate) &&
            _sameSet(eventTypes, other.eventTypes) &&
            categoryId == other.categoryId &&
            accountId == other.accountId &&
            cardId == other.cardId &&
            benefitAccountId == other.benefitAccountId &&
            search == other.search;
  }

  @override
  int get hashCode {
    final types = eventTypes.toList()..sort();
    return Object.hash(
      _dateHash(startDate),
      _dateHash(endDate),
      Object.hashAll(types),
      categoryId,
      accountId,
      cardId,
      benefitAccountId,
      search,
    );
  }
}

class TransactionFilterOptions {
  TransactionFilterOptions({
    Iterable<CategoryItem> categories = const <CategoryItem>[],
    Iterable<AccountItem> accounts = const <AccountItem>[],
    Iterable<CreditCardItem> cards = const <CreditCardItem>[],
    Iterable<AccountItem> benefits = const <AccountItem>[],
  }) : categories = List<CategoryItem>.unmodifiable(categories),
       accounts = List<AccountItem>.unmodifiable(accounts),
       cards = List<CreditCardItem>.unmodifiable(cards),
       benefits = List<AccountItem>.unmodifiable(benefits);

  factory TransactionFilterOptions.empty() => TransactionFilterOptions();

  final List<CategoryItem> categories;
  final List<AccountItem> accounts;
  final List<CreditCardItem> cards;
  final List<AccountItem> benefits;
}

bool _sameSet(Set<String> a, Set<String> b) {
  if (a.length != b.length) return false;
  return a.every(b.contains);
}

bool _sameDate(DateTime? a, DateTime? b) {
  if (a == null || b == null) return a == b;
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

int? _dateHash(DateTime? value) {
  if (value == null) return null;
  return Object.hash(value.year, value.month, value.day);
}
