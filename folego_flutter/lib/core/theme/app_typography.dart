import 'package:flutter/material.dart';

abstract final class AppTypography {
  // ---------------------------------------------------------------------------
  // DESIGN SYSTEM
  //
  // Unbounded = personalidade e títulos principais.
  // Manrope   = títulos de cards, valores, corpo, labels e navegação.
  // ---------------------------------------------------------------------------

  static TextStyle _font(
    String family, {
    TextStyle? textStyle,
    double? fontSize,
    FontWeight? fontWeight,
    double? height,
    double? letterSpacing,
    Color? color,
    FontStyle? fontStyle,
    List<FontFeature>? fontFeatures,
    TextDecoration? decoration,
  }) => (textStyle ?? const TextStyle()).copyWith(
    fontFamily: family,
    fontSize: fontSize,
    fontWeight: fontWeight,
    height: height,
    letterSpacing: letterSpacing,
    color: color,
    fontStyle: fontStyle,
    fontFeatures: fontFeatures,
    decoration: decoration,
  );
  static TextStyle _interface({
    TextStyle? textStyle,
    double? fontSize,
    FontWeight? fontWeight,
    double? height,
    double? letterSpacing,
    Color? color,
    FontStyle? fontStyle,
    List<FontFeature>? fontFeatures,
    TextDecoration? decoration,
  }) => _font(
    'Manrope',
    textStyle: textStyle,
    fontSize: fontSize,
    fontWeight: fontWeight,
    height: height,
    letterSpacing: letterSpacing,
    color: color,
    fontStyle: fontStyle,
    fontFeatures: fontFeatures,
    decoration: decoration,
  );
  static TextStyle _brand({
    TextStyle? textStyle,
    double? fontSize,
    FontWeight? fontWeight,
    double? height,
    double? letterSpacing,
    Color? color,
  }) => _font(
    'Unbounded',
    textStyle: textStyle,
    fontSize: fontSize,
    fontWeight: fontWeight,
    height: height,
    letterSpacing: letterSpacing,
    color: color,
  );

  static TextTheme textTheme(
    TextTheme base, {
    required Color primaryText,
    required Color secondaryText,
  }) {
    final manrope = base
        .apply(fontFamily: 'Manrope')
        .apply(bodyColor: primaryText, displayColor: primaryText);

    return manrope.copyWith(
      displayLarge: _brand(
        textStyle: manrope.displayLarge,
        fontSize: 44,
        fontWeight: FontWeight.w700,
        height: 1.02,
        letterSpacing: -1.2,
        color: primaryText,
      ),
      displayMedium: _brand(
        textStyle: manrope.displayMedium,
        fontSize: 38,
        fontWeight: FontWeight.w700,
        height: 1.04,
        letterSpacing: -1.0,
        color: primaryText,
      ),
      displaySmall: _brand(
        textStyle: manrope.displaySmall,
        fontSize: 34,
        fontWeight: FontWeight.w700,
        height: 1.05,
        letterSpacing: -.8,
        color: primaryText,
      ),
      headlineLarge: _brand(
        textStyle: manrope.headlineLarge,
        fontSize: 26,
        fontWeight: FontWeight.w700,
        height: 1.08,
        letterSpacing: -.5,
        color: primaryText,
      ),
      headlineMedium: _brand(
        textStyle: manrope.headlineMedium,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.10,
        letterSpacing: -.4,
        color: primaryText,
      ),
      headlineSmall: _brand(
        textStyle: manrope.headlineSmall,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        height: 1.12,
        letterSpacing: -.25,
        color: primaryText,
      ),
      titleLarge: _interface(
        textStyle: manrope.titleLarge,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        height: 1.25,
        letterSpacing: 0,
        color: primaryText,
      ),
      titleMedium: _interface(
        textStyle: manrope.titleMedium,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.25,
        color: primaryText,
      ),
      titleSmall: _interface(
        textStyle: manrope.titleSmall,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.25,
        color: primaryText,
      ),
      bodyLarge: _interface(
        textStyle: manrope.bodyLarge,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: primaryText,
      ),
      bodyMedium: _interface(
        textStyle: manrope.bodyMedium,
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: primaryText,
      ),
      bodySmall: _interface(
        textStyle: manrope.bodySmall,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.40,
        color: secondaryText,
      ),
      labelLarge: _interface(
        textStyle: manrope.labelLarge,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.20,
        color: primaryText,
      ),
      labelMedium: _interface(
        textStyle: manrope.labelMedium,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.20,
        color: secondaryText,
      ),
      labelSmall: _interface(
        textStyle: manrope.labelSmall,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 1.20,
        color: secondaryText,
      ),
    );
  }

