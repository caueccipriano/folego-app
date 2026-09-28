import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppTypography {
  // ---------------------------------------------------------------------------
  // DESIGN SYSTEM
  //
  // Unbounded = personalidade, títulos importantes e valores.
  // Manrope   = interface, corpo, labels e navegação.
  // ---------------------------------------------------------------------------

  static TextTheme textTheme(
    TextTheme base, {
    required Color primaryText,
    required Color secondaryText,
  }) {
    final manrope = GoogleFonts.manropeTextTheme(
      base,
    ).apply(bodyColor: primaryText, displayColor: primaryText);

    return manrope.copyWith(
      displayLarge: GoogleFonts.unbounded(
        textStyle: manrope.displayLarge,
        fontSize: 44,
        fontWeight: FontWeight.w700,
        height: 1.02,
        letterSpacing: -1.2,
        color: primaryText,
      ),
      displayMedium: GoogleFonts.unbounded(
        textStyle: manrope.displayMedium,
        fontSize: 38,
        fontWeight: FontWeight.w700,
        height: 1.04,
        letterSpacing: -1.0,
        color: primaryText,
      ),
      displaySmall: GoogleFonts.unbounded(
        textStyle: manrope.displaySmall,
        fontSize: 34,
        fontWeight: FontWeight.w700,
        height: 1.05,
        letterSpacing: -.8,
        color: primaryText,
      ),
      headlineLarge: GoogleFonts.unbounded(
        textStyle: manrope.headlineLarge,
        fontSize: 26,
        fontWeight: FontWeight.w700,
        height: 1.08,
        letterSpacing: -.5,
        color: primaryText,
      ),
      headlineMedium: GoogleFonts.unbounded(
        textStyle: manrope.headlineMedium,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.10,
        letterSpacing: -.4,
        color: primaryText,
      ),
      headlineSmall: GoogleFonts.unbounded(
        textStyle: manrope.headlineSmall,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        height: 1.12,
        letterSpacing: -.25,
        color: primaryText,
      ),
      titleLarge: GoogleFonts.unbounded(
        textStyle: manrope.titleLarge,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        height: 1.15,
        letterSpacing: -.2,
        color: primaryText,
      ),
      titleMedium: GoogleFonts.manrope(
        textStyle: manrope.titleMedium,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.25,
        color: primaryText,
      ),
      titleSmall: GoogleFonts.manrope(
        textStyle: manrope.titleSmall,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.25,
        color: primaryText,
      ),
      bodyLarge: GoogleFonts.manrope(
        textStyle: manrope.bodyLarge,
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.48,
        color: primaryText,
      ),
      bodyMedium: GoogleFonts.manrope(
        textStyle: manrope.bodyMedium,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.48,
        color: primaryText,
      ),
      bodySmall: GoogleFonts.manrope(
        textStyle: manrope.bodySmall,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.48,
        color: secondaryText,
      ),
      labelLarge: GoogleFonts.manrope(
        textStyle: manrope.labelLarge,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.20,
        color: primaryText,
      ),
      labelMedium: GoogleFonts.manrope(
        textStyle: manrope.labelMedium,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.28,
        color: secondaryText,
      ),
      labelSmall: GoogleFonts.manrope(
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
    return GoogleFonts.unbounded(
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
    return GoogleFonts.unbounded(
      textStyle: Theme.of(context).textTheme.titleLarge,
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      height: 1.10,
      letterSpacing: -.25,
      color: color,
    );
  }

  static TextStyle money(
    BuildContext context, {
    double fontSize = 52,
    Color? color,
  }) {
    // Unbounded at tiny sizes with aggressive negative tracking produces
    // overlapping glyphs in iOS WebKit (visually like struck-through amounts).
    // Use the UI font for compact currency and reserve display type for KPIs.
    if (fontSize < 20) {
      return GoogleFonts.manrope(
        textStyle: Theme.of(context).textTheme.bodyMedium,
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        height: 1.25,
        letterSpacing: 0,
        fontFeatures: const [FontFeature.tabularFigures()],
        decoration: TextDecoration.none,
        color: color,
      );
    }
    return GoogleFonts.unbounded(
      textStyle: Theme.of(context).textTheme.displayLarge,
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      height: 1.15,
      letterSpacing: fontSize < 30 ? -.3 : -.8,
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
    return GoogleFonts.manrope(
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
    return GoogleFonts.manrope(
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
    return GoogleFonts.manrope(
      textStyle: Theme.of(context).textTheme.labelLarge,
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      height: 1.20,
      color: color,
    );
  }
}
