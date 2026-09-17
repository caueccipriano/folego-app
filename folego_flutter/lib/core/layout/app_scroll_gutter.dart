import 'package:flutter/widgets.dart';

import 'app_breakpoints.dart';

/// Respiro interno reservado entre o conteúdo rolável e a scrollbar desktop.
///
/// O inset é aplicado dentro do próprio ScrollView (não no card), mantendo a
/// scrollbar fora da área útil de textos, botões, gráficos e bordas.
abstract final class AppScrollGutter {
  static const double desktop = 22;

  static double horizontal(BuildContext context) {
    final layout = AppBreakpoints.of(context);
    return layout == AppLayoutSize.expanded || layout == AppLayoutSize.wide
        ? desktop
        : 0;
  }

  static EdgeInsets padding(
    BuildContext context, {
    double top = 0,
    double bottom = 0,
  }) {
    final horizontal = AppScrollGutter.horizontal(context);
    return EdgeInsets.fromLTRB(horizontal, top, horizontal, bottom);
  }
}
