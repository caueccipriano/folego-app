import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'notification_models.dart';

class NotificationHistoryCache {
  NotificationHistoryCache({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  // Never share cached financial notification text across different sign-ins.
  // Old space-only cache entries are intentionally not read or migrated.
  String _key(String userId, String spaceId) =>
      'folego.notification_history.user.$userId.space.$spaceId';

  Future<void> save(
    String spaceId,
    List<NotificationHistoryItem> items, {
    required String userId,
  }) async {
    if (userId.trim().isEmpty || spaceId.trim().isEmpty) return;

    final payload = items
        .map(
          (item) => <String, dynamic>{
            'id': item.id,
            'kind': item.kind,
            'title': item.title,
            'body': item.body,
            'route': item.route,
            'delivered_at': item.deliveredAt.toIso8601String(),
          },
        )
        .toList(growable: false);

    await _preferences.setString(_key(userId, spaceId), jsonEncode(payload));
  }

  Future<List<NotificationHistoryItem>> load(
    String spaceId, {
    required String userId,
  }) async {
    if (userId.trim().isEmpty || spaceId.trim().isEmpty) return const [];

    final raw = await _preferences.getString(_key(userId, spaceId));
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];

      return decoded
          .whereType<Map>()
          .map(
            (item) => NotificationHistoryItem.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }
}
