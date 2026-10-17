import 'recurring_item.dart';

class SubscriptionCharge {
  const SubscriptionCharge({required this.id, required this.recurringId,
    required this.date, required this.amount});
  final String id, recurringId;
  final DateTime date;
  final double amount;
  factory SubscriptionCharge.fromJson(Map<String, dynamic> row) => SubscriptionCharge(
    id: row['id'] as String,
    recurringId: row['recurring_item_id'] as String,
    date: DateTime.parse(row['due_date'] as String),
    amount: (row['actual_amount'] as num).toDouble(),
  );
}

class SubscriptionInsight {
  const SubscriptionInsight(this.item, this.message);
  final RecurringItem item;
  final String message;
}

String _normalized(String value) => value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// Strict identity and payment instrument matching. Alerts never cancel or merge.
List<SubscriptionInsight> duplicateSubscriptionInsights(List<RecurringItem> items) {
  final groups = <String, List<RecurringItem>>{};
  for (final item in items) {
    if (!item.active || !item.isExpense || item.name.trim().length < 4 ||
        (item.cardId == null && item.accountId == null)) { continue; }
    final key = '${item.spaceId}|${_normalized(item.name)}|${item.cardId}|${item.accountId}|${item.frequency}';
    groups.putIfAbsent(key, () => []).add(item);
  }
  return [for (final group in groups.values)
    if (group.length > 1) SubscriptionInsight(group.first,
      '${group.length} cadastros ativos com mesmo nome, frequência e meio de pagamento. Podem ser planos diferentes; confira antes de encerrar qualquer um.'),
  ];
}

/// Requires two realized, distinct billing cycles. Does not infer from labels.
List<SubscriptionInsight> changedSubscriptionInsights(
  List<RecurringItem> items, List<SubscriptionCharge> charges,
) {
  final result = <SubscriptionInsight>[];
  for (final item in items.where((item) => item.active && item.isExpense)) {
    final seen = <String>{};
    final history = charges.where((charge) => charge.recurringId == item.id &&
      charge.amount.isFinite && charge.amount > 0 && seen.add(charge.id)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    if (history.length < 2) { continue; }
    final latest = history.first;
    final previous = history.where((charge) => charge.date.isBefore(latest.date)).firstOrNull;
    if (previous == null) { continue; }
    final oldCents = (previous.amount * 100).round();
    final newCents = (latest.amount * 100).round();
    if (newCents == oldCents) { continue; }
    // Monetary formatting is done by the UI so privacy changes are reactive.
    result.add(SubscriptionInsight(item,
      '${newCents > oldCents ? 'aumento' : 'redução'} entre as duas últimas cobranças realizadas. Confira os valores abaixo; pode ser reajuste, desconto ou mudança do plano.'));
  }
  return result;
}
