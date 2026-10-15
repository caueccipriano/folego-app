enum DiscoveryKind {
  transaction,
  account,
  card,
  scheduled,
  classification,
  sync,
}

class DiscoveryEntry {
  const DiscoveryEntry({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    this.amount,
    this.date,
    this.priority = 3,
    this.searchContext = '',
    this.targetId,
  });
  final String id;
  final DiscoveryKind kind;
  final String title;
  final String subtitle;
  final double? amount;
  final DateTime? date;
  final int priority;
  final String searchContext;
  final String? targetId;

  String get kindLabel => switch (kind) {
    DiscoveryKind.transaction => 'lançamentos',
    DiscoveryKind.account => 'contas',
    DiscoveryKind.card => 'cartões',
    DiscoveryKind.scheduled => 'agenda',
    DiscoveryKind.classification => 'categorias',
    DiscoveryKind.sync => 'planilha',
  };
}

String normalizeDiscoveryText(String text) {
  var value = text.toLowerCase();
  const groups = {
    'áàãâä': 'a',
    'éèêë': 'e',
    'íìîï': 'i',
    'óòõôö': 'o',
    'úùûü': 'u',
    'ç': 'c',
  };
  for (final group in groups.entries) {
    for (final rune in group.key.runes) {
      value = value.replaceAll(String.fromCharCode(rune), group.value);
    }
  }
  return value.trim();
}

List<DiscoveryEntry> searchDiscovery(
  Iterable<DiscoveryEntry> entries,
  String query, {
  DiscoveryKind? kind,
}) {
  final words = normalizeDiscoveryText(query).split(RegExp(r'\s+'));
  return entries
      .where((entry) {
        if (kind != null && entry.kind != kind) return false;
        final text = normalizeDiscoveryText(
          '${entry.title} ${entry.subtitle} ${entry.searchContext}',
        );
        return words.every(text.contains);
      })
      .toList(growable: false);
}

List<DiscoveryEntry> prioritizeDiscovery(Iterable<DiscoveryEntry> entries) {
  final unique = {
    for (final entry in entries) '${entry.kind.name}:${entry.id}': entry,
  };
  final result = unique.values.toList();
  result.sort((a, b) {
    final priority = a.priority.compareTo(b.priority);
    if (priority != 0) return priority;
    final date = (a.date ?? DateTime(9999)).compareTo(b.date ?? DateTime(9999));
    return date != 0 ? date : a.title.compareTo(b.title);
  });
  return result;
}

class DiscoverySourceStatus {
  const DiscoverySourceStatus({
    required this.name,
    required this.confirmed,
    required this.checkedAt,
  });
  final String name;
  final bool confirmed;
  final DateTime checkedAt;
}

String discoveryOrigin(String source) => switch (source) {
  'sheet-sync' => 'planilha',
  'statement-import' => 'extrato importado',
  'app' || 'manual' => 'registro no Fôlego',
  _ => 'origem: $source',
};

class DiscoveryData {
  const DiscoveryData({
    this.entries = const [],
    this.pending = const [],
    this.unavailable = const [],
    this.sources = const [],
  });
  final List<DiscoveryEntry> entries;
  final List<DiscoveryEntry> pending;
  final List<String> unavailable;
  final List<DiscoverySourceStatus> sources;
}
