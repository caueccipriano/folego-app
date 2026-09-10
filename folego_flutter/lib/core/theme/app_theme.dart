import 'package:flutter/material.dart';

/// Design system do Fôlego.
///
/// Direção visual: "pop criativo sofisticado" — cores alegres, porém menos
/// saturadas/neon, com boa leitura nos modos claro e escuro.
abstract final class AppPalette {
  static const primary = Color(0xFF3157D5);
  static const primaryDeep = Color(0xFF2847B5);
  static const purple = Color(0xFF7659C5);
  static const pink = Color(0xFFD56C9F);
  static const lime = Color(0xFFA6BF5B);
  static const green = Color(0xFF5DAA72);
  static const orange = Color(0xFFD89B67);
  static const teal = Color(0xFF5F9FA0);
  static const indigo = Color(0xFF6877C7);

  static const lightBackground = Color(0xFFF6F7FB);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceMuted = Color(0xFFF0F2F8);
  static const lightBorder = Color(0xFFE3E6EF);
  static const lightText = Color(0xFF14182A);
  static const lightTextMuted = Color(0xFF687086);

  static const darkBackground = Color(0xFF101424);
  static const darkSurface = Color(0xFF171B2E);
  static const darkSurfaceMuted = Color(0xFF20253D);
  static const darkBorder = Color(0xFF2A304D);
  static const darkText = Color(0xFFF7F8FC);
  static const darkTextMuted = Color(0xFFB8C0D4);

  /// Ordem sugerida para gráficos por categoria.
  /// Alimentação, Moradia, Saúde, Transporte e categorias adicionais.
  static const chartColors = <Color>[
    primary,
    purple,
    pink,
    lime,
    orange,
    teal,
    indigo,
    green,
  ];
}

/// Controle de tema simples para o MVP.
/// Depois podemos persistir a escolha do usuário no perfil/local storage.
abstract final class AppThemeController {
  static final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.system);

  static void toggle(BuildContext context) {
    mode.value = Theme.of(context).brightness == Brightness.dark
        ? ThemeMode.light
        : ThemeMode.dark;
  }
}

abstract final class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppPalette.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppPalette.primary,
      secondary: AppPalette.purple,
      tertiary: AppPalette.pink,
      surface: AppPalette.lightSurface,
      onSurface: AppPalette.lightText,
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

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppPalette.primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: const Color(0xFF7892E9),
      secondary: const Color(0xFFA992E1),
      tertiary: const Color(0xFFE09ABC),
      surface: AppPalette.darkSurface,
      onSurface: AppPalette.darkText,
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

  static ThemeData _baseTheme({
    required ColorScheme scheme,
    required Color scaffoldBackground,
    required Color inputFill,
    required Color border,
    required Color cardColor,
    required Brightness brightness,
  }) {
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBackground,
      cardColor: cardColor,
      dividerColor: border,
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: border),
        ),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          backgroundColor: AppPalette.primary,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurface,
          backgroundColor: isDark
              ? AppPalette.darkSurfaceMuted.withValues(alpha: .78)
              : AppPalette.lightSurfaceMuted.withValues(alpha: .88),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppPalette.primary,
        linearTrackColor: isDark
            ? AppPalette.darkSurfaceMuted
            : AppPalette.lightSurfaceMuted,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: isDark ? .24 : .12),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
