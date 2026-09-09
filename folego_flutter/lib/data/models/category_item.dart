class CategoryItem {
  const CategoryItem({
    required this.id,
    required this.name,
    required this.essential,
  });

  final String id;
  final String name;
  final bool essential;

  factory CategoryItem.fromJson(Map<String, dynamic> json) {
    return CategoryItem(
      id: json['id'] as String,
      name: json['name'] as String,
      essential: json['essential'] as bool? ?? false,
    );
  }
}
