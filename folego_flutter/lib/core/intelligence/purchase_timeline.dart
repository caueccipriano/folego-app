import '../../data/models/projection_model.dart';

/// A read-only, month-aligned view of TWO responses from the official engine.
/// Never infers future transactions, never calls a provider or spends quota.
class PurchaseTimelineMonth {
  const PurchaseTimelineMonth({
    required this.month,
    required this.baselineBalance,
    required this.purchaseBalance,
  });

  final DateTime month;
  final double baselineBalance;
  final double purchaseBalance;
  double get difference => purchaseBalance - baselineBalance;
  bool get isNegative => purchaseBalance < 0;
}

List<PurchaseTimelineMonth> purchaseTimeline(
  ProjectionResult baseline,
  ProjectionResult withPurchase,
) {
  final scenarios = <String, ProjectionMonth>{};
  String key(DateTime d) => '${d.year}-${d.month}';
  for (final month in withPurchase.months) {
    scenarios.putIfAbsent(key(month.month), () => month);
  }
  final visited = <String>{};
  final timeline = <PurchaseTimelineMonth>[];
  for (final original in baseline.months) {
    final id = key(original.month);
    if (!visited.add(id)) continue;
    final changed = scenarios[id];
    if (changed == null) continue; // Do not invent months absent in either run.
    if (!original.closingProjected.isFinite || !changed.closingProjected.isFinite) {
      continue;
    }
    timeline.add(PurchaseTimelineMonth(
      month: DateTime(original.month.year, original.month.month),
      baselineBalance: original.closingProjected,
      purchaseBalance: changed.closingProjected,
    ));
  }
  return List.unmodifiable(timeline);
}
