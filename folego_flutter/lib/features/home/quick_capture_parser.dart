/// Preenchimento apenas visual. Nunca registra lançamentos automaticamente.
class QuickCaptureDraft {
  const QuickCaptureDraft({
    required this.description,
    required this.amountText,
  });

  final String description;
  final String amountText;

  /// Aceita texto e valor em ambas as ordens; exige centavos explícitos.
  static QuickCaptureDraft? parse(String input) {
    final value = input.trim();
    if (value.isEmpty || value.length > 180) return null;

    final trailing = RegExp(
      r'^(.+?)\s+(?:R\$\s*)?(\d+(?:\.\d{3})*,\d{2}|\d+\.\d{2})$',
      caseSensitive: false,
    ).firstMatch(value);
    final leading = trailing == null
        ? RegExp(
            r'^(?:R\$\s*)?(\d+(?:\.\d{3})*,\d{2}|\d+\.\d{2})\s+(.+)$',
            caseSensitive: false,
          ).firstMatch(value)
        : null;

    if (trailing == null && leading == null) return null;
    final description = (trailing?.group(1) ?? leading!.group(2)!).trim();
    if (description.isEmpty ||
        description.startsWith('-') ||
        description.startsWith('+') ||
        description.endsWith('-') ||
        description.endsWith('+')) {
      return null;
    }

    final token = trailing?.group(2) ?? leading!.group(1)!;
    final normalized = token.contains(',')
        ? token.replaceAll('.', '').replaceAll(',', '.')
        : token;
    final amount = double.tryParse(normalized);
    if (amount == null || !amount.isFinite || amount <= 0) return null;

    return QuickCaptureDraft(
      description: description,
      amountText: amount.toStringAsFixed(2).replaceAll('.', ','),
    );
  }
}
