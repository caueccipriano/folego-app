class CategoryTag {
  const CategoryTag({
    required this.id,
    required this.name,
    required this.type,
    this.colorHex,
    this.active = true,
  });

  final String id;
  final String name;
  final String type;
  final String? colorHex;
  final bool active;

  bool get isProject => type == 'project';
  bool get isPerson => type == 'person';

  factory CategoryTag.fromJson(Map<String, dynamic> json) {
    return CategoryTag(
      id: json['id'] as String,
      name: json['name'] as String,
      type: (json['tag_type'] ?? json['type'] ?? 'tag') as String,
      colorHex: json['color_hex'] as String?,
      active: json['active'] as bool? ?? true,
    );
  }
}
