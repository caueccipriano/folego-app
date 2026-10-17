import 'category_item.dart';

abstract final class CategorySearch {
  static List<CategoryItem> search(
    Iterable<CategoryItem> categories,
    String query, {
    int limit = 40,
  }) {
    final normalized = normalize(query);
    final items = categories.where((item) => item.isSelectable).toList();

    if (normalized.isEmpty) {
      items.sort(_defaultCompare);
      return items.take(limit).toList(growable: false);
    }

    final scored = <({CategoryItem item, int score})>[];
    for (final item in items) {
      final score = _score(item, normalized);
      if (score != null) scored.add((item: item, score: score));
    }

    scored.sort((a, b) {
      final byScore = a.score.compareTo(b.score);
      if (byScore != 0) return byScore;
      return _defaultCompare(a.item, b.item);
    });

    return scored.take(limit).map((entry) => entry.item).toList(growable: false);
  }

  static String normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('ä', 'a')
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('ë', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ì', 'i')
        .replaceAll('î', 'i')
        .replaceAll('ï', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ò', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ö', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ù', 'u')
        .replaceAll('û', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ç', 'c');
  }

  static int? _score(CategoryItem item, String query) {
    final name = normalize(item.name);
    final parent = normalize(item.parentName ?? '');
    final breadcrumb = normalize(item.breadcrumb);
    final aliases = item.searchAliases.map(normalize).toList();

    if (name == query) return 0;
    if (name.startsWith(query)) return 1;
    if (aliases.any((alias) => alias == query)) return 2;
    if (aliases.any((alias) => alias.startsWith(query))) return 3;
    if (name.contains(query)) return 4;
    if (parent.startsWith(query)) return 5;
    if (breadcrumb.contains(query)) return 6;
    if (aliases.any((alias) => alias.contains(query))) return 7;
    return null;
  }

  static int _defaultCompare(CategoryItem a, CategoryItem b) {
    final byUsage = b.usageCount.compareTo(a.usageCount);
    if (byUsage != 0) return byUsage;

    final aDate = a.lastUsedAt;
    final bDate = b.lastUsedAt;
    if (aDate != null || bDate != null) {
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      final byDate = bDate.compareTo(aDate);
      if (byDate != 0) return byDate;
    }

    final bySort = a.sortOrder.compareTo(b.sortOrder);
    if (bySort != 0) return bySort;
    return normalize(a.breadcrumb).compareTo(normalize(b.breadcrumb));
  }
}
