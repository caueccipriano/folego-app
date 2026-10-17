class ProfileExportRow {
  const ProfileExportRow({
    required this.occurredAt,
    required this.description,
    required this.type,
    required this.amount,
    required this.status,
    required this.source,
    this.category,
    this.account,
    this.card,
  });

  final DateTime occurredAt;
  final String description;
  final String type;
  final double amount;
  final String? category;
  final String? account;
  final String? card;
  final String status;
  final String source;

  factory ProfileExportRow.fromJson(Map<String, dynamic> json) {
    final category = _firstMap(json['category'] ?? json['categories']);
    final account = _accountName(json['financial_impacts']);
    final card = _cardName(json);

    return ProfileExportRow(
      occurredAt: DateTime.parse(json['occurred_at'] as String),
      description: (json['description'] as String?)?.trim() ?? '',
      type: _typeLabel((json['event_type'] as String?) ?? ''),
      amount: _number(json['amount']),
      category: _nonEmpty(category?['name']),
      account: account,
      card: card,
      status: (json['status'] as String?)?.trim() ?? '',
      source: (json['source'] as String?)?.trim() ?? '',
    );
  }
}

const profileExportHeaders = <String>[
  'data',
  'descrição',
  'tipo',
  'valor',
  'categoria',
  'conta',
  'cartão',
  'status',
  'origem',
];

List<ProfileExportRow> parseProfileExportRows(
  Iterable<Map<String, dynamic>> rows, {
  required String expectedSpaceId,
}) {
  return rows
      .where((row) => row['space_id']?.toString() == expectedSpaceId)
      .map(ProfileExportRow.fromJson)
      .toList(growable: false);
}

String buildProfileExportCsv(Iterable<ProfileExportRow> rows) {
  final lines = <String>[
    profileExportHeaders.map(_csvCell).join(';'),
  ];

  for (final row in rows) {
    lines.add(
      <String>[
        _dateTime(row.occurredAt),
        row.description,
        row.type,
        row.amount.toStringAsFixed(2).replaceAll('.', ','),
        row.category ?? '',
        row.account ?? '',
        row.card ?? '',
        row.status,
        row.source,
      ].map(_csvCell).join(';'),
    );
  }

  return '\uFEFF${lines.join('\r\n')}\r\n';
}

String _csvCell(String value) {
  final normalized = value
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll('"', '""');
  return '"$normalized"';
}

String _dateTime(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}

String _typeLabel(String type) {
  switch (type) {
    case 'income':
      return 'receita';
    case 'expense':
      return 'despesa';
    case 'card_purchase':
      return 'compra no cartão';
    case 'card_payment':
      return 'pagamento de fatura';
    case 'benefit_credit':
      return 'crédito de benefício';
    case 'benefit_expense':
      return 'compra com benefício';
    case 'debt_payment':
      return 'pagamento de dívida';
    case 'transfer':
      return 'transferência';
    default:
      return type;
  }
}

String? _accountName(dynamic impactsRaw) {
  if (impactsRaw is! List) {
    return null;
  }

  Map<String, dynamic>? fallback;
  for (final raw in impactsRaw) {
    if (raw is! Map) continue;
    final impact = Map<String, dynamic>.from(raw);
    final account = _firstMap(impact['account']);
    final name = _nonEmpty(account?['name']);
    if (name == null) continue;

    fallback ??= impact;
    final dimension = impact['dimension']?.toString();
    if (dimension == 'cash' || dimension == 'benefit') {
      return name;
    }
  }

  return _nonEmpty(_firstMap(fallback?['account'])?['name']);
}

String? _cardName(Map<String, dynamic> json) {
  final purchase = _firstMap(json['card_purchases']);
  final purchaseCard = _firstMap(purchase?['card']);
  final purchaseCardName = _nonEmpty(purchaseCard?['name']);
  if (purchaseCardName != null) {
    return purchaseCardName;
  }

  final payment = _firstMap(json['card_payments']);
  final invoice = _firstMap(payment?['invoice']);
  final paymentCard = _firstMap(invoice?['card']);
  return _nonEmpty(paymentCard?['name']);
}

Map<String, dynamic>? _firstMap(dynamic value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }

  if (value is List) {
    for (final item in value) {
      if (item is Map) {
        return Map<String, dynamic>.from(item);
      }
    }
  }

  return null;
}

String? _nonEmpty(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

double _number(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
