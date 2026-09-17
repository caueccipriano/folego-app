import 'package:flutter/material.dart';

import 'app_breakpoints.dart';

/// Respiro reservado entre conteúdo rolável e a scrollbar automática desktop.
///
/// O gutter é estrutural: [AppScrollBehavior] mantém o viewport rolável 22 px
/// afastado da scrollbar, sem alterar larguras de cards individualmente.
abstract final class AppScrollGutter {
  static const double desktop = 22;

  static double horizontal(BuildContext context) {
    final layout = AppBreakpoints.of(context);
    return layout == AppLayoutSize.expanded || layout == AppLayoutSize.wide
        ? desktop
        : 0;
  }

  /// Mantido para telas que já usam este helper para top/bottom padding.
  ///
  /// O espaço lateral da scrollbar é aplicado por [AppScrollBehavior], por isso
  /// não é duplicado aqui.
  static EdgeInsets padding(
    BuildContext context, {
    double top = 0,
    double bottom = 0,
  }) {
    return EdgeInsets.only(top: top, bottom: bottom);
  }
}

/// Scroll behavior oficial do app para desktop.
///
/// Flutter desenha a scrollbar automática por cima do viewport. Aqui o
/// scrollbar continua no extremo direito, enquanto o Scrollable recebe um
/// trailing inset físico de 22 px. Scrolls horizontais e plataformas móveis
/// preservam o comportamento padrão.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    if (axisDirectionToAxis(details.direction) == Axis.horizontal) {
      return child;
    }

    switch (getPlatform(context)) {
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return Scrollbar(
          controller: details.controller,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(
              end: AppScrollGutter.desktop,
            ),
            child: child,
          ),
        );
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.iOS:
        return child;
    }
  }
}
