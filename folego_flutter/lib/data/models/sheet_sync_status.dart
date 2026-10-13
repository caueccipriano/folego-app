/// Read-only operational timestamps from the sheet-sync integration.
///
/// push: the sheet submitted rows to the Fôlego API. A recorded push does
/// not certify that every row succeeded.
/// pull: the sheet fetched rows from the Fôlego API. A recorded pull does
/// not certify that the sheet applied every row.
final class SheetSyncStatus {
  const SheetSyncStatus({
    required this.configured,
    required this.enabled,
    this.lastPushAt,
    this.lastPullAt,
  });

  final bool configured;
  final bool enabled;
  final DateTime? lastPushAt;
  final DateTime? lastPullAt;

  factory SheetSyncStatus.fromJson(Map<String, dynamic> json) {
    DateTime? asDate(dynamic value) {
      if (value is! String || value.isEmpty) return null;
      return DateTime.tryParse(value)?.toLocal();
    }

    return SheetSyncStatus(
      configured: json['configured'] == true,
      enabled: json['enabled'] == true,
      lastPushAt: asDate(json['last_push_at']),
      lastPullAt: asDate(json['last_pull_at']),
    );
  }

  String get headline {
    if (!configured) return 'Planilha não conectada';
    if (!enabled) return 'Integração desativada';
    if (lastPushAt == null && lastPullAt == null) {
      return 'Integração habilitada · sem histórico de comunicação';
    }
    return 'Integração habilitada';
  }
}
