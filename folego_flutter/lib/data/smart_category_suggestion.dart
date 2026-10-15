import '../models/category_item.dart';
import '../models/transaction_item.dart';

/// Read-only local recommendations from this financial space's own history
/// and selectable category aliases. Never auto-save or infer from amounts.
class SmartCategorySuggestion {
  const SmartCategorySuggestion({
    required this.category,
    required this.reason,
    required this.evidenceCount,
  });

  final CategoryItem category;
  final String reason;
  final int evidenceCount;
}

const _genericDescriptions = <String>{
  'pix', 'pix enviado', 'pix enviada', 'pix recebido', 'pix recebida',
  'pix enviada santander', 'pix enviado santander',
  'pix recebida santander', 'pix recebido santander',
  'pagamento pix', 'transferencia', 'transferencia recebida',
  'compra cartao', 'compra no cartao', 'cartao', 'pagamento',
  'debito', 'credito', 'compra', 'outros', 'diversos',
};

String _normalizeCategoryText(String text) {
  var value = text.toLowerCase().trim();
  const replace = <String, String>{
    'á':'a','à':'a','â':'a','ã':'a','ä':'a',
    'é':'e','è':'e','ê':'e','ë':'e',
    'í':'i','ì':'i','î':'i',
    'ó':'o','ò':'o','ô':'o','õ':'o','ö':'o',
    'ú':'u','ù':'u','û':'u','ü':'u','ç':'c',
  };
  for (final entry in replace.entries) {
    value = value.replaceAll(entry.key, entry.value);
  }
  return value.replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ').trim();
}

bool _specificDescription(String normalized) {
  if (normalized.length < 4 || _genericDescriptions.contains(normalized)) {
    return false;
  }
  final parts = normalized.split(' ');
  return parts.any((part) => part.length >= 4 && !const <String>{
    'pix', 'para', 'pelo', 'pela', 'com', 'sem', 'compra', 'pagamento',
    'debito', 'credito', 'transferencia', 'enviado', 'recebido',
  }.contains(part));
}

String? _direction(String eventType) {
  if (eventType == 'income' || eventType == 'benefit_credit') {
    return 'income';
  }
  if (eventType == 'expense' || eventType == 'card_purchase' ||
      eventType == 'benefit_expense') {
    return 'expense';
  }
  return null;
}

/// Conflicting exact matches yield NO guess. We also deliberately avoid
/// amount-based prediction, unseen users and category creation.
SmartCategorySuggestion? suggestSmartCategory({
  required String description,
  required String eventType,
  required Iterable<TransactionItem> history,
  required Iterable<CategoryItem> categories,
}) {
  final query = _normalizeCategoryText(description);
  final direction = _direction(eventType);
  if (direction == null || !_specificDescription(query)) return null;

  final catalog = <String, CategoryItem>{};
  for (final category in categories) {
    if (category.active && category.isSelectable &&
        (category.categoryRole == null || category.categoryRole == 'economic') &&
        (category.kind == null || category.kind == direction)) {
      catalog[category.id] = category;
    }
  }

  // Most reliable: same meaningful description categorized previously.
  final votes = <String, int>{};
  for (final item in history) {
    if (item.status != 'confirmed' ||
        _direction(item.eventType) != direction ||
        !catalog.containsKey(item.categoryId) ||
        _normalizeCategoryText(item.description) != query) {
      continue;
    }
    final id = item.categoryId!;
    votes[id] = (votes[id] ?? 0) + 1;
  }
  if (votes.isNotEmpty) {
    if (votes.length != 1) return null; // Conflict requires human selection.
    final match = votes.entries.single;
    return SmartCategorySuggestion(
      category: catalog[match.key]!,
      reason: match.value >= 2
          ? 'mesma descrição classificada ${match.value} vezes'
          : 'mesma descrição classificada anteriormente',
      evidenceCount: match.value,
    );
  }

  // A category name or explicit alias must be a complete token/phrase,
  // never an arbitrary substring. Ambiguous matches are intentionally hidden.
  final matches = <CategoryItem>[];
  for (final category in catalog.values) {
    final phrases = <String>{category.name, ...category.searchAliases}
        .map(_normalizeCategoryText)
        .where((part) => part.length >= 5 &&
            !_genericDescriptions.contains(part) &&
            !const <String>{'outros', 'geral', 'diversos', 'receitas', 'despesas'}
                .contains(part));
    if (phrases.any((part) => query == part ||
        query.startsWith('$part ') ||
        query.endsWith(' $part') ||
        query.contains(' $part '))) {
      matches.add(category);
    }
  }
  if (matches.length != 1) return null;
  return SmartCategorySuggestion(
    category: matches.single,
    reason: 'nome ou palavra-chave da categoria',
    evidenceCount: 0,
  );
}
