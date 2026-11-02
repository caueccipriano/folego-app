/// Selects a valid instrument without guessing between multiple choices.
/// A previous selection is retained only when it still belongs to the catalog.
/// Exactly one available option is safe to propose; two or more require a tap.
String? quickRegisterInstrumentId<T>({
  required List<T> items,
  required String? currentId,
  required String Function(T) idOf,
}) {
  if (currentId != null && items.any((item) => idOf(item) == currentId)) {
    return currentId;
  }
  return items.length == 1 ? idOf(items.single) : null;
}

/// A history shortcut may only reuse a payment account for a direct expense.
/// Card and benefit purchases have different financial posting semantics.
String? quickRegisterHistoryAccountId({
  required String eventType,
  required String? historicalAccountId,
  required List<String> activeAccountIds,
  required bool currentlyUsingAccount,
  required String? selectedAccountId,
}) {
  if (!currentlyUsingAccount || selectedAccountId != null) return null;
  if (eventType != 'expense' || historicalAccountId == null) return null;
  return activeAccountIds.contains(historicalAccountId)
      ? historicalAccountId
      : null;
}
