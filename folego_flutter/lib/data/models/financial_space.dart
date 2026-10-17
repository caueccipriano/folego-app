class FinancialSpace {
  const FinancialSpace({required this.id, required this.name});

  final String id;
  final String name;

  factory FinancialSpace.fromJson(Map<String, dynamic> json) {
    return FinancialSpace(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? 'Minhas Finanças',
    );
  }
}