  static TextStyle display(
    BuildContext context, {
    double fontSize = 40,
    Color? color,
  }) {
    return _brand(
      textStyle: Theme.of(context).textTheme.displayLarge,
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      height: 1.02,
      letterSpacing: -1.0,
      color: color,
    );
  }

  static TextStyle section(
    BuildContext context, {
    double fontSize = 18,
    Color? color,
  }) {
    return _brand(
      textStyle: Theme.of(context).textTheme.titleLarge,
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      height: 1.10,
      letterSpacing: -.25,
      color: color,
    );
  }

  /// Titles inside cards use Manrope; keep Unbounded for page/editorial
  /// headings. This prevents display lettering from overpowering compact cards.
  static TextStyle cardTitle(
    BuildContext context, {
    double fontSize = 16,
    Color? color,
  }) => _interface(
    textStyle: Theme.of(context).textTheme.titleMedium,
    fontSize: fontSize,
    fontWeight: FontWeight.w700,
    height: 1.22,
    letterSpacing: -.25,
    color: color,
  );

  /// One numeric face at every size keeps amounts comparable across cards.
  static TextStyle money(
    BuildContext context, {
    double fontSize = 52,
    Color? color,
  }) {
    final effectiveSize = fontSize < 13 ? 13.0 : fontSize;
    final isHero = effectiveSize >= 28;
    final isMetric = effectiveSize >= 20;
    return _interface(
      textStyle: Theme.of(context).textTheme.bodyMedium,
      fontSize: effectiveSize,
      fontWeight: isMetric ? FontWeight.w800 : FontWeight.w700,
      // Compact amounts retain the existing >=1.20 reading-height contract.
      height: isHero ? 1.08 : (isMetric ? 1.17 : 1.20),
      letterSpacing: isHero ? -1.0 : (isMetric ? -.4 : 0),
      fontFeatures: const [
        FontFeature.tabularFigures(),
        FontFeature.liningFigures(),
      ],
      decoration: TextDecoration.none,
      color: color,
    );
  }

  static TextStyle body(
    BuildContext context, {
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    FontStyle? fontStyle,
    Color? color,
  }) {
    final effectiveFontSize = fontSize < 11 ? 11.0 : fontSize;
    return _interface(
      textStyle: Theme.of(context).textTheme.bodyMedium,
      fontSize: effectiveFontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      height: 1.45,
      color: color,
    );
  }

  static TextStyle label(
    BuildContext context, {
    double fontSize = 11,
    FontWeight fontWeight = FontWeight.w500,
    Color? color,
  }) {
    final effectiveFontSize = fontSize < 11 ? 11.0 : fontSize;
    return _interface(
      textStyle: Theme.of(context).textTheme.labelMedium,
      fontSize: effectiveFontSize,
      fontWeight: fontWeight,
      height: 1.20,
      color: color,
    );
  }

  static TextStyle button(
    BuildContext context, {
    double fontSize = 13,
    Color? color,
  }) {
    return _interface(
      textStyle: Theme.of(context).textTheme.labelLarge,
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      height: 1.20,
      color: color,
    );
  }
}
