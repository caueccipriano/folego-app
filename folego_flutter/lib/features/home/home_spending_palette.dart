import 'package:flutter/material.dart';
import '../../core/theme/app_color_tokens.dart';

/// Paleta exclusiva do gráfico de gastos da Home.
///
/// Não altera a taxonomia nem as cores canônicas das categorias em outras
/// superfícies. A escolha é determinística para que a mesma categoria mantenha
/// identidade visual entre rebuilds e sessões.
abstract final class HomeSpendingPalette {
  static const List<Color> colors = <Color>[
    FolegoLegacyColors.hexFF8A6CF0, // purple
    FolegoLegacyColors.hexFFC6F135, // lime
    FolegoLegacyColors.hexFF35D6FF, // electric cyan
    FolegoLegacyColors.hexFFFF6B7A, // coral
    FolegoLegacyColors.hexFFFF69C9, // hot pink
    FolegoLegacyColors.hexFFFF9F43, // tangerine
    FolegoLegacyColors.hexFF45E0B7, // mint
    FolegoLegacyColors.hexFFB78CFF, // lavender
  ];

  static const Color otherLight = FolegoLegacyColors.hexFF8B8A94;
  static const Color otherDark = FolegoLegacyColors.hexFFA8A7B2;

  static Color colorFor({
    required String category,
    required Brightness brightness,
    String? categoryId,
    bool isOther = false,
  }) {
    if (isOther) {
      return brightness == Brightness.dark ? otherDark : otherLight;
    }

    final id = categoryId?.trim();
    final seed = id != null && id.isNotEmpty
        ? 'id:$id'
        : 'label:${category.trim().toLowerCase()}';
    return colors[_stableIndex(seed, colors.length)];
  }

  static int _stableIndex(String value, int length) {
    // FNV-1a de 32 bits implementado localmente para não depender de hashCode,
    // cuja estabilidade entre runtimes não faz parte do contrato visual.
    var hash = 0x811C9DC5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return (hash & 0x7FFFFFFF) % length;
  }
}
