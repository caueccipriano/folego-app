class AccountItem {
  const AccountItem({required this.id, required this.name});

  final String id;
  final String name;

  factory AccountItem.fromJson(Map<String, dynamic> json) {
    return AccountItem(id: json['id'] as String, name: json['name'] as String);
  }
}
