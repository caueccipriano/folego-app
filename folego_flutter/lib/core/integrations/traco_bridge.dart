import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class TracoBridgeCategory {
  const TracoBridgeCategory({required this.id, required this.label, required this.kind});

  final String id;
  final String label;
  final String kind;

  factory TracoBridgeCategory.fromJson(Map<String, dynamic> json) {
    return TracoBridgeCategory(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      kind: json['kind']?.toString() ?? '',
    );
  }
}

class TracoBridgeData {
  const TracoBridgeData({
    required this.updatedAt,
    required this.categories,
    required this.note,
  });

  final String? updatedAt;
  final List<TracoBridgeCategory> categories;
  final String? note;
}

class TracoBridge {
  static const _key = 'folego_bridge_traco_v1';

  static Future<TracoBridgeData?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;

      final rawCategories = decoded['suggestedCategories'];
      final categories = rawCategories is List
          ? rawCategories
              .whereType<Map>()
              .map((item) => TracoBridgeCategory.fromJson(Map<String, dynamic>.from(item)))
              .where((item) => item.id.isNotEmpty && item.label.isNotEmpty)
              .toList(growable: false)
          : const <TracoBridgeCategory>[];

      return TracoBridgeData(
        updatedAt: decoded['updatedAt']?.toString(),
        categories: categories,
        note: decoded['note']?.toString(),
      );
    } catch (_) {
      return null;
    }
  }
}
