import 'package:flutter/material.dart';

abstract final class AppTypography {
  /// Fonte de personalidade do Fôlego.
  /// Quando o arquivo Cooper BT for adicionado aos assets,
  /// este nome passará a usar a fonte real.
  static const displayFont = 'CooperBT';

  static TextStyle display(
    BuildContext context, {
    double fontSize = 32,
    Color? color,
  }) {
    return Theme.of(context).textTheme.headlineLarge!.copyWith(
          fontFamily: displayFont,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          height: 1.05,
          letterSpacing: -0.8,
          color: color,
        );
  }

  static TextStyle section(
    BuildContext context, {
    double fontSize = 24,
    Color? color,
  }) {
    return Theme.of(context).textTheme.titleLarge!.copyWith(
          fontFamily: displayFont,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          height: 1.1,
          letterSpacing: -0.4,
          color: color,
        );
  }

  static TextStyle money(
    BuildContext context, {
    double fontSize = 52,
    Color? color,
  }) {
    return Theme.of(context).textTheme.displayLarge!.copyWith(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          height: .95,
          letterSpacing: -2,
          color: color,
        );
  }
}