import 'package:flutter/widgets.dart';

enum AppLayoutSize {
  compact,
  medium,
  expanded,
  wide,
}

/// Fonte única de verdade para os breakpoints estruturais do Fôlego.
///
/// O layout responde à largura disponível, independentemente de plataforma.
abstract final class AppBreakpoints {
  /// Faixa compact começa em 0 e vai até antes de [medium].
  static const double compact = 0;

  /// Medium: 600–1023 px.
  static const double medium = 600;

  /// Expanded: 1024–1439 px.
  static const double expanded = 1024;

  /// Wide: 1440 px ou mais.
  static const double wide = 1440;

  static AppLayoutSize fromWidth(double width) {
    if (width < medium) {
      return AppLayoutSize.compact;
    }

    if (width < expanded) {
      return AppLayoutSize.medium;
    }

    if (width < wide) {
      return AppLayoutSize.expanded;
    }

    return AppLayoutSize.wide;
  }

  static AppLayoutSize of(BuildContext context) {
    return fromWidth(MediaQuery.sizeOf(context).width);
  }
}

/// Espaçamento estrutural de página.
abstract final class AppResponsiveSpacing {
  static const double compactHorizontal = 16;
  static const double mediumHorizontal = 24;
  static const double expandedHorizontal = 32;
  static const double wideHorizontal = 32;

  static double horizontalForWidth(double width) {
    switch (AppBreakpoints.fromWidth(width)) {
      case AppLayoutSize.compact:
        return compactHorizontal;
      case AppLayoutSize.medium:
        return mediumHorizontal;
      case AppLayoutSize.expanded:
        return expandedHorizontal;
      case AppLayoutSize.wide:
        return wideHorizontal;
    }
  }

  static double horizontal(BuildContext context) {
    return horizontalForWidth(MediaQuery.sizeOf(context).width);
  }
}

/// Limites de conteúdo por natureza de tela.
///
/// Estes valores não são impostos globalmente pelo Shell. Cada tela escolhe
/// explicitamente o limite que faz sentido para seu conteúdo.
abstract final class AppContentWidths {
  static const double auth = 520;
  static const double form = 640;
  static const double list = 900;
  static const double dashboard = 1200;
}
