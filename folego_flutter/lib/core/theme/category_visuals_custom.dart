import 'package:flutter/material.dart';

import 'category_icon_catalog.dart';
import 'category_visuals_v3.dart' as legacy;

typedef CategoryVisualData = legacy.CategoryVisualData;

/// Public category visual facade.
///
/// System and legacy categories keep the established resolver. User-managed
/// categories can opt into a stable persisted [iconKey] from the curated
/// [CategoryIconCatalog].
abstract final class CategoryVisuals {
  static CategoryVisualData resolve({
    required Brightness brightness,
    String? category,
    String? subcategory,
    String? eventType,
    String? systemKey,
    String? colorHex,
    String? iconKey,
  }) {
    final base = legacy.CategoryVisuals.resolve(
      brightness: brightness,
      category: category,
      subcategory: subcategory,
      eventType: eventType,
      systemKey: systemKey,
      colorHex: colorHex,
    );
    final customIcon = CategoryIconCatalog.tryIconForKey(iconKey);
    if (customIcon == null) return base;
    return CategoryVisualData(icon: customIcon, color: base.color);
  }

  static IconData iconFor({
    String? category,
    String? subcategory,
    String? eventType,
    String? systemKey,
    String? iconKey,
  }) {
    return CategoryIconCatalog.tryIconForKey(iconKey) ??
        legacy.CategoryVisuals.iconFor(
          category: category,
          subcategory: subcategory,
          eventType: eventType,
          systemKey: systemKey,
        );
  }

  static Color colorFor({
    required String category,
    required Brightness brightness,
    String? eventType,
    String? colorHex,
  }) {
    return legacy.CategoryVisuals.colorFor(
      category: category,
      brightness: brightness,
      eventType: eventType,
      colorHex: colorHex,
    );
  }

  static String canonicalCategory(String value) =>
      legacy.CategoryVisuals.canonicalCategory(value);

  static String canonicalSubcategory(String value) =>
      legacy.CategoryVisuals.canonicalSubcategory(value);
}
