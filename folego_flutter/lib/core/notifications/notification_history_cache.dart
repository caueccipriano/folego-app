import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'notification_models.dart';

class NotificationHistoryCache {
  NotificationHistoryCache({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  String _key(String spaceId) => 'folego.notification_history.$spaceId';

  Future<void> save(
    String spaceId,
    List<NotificationHistoryItem> items,
  ) async {
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

    await _preferences.setString(_key(spaceId), jsonEncode(payload));
  }

  Future<List<NotificationHistoryItem>> load(String spaceId) async {
    final raw = await _preferences.getString(_key(spaceId));
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
