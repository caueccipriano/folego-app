class CreditCardItem {
  const CreditCardItem({
    required this.id,
    required this.name,
    required this.active,
    this.issuer,
    this.brand,
    this.lastFour,
  });

  final String id;
  final String name;
  final String? issuer;
  final String? brand;
  final String? lastFour;
  final bool active;

  factory CreditCardItem.fromJson(Map<String, dynamic> json) {
    return CreditCardItem(
      id: json['id'] as String,
      name: json['name'] as String,
      issuer: _optionalText(json['issuer']),
      brand: _optionalText(json['brand']),
      lastFour: _optionalText(json['last_four']),
      active: json['active'] as bool? ?? true,
    );
  }
}

String? _optionalText(dynamic value) {
  if (value == null) {
    return null;
  }

  final text = value.toString().trim();

  return text.isEmpty ? null : text;
}
