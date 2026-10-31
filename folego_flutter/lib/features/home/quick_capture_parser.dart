/// Rascunho visual: não registra nem altera lançamentos.
class QuickCaptureDraft {
  const QuickCaptureDraft({required this.description, required this.amountText});

  final String description;
  final String amountText;

  /// Exemplos: "Uber 27,90" e "mercado R$ 1.234,56".
  /// Só aceita duas casas decimais, sem confundir anos ou endereços.
  static QuickCaptureDraft? parse(String input) {
    final value = input.trim();
    if (value.isEmpty || value.length > 180) return null;

    final match = RegExp(
      r'^(.+?)\s+(?:R\$\s*)?(\d+(?:\.\d{3})*,\d{2}|\d+\.\d{2})$',
      caseSensitive: false,
    ).firstMatch(value);
    if (match == null) return null;

    final description = match.group(1)!.trim();
    if (description.isEmpty ||
        description.endsWith('-') ||
        description.endsWith('+') ||
        description.endsWith('R$')) {
      return null;
    }

    final token = match.group(2)!;
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
