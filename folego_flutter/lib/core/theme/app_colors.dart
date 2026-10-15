import 'package:flutter/material.dart';
import 'app_color_tokens.dart';

abstract final class AppColors {
  static const transparent = FolegoLegacyColors.transparent;
  // ---------------------------------------------------------------------------
  // BRAND
  // ---------------------------------------------------------------------------

  static const purpleLight = FolegoLegacyColors.hexFF6C3CE9;
  static const purpleDark = FolegoLegacyColors.hexFF967CF4;

  static const lime = FolegoLegacyColors.hexFFC6F135;

  // ---------------------------------------------------------------------------
  // LIGHT MODE
  // ---------------------------------------------------------------------------

  static const lightBackground = FolegoLegacyColors.hexFFF5F1E8;
  static const lightSurface = FolegoLegacyColors.hexFFFFFFFF;
  static const lightBorder = FolegoLegacyColors.hexFFE4DFD2;

  static const lightPrimaryText = FolegoLegacyColors.hexFF16150F;
  static const lightSecondaryText = FolegoLegacyColors.hexFF6B6656;

  // ---------------------------------------------------------------------------
  // DARK MODE
  // ---------------------------------------------------------------------------

  static const darkBackground = FolegoLegacyColors.hexFF101014;
  static const darkSurface = FolegoLegacyColors.hexFF1D1D24;
  static const darkBorder = FolegoLegacyColors.hexFF2E2E38;

  static const darkPrimaryText = FolegoLegacyColors.hexFFF0EFEA;
  static const darkSecondaryText = FolegoLegacyColors.hexFF9B98A8;

  // ---------------------------------------------------------------------------
  // SEMANTIC — INCOME / POSITIVE
  // ---------------------------------------------------------------------------

  static const lightPositiveText = FolegoLegacyColors.hexFF3B6D11;
  static const lightPositiveBackground = FolegoLegacyColors.hexFFEAF3DE;

  static const darkPositiveText = FolegoLegacyColors.hexFFA9DB6B;
  static const darkPositiveBackground = darkSurface;

  // ---------------------------------------------------------------------------
  // SEMANTIC — EXPENSE / ALERT
  // ---------------------------------------------------------------------------

  static const lightExpenseText = FolegoLegacyColors.hexFF712B13;
  static const lightExpenseBackground = FolegoLegacyColors.hexFFFAECE7;

  static const darkExpenseText = FolegoLegacyColors.hexFFF0A98A;
  static const darkExpenseBackground = darkSurface;

  // ---------------------------------------------------------------------------
  // CATEGORY COLORS
  // ---------------------------------------------------------------------------

  static const foodLight = FolegoLegacyColors.hexFF6C3CE9;
  static const foodDark = FolegoLegacyColors.hexFFB39CF5;

  static const homeLight = FolegoLegacyColors.hexFFD4457A;
  static const homeDark = FolegoLegacyColors.hexFFF096B8;

  static const transportLight = FolegoLegacyColors.hexFF3B6D11;
  static const transportDark = FolegoLegacyColors.hexFFA9DB6B;

  static const healthLight = FolegoLegacyColors.hexFF993C1D;
  static const healthDark = FolegoLegacyColors.hexFFE8A87C;

  // ---------------------------------------------------------------------------
  // REFLECTION TAGS
  // ---------------------------------------------------------------------------

  static const desireLightBackground = FolegoLegacyColors.hexFFFBEAF0;
  static const desireLightText = FolegoLegacyColors.hexFF993556;

  static const desireDarkBackground = FolegoLegacyColors.hexFF3A2530;
  static const desireDarkText = FolegoLegacyColors.hexFFF096B8;

  static const necessaryLightBackground = FolegoLegacyColors.hexFFEAF3DE;
  static const necessaryLightText = FolegoLegacyColors.hexFF3B6D11;

  static const necessaryDarkBackground = FolegoLegacyColors.hexFF22301A;
  static const necessaryDarkText = FolegoLegacyColors.hexFFA9DB6B;

  // ---------------------------------------------------------------------------
  // ICONS
  // ---------------------------------------------------------------------------

  static const lightNeutralIcon = lightSecondaryText;
  static const darkNeutralIcon = darkSecondaryText;

  static const lightActiveIcon = purpleLight;
  static const darkActiveIcon = purpleDark;

  static const iconOnLime = darkBackground;
  static const iconOnPurpleLight = FolegoLegacyColors.hexFFFFFFFF;
  static const iconOnPurpleDark = darkPrimaryText;

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  static Color action(Brightness brightness) =>
      FolegoColorTokens.fromId(AppColorSelection.selected.value, brightness).acao;

  static Color onAction(Brightness brightness) =>
      FolegoColorTokens.fromId(AppColorSelection.selected.value, brightness).acaoSobre;

  static Color onBrand(Brightness brightness) =>
      FolegoColorTokens.fromId(AppColorSelection.selected.value, brightness).marcaSobre;

  static Color primaryPurple(Brightness brightness) {
    return FolegoColorTokens.fromId(AppColorSelection.selected.value, brightness).marca;
  }

  static Color background(Brightness brightness) {
    return FolegoColorTokens.fromId(AppColorSelection.selected.value, brightness).fundo;
  }

  static Color surface(Brightness brightness) {
    return FolegoColorTokens.fromId(AppColorSelection.selected.value, brightness).superficie;
  }

  static Color border(Brightness brightness) {
    return FolegoColorTokens.fromId(AppColorSelection.selected.value, brightness).borda;
  }

  static Color primaryText(Brightness brightness) {
    return FolegoColorTokens.fromId(AppColorSelection.selected.value, brightness).textoPrincipal;
  }

  static Color secondaryText(Brightness brightness) {
    return FolegoColorTokens.fromId(AppColorSelection.selected.value, brightness).textoSecundario;
  }

  static Color positiveText(Brightness brightness) {
    return FolegoColorTokens.fromId(AppColorSelection.selected.value, brightness).folga;
  }

  /// Attention states intentionally use the existing Fôlego purple language.
  static Color warningText(Brightness brightness) {
    return FolegoColorTokens.fromId(AppColorSelection.selected.value, brightness).apertado;
  }

  static Color expenseText(Brightness brightness) {
    return FolegoColorTokens.fromId(AppColorSelection.selected.value, brightness).estourado;
  }
}
