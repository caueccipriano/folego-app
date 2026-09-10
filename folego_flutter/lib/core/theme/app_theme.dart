import 'package:flutter/material.dart';

/// Design system do Fôlego.
///
/// Direção:
/// - dark grafite como identidade principal
/// - claro em creme
/// - roxo como cor estrutural
/// - verde-lima para destaques financeiros
/// - rosa, verde, laranja e teal para categorias
abstract final class AppPalette {
  // ─────────────────────────────────────────────
  // Brand
  // ─────────────────────────────────────────────

  static const purple = Color(0xFF6C3BF0);
  static const purpleLight = Color(0xFF8B68F6);

  /// Compatibilidade com o código atual.
  static const primary = purple;

  static const lime = Color(0xFFC6F135);
  static const pink = Color(0xFFE15B8F);
  static const green = Color(0xFF75A83B);

  // Cores auxiliares
  static const orange = Color(0xFFE99A52);
  static const teal = Color(0xFF58A8A0);
  static const indigo = Color(0xFF5969C9);

  // ─────────────────────────────────────────────
  // Light
  // ─────────────────────────────────────────────

  static const lightBackground = Color(0xFFF5F1E7);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceMuted = Color(0xFFF0ECE2);

  static const lightText = Color(0xFF111114);
  static const lightTextSecondary = Color(0xFF77747C);

  static const lightBorder = Color(0xFFE1DDD4);

  // ─────────────────────────────────────────────
  // Dark
  // ─────────────────────────────────────────────

  static const darkBackground = Color(0xFF0E0E11);
  static const darkSurface = Color(0xFF1D1C22);
  static const darkSurfaceMuted = Color(0xFF25242B);

  static const darkText = Color(0xFFF9F9FA);
  static const darkTextSecondary = Color(0xFFA7A4AE);

  static const darkBorder = Color(0xFF34323C);

  // ─────────────────────────────────────────────
  // Semantic
  // ─────────────────────────────────────────────

  static const income = lime;
  static const expense = pink;
  static const transfer = purpleLight;
  static const warning = Color(0xFFFFC857);

  // ─────────────────────────────────────────────
  // Charts
  // ─────────────────────────────────────────────

  /// Ordem padrão para gráficos de categorias.
  static const chartColors = <Color>[
    purple,
    pink,
    lime,
    green,
    orange,
    teal,
    indigo,
    purpleLight,
  ];
}

/// Controle simples de tema para o MVP.
///
/// Depois vamos persistir esta escolha no perfil do usuário.
abstract final class AppThemeController {
  static final ValueNotifier<ThemeMode> mode = ValueNotifier(
    ThemeMode.system,
  );

  static void toggle(BuildContext context) {
    mode.value = Theme.of(context).brightness == Brightness.dark
        ? ThemeMode.light
        : ThemeMode.dark;
  }
}

abstract final class AppTheme {
  // ─────────────────────────────────────────────
  // Light
  // ─────────────────────────────────────────────

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppPalette.purple,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppPalette.purple,
      onPrimary: Colors.white,
      secondary: AppPalette.lime,
      onSecondary: AppPalette.lightText,
      tertiary: AppPalette.pink,
      surface: AppPalette.lightSurface,
      onSurface: AppPalette.lightText,
      error: AppPalette.pink,
    );

    return _baseTheme(
      scheme: scheme,
      scaffoldBackground: AppPalette.lightBackground,
      inputFill: AppPalette.lightSurface,
      border: AppPalette.lightBorder,
      cardColor: AppPalette.lightSurface,
      brightness: Brightness.light,
    );
  }

  // ─────────────────────────────────────────────
  // Dark
  // ─────────────────────────────────────────────

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppPalette.purple,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppPalette.purpleLight,
      onPrimary: Colors.white,
      secondary: AppPalette.lime,
      onSecondary: AppPalette.darkBackground,
      tertiary: AppPalette.pink,
      surface: AppPalette.darkSurface,
      onSurface: AppPalette.darkText,
      error: AppPalette.pink,
    );

    return _baseTheme(
      scheme: scheme,
      scaffoldBackground: AppPalette.darkBackground,
      inputFill: AppPalette.darkSurfaceMuted,
      border: AppPalette.darkBorder,
      cardColor: AppPalette.darkSurface,
      brightness: Brightness.dark,
    );
  }

  // ─────────────────────────────────────────────
  // Shared
  // ─────────────────────────────────────────────

  static ThemeData _baseTheme({
    required ColorScheme scheme,
    required Color scaffoldBackground,
    required Color inputFill,
    required Color border,
    required Color cardColor,
    required Brightness brightness,
  }) {
    final isDark = brightness == Brightness.dark;

    final primaryTextColor =
        isDark ? AppPalette.darkText : AppPalette.lightText;

    final secondaryTextColor = isDark
        ? AppPalette.darkTextSecondary
        : AppPalette.lightTextSecondary;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBackground,
      cardColor: cardColor,
      dividerColor: border,

      // Enquanto não adicionarmos legalmente o arquivo da Cooper BT,
      // mantemos a fonte nativa. Depois configuraremos Cooper BT
      // apenas em títulos/branding e uma sans limpa no restante.
      textTheme: TextTheme(
        displayLarge: TextStyle(
          color: primaryTextColor,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.4,
        ),
        displayMedium: TextStyle(
          color: primaryTextColor,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.1,
        ),
        headlineLarge: TextStyle(
          color: primaryTextColor,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
        ),
        headlineMedium: TextStyle(
          color: primaryTextColor,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          color: primaryTextColor,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          color: primaryTextColor,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(
          color: primaryTextColor,
        ),
        bodyMedium: TextStyle(
          color: primaryTextColor,
        ),
        bodySmall: TextStyle(
          color: secondaryTextColor,
        ),
        labelLarge: TextStyle(
          color: primaryTextColor,
          fontWeight: FontWeight.w700,
        ),
      ),

      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: border,
          ),
        ),
      ),

      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: border,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: scheme.primary,
            width: 1.5,
          ),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          backgroundColor: AppPalette.purple,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurface,
          backgroundColor: isDark
              ? AppPalette.darkSurfaceMuted
              : AppPalette.lightSurfaceMuted,
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppPalette.purple,
        linearTrackColor: isDark
            ? AppPalette.darkSurfaceMuted
            : AppPalette.lightSurfaceMuted,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(
          alpha: isDark ? .20 : .12,
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w500,
          ),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
    );
  }
}