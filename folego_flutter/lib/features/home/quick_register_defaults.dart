/// Resolves a single choice *after* the user explicitly confirms it.
/// Never call this helper from catalog loading: payment selection is deliberate.
String? quickRegisterInstrumentId<T>({
  required List<T> items,
  required String? currentId,
  required String Function(T) idOf,
}) {
  if (currentId != null) {
    // An explicit selection that disappeared must not silently become another
    // account when a catalog refresh completes while the draft is open.
    return items.any((item) => idOf(item) == currentId) ? currentId : null;
  }
  return items.length == 1 ? idOf(items.single) : null;
}

/// Existing payment choices remain valid only while their instrument exists.
String? quickRegisterExistingInstrumentId<T>({
  required List<T> items,
  required String? currentId,
  required String Function(T) idOf,
}) {
  if (currentId == null) return null;
  return items.any((item) => idOf(item) == currentId) ? currentId : null;
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
