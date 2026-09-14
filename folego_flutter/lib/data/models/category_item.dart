class CategoryItem {
  const CategoryItem({
    required this.id,
    required this.name,
    required this.essential,
    this.kind,
    this.parentId,
    this.parentName,
    this.isSystem = false,
    this.isSelectable = true,
    this.searchAliases = const <String>[],
    this.sortOrder = 100,
    this.usageCount = 0,
    this.lastUsedAt,
  });

  final String id;
  final String name;
  final bool essential;
  final String? kind;

  /// Null = categoria principal.
  /// Preenchido = subcategoria pertencente à categoria desse ID.
  final String? parentId;
  final String? parentName;

  final bool isSystem;
  final bool isSelectable;
  final List<String> searchAliases;
  final int sortOrder;
  final int usageCount;
  final DateTime? lastUsedAt;

  bool get isParent => parentId == null;

  bool get isSubcategory => parentId != null;

  String get breadcrumb {
    final parent = parentName?.trim();
    if (parent == null || parent.isEmpty) return name;
    return '$parent > $name';
  }

  String get normalizedSearchText => _normalize(
        <String>[
          name,
          if (parentName != null) parentName!,
          ...searchAliases,
        ].join(' '),
      );

  bool matchesSearch(String query) {
    final normalized = _normalize(query);
    if (normalized.isEmpty) return true;
    return normalizedSearchText.contains(normalized);
  }

  factory CategoryItem.fromJson(Map<String, dynamic> json) {
    final aliasesRaw = json['search_aliases'];
    final aliases = aliasesRaw is List
        ? aliasesRaw.whereType<Object>().map((item) => item.toString()).toList()
        : const <String>[];

    final lastUsedRaw = json['last_used_at'];

    return CategoryItem(
      id: json['id'] as String,
      name: json['name'] as String,
      essential: json['essential'] as bool? ?? false,
      kind: json['kind'] as String?,
      parentId: json['parent_id'] as String?,
      parentName: json['parent_name'] as String?,
      isSystem: json['is_system'] as bool? ?? false,
      isSelectable: json['is_selectable'] as bool? ?? true,
      searchAliases: aliases,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 100,
      usageCount: (json['usage_count'] as num?)?.toInt() ?? 0,
      lastUsedAt: lastUsedRaw == null
          ? null
          : DateTime.tryParse(lastUsedRaw.toString()),
    );
  }

  static String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
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
}
