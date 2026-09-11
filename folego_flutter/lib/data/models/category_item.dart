class CategoryItem {
  const CategoryItem({
    required this.id,
    required this.name,
    required this.essential,
    this.parentId,
  });

  final String id;
  final String name;
  final bool essential;

  /// Null = categoria principal.
  /// Preenchido = subcategoria pertencente à categoria desse ID.
  final String? parentId;

  bool get isParent => parentId == null;

  bool get isSubcategory => parentId != null;

  factory CategoryItem.fromJson(Map<String, dynamic> json) {
    return CategoryItem(
      id: json['id'] as String,
      name: json['name'] as String,
      essential: json['essential'] as bool? ?? false,
      parentId: json['parent_id'] as String?,
    );
  }
}
