import 'package:flutter/material.dart';

import '../../core/theme/app_color_tokens.dart';

/// Lightweight glass-style surface for Flutter Web/PWA and mobile.
/// Uses a translucent, palette-aware gradient instead of BackdropFilter.
/// A real blur on the bottom navigation previously caused hit-testing issues
/// in iOS PWAs; keep this decoration layer geometry-neutral.
class FolegoGlassSurface extends StatelessWidget {
  const FolegoGlassSurface({
    super.key,
    required this.child,
    this.radius = 22,
    this.padding = EdgeInsets.zero,
    this.elevated = true,
    this.prominent = false,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final bool elevated;
  /// More visible, palette-aware glass for the floating dock and tool drawer.
  final bool prominent;

  static BoxDecoration decorationFor(
    BuildContext context, {
    double radius = 22,
    bool elevated = true,
    bool prominent = false,
  }) {
    final tokens = FolegoColorTokens.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final highContrast = MediaQuery.highContrastOf(context);
    final edge = Color.alphaBlend(
      tokens.superficie.withValues(alpha: isDark ? .20 : .82),
      tokens.borda.withValues(alpha: isDark ? .70 : .82),
    );

    if (highContrast) {
      return BoxDecoration(
        color: tokens.superficie,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: tokens.borda, width: 1.2),
      );
    }

    final translucent = Color.alphaBlend(
      tokens.marca.withValues(alpha: isDark ? .055 : .025),
      tokens.superficie.withValues(alpha: isDark ? .87 : .82),
    );

    // The previous gradient differed from the background by only a few
    // percent. The prominent variant uses a deliberately visible tint and
    // sheen; no BackdropFilter/compositing layer is added over iOS PWA taps.
    final tinted = Color.alphaBlend(
      tokens.marca.withValues(alpha: isDark ? .23 : .14),
      tokens.superficie.withValues(alpha: isDark ? .93 : .94),
    );
    final strongEdge = Color.alphaBlend(
      tokens.marca.withValues(alpha: isDark ? .42 : .27),
      tokens.borda,
    );

    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: prominent
          ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.alphaBlend(
                  tokens.textoPrincipal.withValues(
                    alpha: isDark ? .21 : .025,
                  ),
                  tinted,
                ),
                Color.alphaBlend(
                  tokens.superficie.withValues(alpha: isDark ? .14 : .65),
                  tinted,
                ),
                tinted,
                Color.alphaBlend(
                  tokens.marca.withValues(alpha: isDark ? .25 : .13),
                  tinted,
                ),
              ],
              stops: const [0, .25, .67, 1],
            )
          : LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.alphaBlend(
                  (isDark ? tokens.textoPrincipal : tokens.superficie)
                      .withValues(alpha: isDark ? .105 : .19),
                  translucent,
                ),
                translucent,
                Color.alphaBlend(
                  tokens.superficieAlta.withValues(alpha: isDark ? .18 : .24),
                  translucent,
                ),
              ],
              stops: const [0, .50, 1],
            ),
      border: Border.all(color: prominent ? strongEdge : edge,
          width: prominent ? 1.35 : 1),
      boxShadow: elevated
          ? [
              BoxShadow(
                color: (isDark ? tokens.fundo : tokens.textoPrincipal)
                    .withValues(alpha: prominent
                        ? (isDark ? .40 : .17)
                        : (isDark ? .23 : .09)),
                blurRadius: prominent ? 29 : 24,
                offset: Offset(0, prominent ? 11 : 9),
              ),
              BoxShadow(
                color: tokens.marca.withValues(
                  alpha: prominent ? (isDark ? .21 : .14)
                      : (isDark ? .10 : .055),
                ),
                blurRadius: prominent ? 19 : 12,
                offset: const Offset(0, 2),
              ),
            ]
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: decorationFor(context,
        radius: radius, elevated: elevated, prominent: prominent),
      padding: padding,
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}
