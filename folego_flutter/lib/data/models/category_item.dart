class CategoryItem {
  const CategoryItem({
    required this.id,
    required this.name,
    required this.essential,
    this.parentId,
    this.parentName,
  });

  final String id;
  final String name;
  final bool essential;
  final String? parentId;
  final String? parentName;

  String get path {
    final parent = parentName?.trim();
    if (parent == null || parent.isEmpty) return name;
    return '$parent > $name';
  }

  factory CategoryItem.fromJson(Map<String, dynamic> json) {
    return CategoryItem(
      id: json['id'] as String,
      name: json['name'] as String,
      essential: json['essential'] as bool? ?? false,
      parentId: json['parent_id'] as String?,
      parentName: json['parent_name'] as String?,
    );
  }
}
