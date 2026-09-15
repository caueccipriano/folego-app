/// Removes import-only suffixes from financial descriptions for presentation.
///
/// This helper never mutates persisted data. It only cleans text shown in UI.
String financialDisplayDescription(String value) {
  return value
      .replaceFirst(
        RegExp(r'\s*\[extrato\s+\d+\]\s*$', caseSensitive: false),
        '',
      )
      .trim();
}
