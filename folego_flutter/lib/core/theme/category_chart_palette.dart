import 'package:flutter/material.dart';

/// Semantic identity of one visible chart segment, not a budget definition.
/// A subcategory never receives a second independent budget color here.
class CategoryChartEntry {
  const CategoryChartEntry({
    required this.name,
    this.categoryId,
    this.isOther = false,
  });

  final String name;
  final String? categoryId;
  final bool isOther;
}

/// Shared, high-contrast categorical colors for spending charts.
///
/// Each chart computes its entire palette once: a single hash may produce
/// duplicates, so a chart-wide pass keeps visible categories different.
/// The order of values/slices does not affect the colors returned for
/// the same set of categories, including when spending changes.
abstract final class CategoryChartPalette {
  static const List<Color> light = <Color>[
    Color(0xFF245FCB), // royal blue
    Color(0xFFD16B18), // orange
    Color(0xFF008A7B), // teal
    Color(0xFFBF398E), // fuchsia
    Color(0xFF759510), // lime/olive
    Color(0xFF7351C7), // violet
    Color(0xFFC9413D), // red
    Color(0xFF087FAD), // cyan blue
    Color(0xFFAD7900), // ochre
    Color(0xFF267E48), // green
    Color(0xFFAE4268), // raspberry
    Color(0xFF535EB7), // indigo
    Color(0xFFA05A1F), // copper
    Color(0xFF9C469D), // purple
    Color(0xFF4E858C), // slate teal
    Color(0xFF9C4651), // cranberry
    Color(0xFF3F75AB), // ocean blue
    Color(0xFFC05573), // coral pink
    Color(0xFF77639A), // muted purple
    Color(0xFF647B2A), // olive green
  ];

  static const List<Color> dark = <Color>[
    Color(0xFF83ADFF),
    Color(0xFFFFAE62),
    Color(0xFF54D9BD),
    Color(0xFFFF79CC),
    Color(0xFFCEEF61),
    Color(0xFFBDA4FF),
    Color(0xFFFF8A7F),
    Color(0xFF70D1FF),
    Color(0xFFFFDC72),
    Color(0xFF71DFA0),
    Color(0xFFFF97B2),
    Color(0xFFA5B1FF),
    Color(0xFFFFBF82),
    Color(0xFFE09AE7),
    Color(0xFF88DFE6),
    Color(0xFFF09DA5),
    Color(0xFF8FC4FF),
    Color(0xFFFFA4C9),
    Color(0xFFC7B2E4),
    Color(0xFFBEDB7E),
  ];

  static const Color otherLight = Color(0xFF767C87);
  static const Color otherDark = Color(0xFFB0B6C1);

  static Color colorFor({
    required String category,
    required Brightness brightness,
    String? categoryId,
    bool isOther = false,
  }) {
    if (_isOther(category, isOther)) {
      return brightness == Brightness.dark ? otherDark : otherLight;
    }
    final colors = brightness == Brightness.dark ? dark : light;
    return colors[_preferredSlot(category, categoryId, colors.length)];
  }

  static List<Color> colorsFor(
    List<CategoryChartEntry> entries, {
    required Brightness brightness,
  }) {
    if (entries.isEmpty) return const <Color>[];
    final palette = brightness == Brightness.dark ? dark : light;
    final output = List<Color>.filled(entries.length, otherLight);
    final assignedSlots = <int>{};
    final chosenColors = <Color>[];
    final indices = List<int>.generate(entries.length, (index) => index)
      ..sort((a, b) {
        final left = _normalize(entries[a].name);
        final right = _normalize(entries[b].name);
        final nameOrder = left.compareTo(right);
        if (nameOrder != 0) return nameOrder;
        return (entries[a].categoryId ?? '')
            .compareTo(entries[b].categoryId ?? '');
      });

    for (final index in indices) {
      final entry = entries[index];
      if (_isOther(entry.name, entry.isOther)) {
        output[index] = brightness == Brightness.dark ? otherDark : otherLight;
        continue;
      }

      final preferred = _preferredSlot(
        entry.name,
        entry.categoryId,
        palette.length,
      );
      var chosen = preferred;
      if (assignedSlots.contains(chosen) ||
          (chosenColors.isNotEmpty &&
              _closestDifference(palette[chosen], chosenColors) < .52)) {
        var bestScore = -1.0;
        for (var candidate = 0; candidate < palette.length; candidate++) {
          if (assignedSlots.contains(candidate)) continue;
          final contrast = _closestDifference(palette[candidate], chosenColors);
          // A tiny, deterministic preference keeps identities stable when
          // multiple available shades are equally distinguishable.
          final offset = (candidate - preferred + palette.length) %
              palette.length;
          final score = contrast - (offset * .00001);
          if (score > bestScore) {
            bestScore = score;
            chosen = candidate;
          }
        }
      }

      output[index] = palette[chosen];
      assignedSlots.add(chosen);
      chosenColors.add(palette[chosen]);
    }
    return output;
  }

