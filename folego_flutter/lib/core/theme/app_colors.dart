import 'package:flutter/material.dart';

abstract final class AppColors {
  // ---------------------------------------------------------------------------
  // BRAND
  // ---------------------------------------------------------------------------

  static const purpleLight = Color(0xFF6C3CE9);
  static const purpleDark = Color(0xFF8A6CF0);

  static const lime = Color(0xFFC6F135);

  // ---------------------------------------------------------------------------
  // LIGHT MODE
  // ---------------------------------------------------------------------------

  static const lightBackground = Color(0xFFF5F1E8);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightBorder = Color(0xFFE4DFD2);

  static const lightPrimaryText = Color(0xFF16150F);
  static const lightSecondaryText = Color(0xFF6B6656);

  // ---------------------------------------------------------------------------
  // DARK MODE
  // ---------------------------------------------------------------------------

  static const darkBackground = Color(0xFF101014);
  static const darkSurface = Color(0xFF1D1D24);
  static const darkBorder = Color(0xFF2E2E38);

  static const darkPrimaryText = Color(0xFFF0EFEA);
  static const darkSecondaryText = Color(0xFF9B98A8);

  // ---------------------------------------------------------------------------
  // SEMANTIC — INCOME / POSITIVE
  // ---------------------------------------------------------------------------

  static const lightPositiveText = Color(0xFF3B6D11);
  static const lightPositiveBackground = Color(0xFFEAF3DE);

  static const darkPositiveText = Color(0xFFA9DB6B);
  static const darkPositiveBackground = darkSurface;

  // ---------------------------------------------------------------------------
  // SEMANTIC — EXPENSE / ALERT
  // ---------------------------------------------------------------------------

  static const lightExpenseText = Color(0xFF712B13);
  static const lightExpenseBackground = Color(0xFFFAECE7);

  static const darkExpenseText = Color(0xFFF0A98A);
  static const darkExpenseBackground = darkSurface;

  // ---------------------------------------------------------------------------
  // CATEGORY COLORS
  // ---------------------------------------------------------------------------

  static const foodLight = Color(0xFF6C3CE9);
  static const foodDark = Color(0xFFB39CF5);

  static const homeLight = Color(0xFFD4457A);
  static const homeDark = Color(0xFFF096B8);

  static const transportLight = Color(0xFF3B6D11);
  static const transportDark = Color(0xFFA9DB6B);

  static const healthLight = Color(0xFF993C1D);
  static const healthDark = Color(0xFFE8A87C);

  // ---------------------------------------------------------------------------
  // REFLECTION TAGS
  // ---------------------------------------------------------------------------

  static const desireLightBackground = Color(0xFFFBEAF0);
  static const desireLightText = Color(0xFF993556);

  static const desireDarkBackground = Color(0xFF3A2530);
  static const desireDarkText = Color(0xFFF096B8);

  static const necessaryLightBackground = Color(0xFFEAF3DE);
  static const necessaryLightText = Color(0xFF3B6D11);

  static const necessaryDarkBackground = Color(0xFF22301A);
  static const necessaryDarkText = Color(0xFFA9DB6B);

  // ---------------------------------------------------------------------------
  // ICONS
  // ---------------------------------------------------------------------------

  static const lightNeutralIcon = lightSecondaryText;
  static const darkNeutralIcon = darkSecondaryText;

  static const lightActiveIcon = purpleLight;
  static const darkActiveIcon = purpleDark;

  static const iconOnLime = darkBackground;
  static const iconOnPurpleLight = Color(0xFFFFFFFF);
  static const iconOnPurpleDark = darkPrimaryText;

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  static Color primaryPurple(Brightness brightness) {
    return brightness == Brightness.dark ? purpleDark : purpleLight;
  }

  static Color background(Brightness brightness) {
    return brightness == Brightness.dark ? darkBackground : lightBackground;
  }

  static Color surface(Brightness brightness) {
    return brightness == Brightness.dark ? darkSurface : lightSurface;
  }

  static Color border(Brightness brightness) {
    return brightness == Brightness.dark ? darkBorder : lightBorder;
  }

  static Color primaryText(Brightness brightness) {
    return brightness == Brightness.dark ? darkPrimaryText : lightPrimaryText;
  }

  static Color secondaryText(Brightness brightness) {
    return brightness == Brightness.dark
        ? darkSecondaryText
        : lightSecondaryText;
  }

  static Color positiveText(Brightness brightness) {
    return brightness == Brightness.dark ? darkPositiveText : lightPositiveText;
  }

  static Color expenseText(Brightness brightness) {
    return brightness == Brightness.dark ? darkExpenseText : lightExpenseText;
  }
}
