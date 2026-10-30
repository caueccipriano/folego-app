/// The Resolver combines existing read-only queues. The financial event is
/// shown once even if it is simultaneously pending category, behavior and
/// "Outros" review; the most actionable workflow takes priority.
///
/// This does not classify, merge, post or settle any financial record.
const resolverTabIndex = 3;

int resolverTaskPriority(String kind) => switch (kind) {
  'capture' => 0,
  'classification' => 1,
  'other' => 2,
  'behavior' => 3,
  _ => 4,
};

String resolverTaskLabel(String kind) => switch (kind) {
  'capture' => 'comprovante para conferir',
  'classification' => 'categoria para confirmar',
  'other' => 'revisar categoria “Outros”',
  'behavior' => 'identificar gasto fixo ou variável',
  _ => 'conferir lançamento',
};

String resolverTaskAction(String kind) => switch (kind) {
  'capture' => 'conferir comprovante',
  'classification' => 'organizar categoria',
  'other' => 'revisar categoria',
  'behavior' => 'conferir lançamento',
  _ => 'conferir',
};

/// All items must originate from previously space-filtered repository reads.
/// The caller keeps the same RLS, account and user session.
List<Map<String, dynamic>> mergeResolverTasks({
  required Iterable<Map<String, dynamic>> pending,
  required Iterable<Map<String, dynamic>> other,
}) {
  final candidates = <Map<String, dynamic>>[
    for (final row in pending) Map<String, dynamic>.from(row),
    for (final row in other) <String, dynamic>{...row, 'kind': 'other'},
  ];
  candidates.removeWhere((row) =>
    resolverTaskPriority(row['kind']?.toString() ?? '') > 3);
  // Prefer exact queue semantics over chronology. A classification problem
  // must not disappear because the same event also lacks a behavior type.
  candidates.sort((a, b) {
    final aPriority = resolverTaskPriority(a['kind']?.toString() ?? '');
    final bPriority = resolverTaskPriority(b['kind']?.toString() ?? '');
    final byPriority = aPriority.compareTo(bPriority);
    if (byPriority != 0) return byPriority;
    final aDate = DateTime.tryParse(a['occurred_at']?.toString() ?? '') ??
        DateTime(1970);
    final bDate = DateTime.tryParse(b['occurred_at']?.toString() ?? '') ??
        DateTime(1970);
    final byDate = bDate.compareTo(aDate);
    if (byDate != 0) return byDate;
    return (a['id']?.toString() ?? '').compareTo(b['id']?.toString() ?? '');
  });
  final seen = <String>{};
  final tasks = <Map<String, dynamic>>[];
  for (final row in candidates) {
    final kind = row['kind']?.toString() ?? '';
    final id = row['id']?.toString() ?? '';
    if (id.isEmpty) continue;
    // Capture IDs and financial event IDs belong to distinct tables.
    final identity = kind == 'capture' ? 'capture:$id' : 'event:$id';
    if (seen.add(identity)) tasks.add(row);
  }
  return tasks;
}
