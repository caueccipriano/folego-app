import 'package:flutter/material.dart';

import '../../core/theme/category_chart_palette.dart';
import '../../data/models/home_expense_summary.dart';

/// All visible Home chart segments are assigned together, so two categories
/// do not accidentally receive an identical or near-identical swatch.
/// The same category-to-color mapping drives the ring and its legend.
abstract final class HomeSpendingPalette {
  static const List<Color> colors = CategoryChartPalette.light;
  static const Color otherLight = CategoryChartPalette.otherLight;
  static const Color otherDark = CategoryChartPalette.otherDark;

  static Color colorFor({
    required String category,
    required Brightness brightness,
    String? categoryId,
    bool isOther = false,
  }) => CategoryChartPalette.colorFor(
    category: category,
    brightness: brightness,
    categoryId: categoryId,
    isOther: isOther,
  );

  static List<Color> colorsFor(
    List<HomeCategoryExpense> categories,
    Brightness brightness,
  ) => CategoryChartPalette.colorsFor(
    categories
        .map(
          (category) => CategoryChartEntry(
            name: category.category,
            categoryId: category.categoryId,
            isOther: category.isOther,
          ),
        )
        .toList(growable: false),
    brightness: brightness,
  );
}
