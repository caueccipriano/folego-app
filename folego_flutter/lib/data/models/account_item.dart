class AccountItem {
  const AccountItem({
    required this.id,
    required this.name,
    this.type,
  });

  static const benefitType = 'benefit';

  final String id;
  final String name;
  final String? type;

  bool get hasKnownType => type != null;

  bool get isBenefit => type == benefitType;

  bool get isPaymentAccount => hasKnownType && !isBenefit;

  factory AccountItem.fromJson(Map<String, dynamic> json) {
    return AccountItem(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String?,
    );
  }
}