  static double _closestDifference(Color color, List<Color> used) {
    if (used.isEmpty) return 1.0;
    final base = HSLColor.fromColor(color);
    var closest = double.infinity;
    for (final other in used) {
      final hsl = HSLColor.fromColor(other);
      final rawHue = (base.hue - hsl.hue).abs();
      final hue = (rawHue > 180 ? 360 - rawHue : rawHue) / 180.0;
      final brightness = (base.lightness - hsl.lightness).abs();
      final saturation = (base.saturation - hsl.saturation).abs();
      final difference = hue * .8 + brightness * .6 + saturation * .1;
      if (difference < closest) closest = difference;
    }
    return closest;
  }

  static bool _isOther(String name, bool isOther) {
    final n = _normalize(name);
    return isOther ||
        n == 'outros' ||
        n == 'outros gastos' ||
        n == 'a classificar';
  }

  static int _preferredSlot(String name, String? id, int count) {
    final n = _normalize(name);
    final explicit = switch (n) {
      'alimentacao' => 0,
      'contas da casa' => 1,
      'transporte' => 2,
      'beleza & cuidados' || 'beleza e cuidados' || 'beleza' => 3,
      'moradia' || 'casa' => 4,
      'educacao' => 5,
      'dividas & financiamentos' || 'dividas e emprestimos' || 'dividas' => 6,
      'viagens' => 7,
      'compras' => 8,
      'saude & bem-estar' || 'saude e bem-estar' || 'saude' => 9,
      'presentes & doacoes' || 'presentes' => 10,
      'familia & dependentes' || 'familia' => 11,
      'lazer & entretenimento' || 'lazer' => 12,
      'assinaturas' || 'assinaturas e servicos' => 13,
      'seguros' => 14,
      'financeiro & impostos' || 'financeiro' => 15,
      'vestuario' => 16,
      'pets' => 17,
      _ => -1,
    };
    if (explicit >= 0) return explicit % count;

    // FNV-1a: unlike hashCode, results are stable across sessions and web
    // runtimes. Use the label to preserve a category's identity if its ID
    // changes during import; the ID distinguishes duplicated custom names.
    final seed = n.isEmpty ? (id ?? 'categoria') : n;
    var hash = 0x811C9DC5;
    for (final unit in seed.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return (hash & 0x7FFFFFFF) % count;
  }

  static String _normalize(String value) {
    var text = value.trim().toLowerCase();
    const replacements = <String, String>{
      'á': 'a', 'à': 'a', 'ã': 'a', 'â': 'a', 'ä': 'a',
      'é': 'e', 'ê': 'e', 'è': 'e', 'ë': 'e',
      'í': 'i', 'ì': 'i', 'î': 'i',
      'ó': 'o', 'ô': 'o', 'õ': 'o', 'ò': 'o',
      'ú': 'u', 'ü': 'u', 'ù': 'u',
      'ç': 'c',
    };
    for (final entry in replacements.entries) {
      text = text.replaceAll(entry.key, entry.value);
    }
    return text.replaceAll(RegExp(r'\s+'), ' ');
  }
}
