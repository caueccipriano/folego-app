import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radii.dart';
import 'app_typography.dart';

/// ---------------------------------------------------------------------------
/// COMPATIBILIDADE TEMPORÁRIA
///
/// O design system oficial agora vive em [AppColors].
///
/// AppPalette continua existindo temporariamente porque componentes antigos
/// ainda fazem referência a ele. Conforme revisarmos as telas, essas chamadas
/// serão migradas para AppColors.
/// ---------------------------------------------------------------------------
abstract final class AppPalette {
  // Brand
  static const purple = AppColors.purpleLight;
  static const purpleLight = AppColors.purpleDark;

  static const primary = purple;
  static const lime = AppColors.lime;

  // Compatibilidade com componentes antigos.
  static const pink = Color(0xFFD4457A);
  static const green = Color(0xFF3B6D11);
  static const orange = Color(0xFFE8A87C);
  static const teal = Color(0xFF58A8A0);
  static const indigo = Color(0xFF5969C9);

  // Light
  static const lightBackground = AppColors.lightBackground;

  static const lightSurface = AppColors.lightSurface;

  static const lightSurfaceMuted = Color(0xFFF0ECE2);

  static const lightText = AppColors.lightPrimaryText;

  static const lightTextSecondary = AppColors.lightSecondaryText;

  static const lightBorder = AppColors.lightBorder;

  // Dark
  static const darkBackground = AppColors.darkBackground;

  static const darkSurface = AppColors.darkSurface;

  static const darkSurfaceMuted = Color(0xFF25252D);

  static const darkText = AppColors.darkPrimaryText;

  static const darkTextSecondary = AppColors.darkSecondaryText;

  static const darkBorder = AppColors.darkBorder;

  // Semânticas antigas
  static const income = AppColors.lime;
  static const expense = pink;
  static const transfer = AppColors.purpleDark;

  static const warning = Color(0xFFE8A87C);

  static const chartColors = <Color>[
    AppColors.purpleLight,
    AppColors.homeLight,
    AppColors.lime,
    AppColors.transportLight,
    AppColors.healthLight,
    teal,
    indigo,
    AppColors.purpleDark,
  ];
}

/// Controle de tema.
///
/// Dark Mode é a identidade principal do Fôlego.
/// Por enquanto a preferência ainda não é persistida.
abstract final class AppThemeController {
  static final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.dark);

  static void toggle(BuildContext context) {
    mode.value = Theme.of(context).brightness == Brightness.dark
        ? ThemeMode.light
        : ThemeMode.dark;
  }

  static void setDark() {
    mode.value = ThemeMode.dark;
  }

  static void setLight() {
    mode.value = ThemeMode.light;
  }

  static void setSystem() {
    mode.value = ThemeMode.system;
  }
}

abstract final class AppTheme {
  // ---------------------------------------------------------------------------
  // LIGHT
  // ---------------------------------------------------------------------------

  static ThemeData light() {
    const brightness = Brightness.light;

    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.purpleLight,
          brightness: brightness,
        ).copyWith(
          primary: AppColors.purpleLight,
          onPrimary: Colors.white,

          secondary: AppColors.lime,
          onSecondary: AppColors.darkBackground,

          surface: AppColors.lightSurface,
          onSurface: AppColors.lightPrimaryText,

          error: AppColors.lightExpenseText,
          onError: Colors.white,

          outline: AppColors.lightBorder,
          outlineVariant: AppColors.lightBorder,

          surfaceContainerHighest: AppColors.lightBackground,
        );

    return _baseTheme(
      scheme: scheme,
      brightness: brightness,
      scaffoldBackground: AppColors.lightBackground,
      surface: AppColors.lightSurface,
      border: AppColors.lightBorder,
      primaryText: AppColors.lightPrimaryText,
      secondaryText: AppColors.lightSecondaryText,
      primaryPurple: AppColors.purpleLight,
    );
  }

  // ---------------------------------------------------------------------------
  // DARK
  // ---------------------------------------------------------------------------

  static ThemeData dark() {
    const brightness = Brightness.dark;

    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.purpleDark,
          brightness: brightness,
        ).copyWith(
          primary: AppColors.purpleDark,
          onPrimary: AppColors.darkPrimaryText,

          secondary: AppColors.lime,
          onSecondary: AppColors.darkBackground,

          surface: AppColors.darkSurface,
          onSurface: AppColors.darkPrimaryText,

          error: AppColors.darkExpenseText,
          onError: AppColors.darkBackground,

          outline: AppColors.darkBorder,
          outlineVariant: AppColors.darkBorder,

          surfaceContainerHighest: AppColors.darkSurface,
        );

    return _baseTheme(
      scheme: scheme,
      brightness: brightness,
      scaffoldBackground: AppColors.darkBackground,
      surface: AppColors.darkSurface,
      border: AppColors.darkBorder,
      primaryText: AppColors.darkPrimaryText,
      secondaryText: AppColors.darkSecondaryText,
      primaryPurple: AppColors.purpleDark,
    );
  }

  // ---------------------------------------------------------------------------
  // SHARED
  // ---------------------------------------------------------------------------

  static ThemeData _baseTheme({
    required ColorScheme scheme,
    required Brightness brightness,
    required Color scaffoldBackground,
    required Color surface,
    required Color border,
    required Color primaryText,
    required Color secondaryText,
    required Color primaryPurple,
  }) {
    final baseTextTheme = ThemeData(
      useMaterial3: true,
      brightness: brightness,
    ).textTheme;

    final textTheme = AppTypography.textTheme(
      baseTextTheme,
      primaryText: primaryText,
      secondaryText: secondaryText,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,

      scaffoldBackgroundColor: scaffoldBackground,

      cardColor: surface,
      canvasColor: scaffoldBackground,
      dividerColor: border,

      // -----------------------------------------------------------------------
      // TIPOGRAFIA
      //
      // Manrope é aplicada à interface.
      // Unbounded entra automaticamente nas hierarquias definidas em
      // AppTypography.
      // -----------------------------------------------------------------------
      textTheme: textTheme,

      primaryTextTheme: textTheme,

      // -----------------------------------------------------------------------
      // APP BAR
      // -----------------------------------------------------------------------
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: primaryText,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: primaryText),
        iconTheme: IconThemeData(color: primaryText),
      ),

      // -----------------------------------------------------------------------
      // CARDS
      // -----------------------------------------------------------------------
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: BorderSide(color: border),
        ),
      ),

      // -----------------------------------------------------------------------
      // INPUTS
      // -----------------------------------------------------------------------
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,

        labelStyle: textTheme.bodyMedium?.copyWith(color: secondaryText),

        hintStyle: textTheme.bodyMedium?.copyWith(color: secondaryText),

        helperStyle: textTheme.bodySmall,

        errorStyle: textTheme.bodySmall?.copyWith(color: scheme.error),

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: BorderSide(color: border),
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: BorderSide(color: border),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: BorderSide(color: primaryPurple, width: 1.5),
        ),

        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: BorderSide(color: scheme.error),
        ),

        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
      ),

      // -----------------------------------------------------------------------
      // FILLED BUTTON
      // -----------------------------------------------------------------------
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          elevation: 0,

          backgroundColor: primaryPurple,

          foregroundColor: brightness == Brightness.dark
              ? AppColors.darkPrimaryText
              : Colors.white,

          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.compactCard),
          ),
        ),
      ),

      // -----------------------------------------------------------------------
      // TEXT BUTTON
      // -----------------------------------------------------------------------
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryPurple,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
        ),
      ),

      // -----------------------------------------------------------------------
      // OUTLINED BUTTON
      // -----------------------------------------------------------------------
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryText,

          side: BorderSide(color: border),

          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.compactCard),
          ),
        ),
      ),

      // -----------------------------------------------------------------------
      // ICON BUTTON
      // -----------------------------------------------------------------------
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: secondaryText,
          minimumSize: const Size(44, 44),
          tapTargetSize: MaterialTapTargetSize.padded,
          highlightColor: primaryPurple.withValues(alpha: .10),
        ),
      ),

      // -----------------------------------------------------------------------
      // SWITCHES
      // -----------------------------------------------------------------------
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return secondaryText.withValues(alpha: .45);
          }
          if (states.contains(WidgetState.selected)) {
            return brightness == Brightness.dark
                ? AppColors.darkPrimaryText
                : Colors.white;
          }
          return secondaryText;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return border.withValues(alpha: .45);
          }
          if (states.contains(WidgetState.selected)) {
            return primaryPurple.withValues(alpha: .42);
          }
          return surface;
        }),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed) ||
              states.contains(WidgetState.focused)) {
            return primaryPurple.withValues(alpha: .10);
          }
          return null;
        }),
      ),

      // -----------------------------------------------------------------------
      // SEGMENTED BUTTONS
      // -----------------------------------------------------------------------
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return primaryPurple.withValues(
                alpha: brightness == Brightness.dark ? .18 : .10,
              );
            }
            return surface;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? primaryPurple
                : primaryText;
          }),
          side: WidgetStatePropertyAll(BorderSide(color: border)),
          textStyle: WidgetStatePropertyAll(
            textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ),

      // -----------------------------------------------------------------------
      // CHIPS
      // -----------------------------------------------------------------------
      chipTheme: ChipThemeData(
        backgroundColor: surface,

        selectedColor: primaryPurple.withValues(
          alpha: brightness == Brightness.dark ? .18 : .10,
        ),

        disabledColor: surface,

        side: BorderSide(color: border),

        labelStyle: textTheme.labelMedium?.copyWith(color: primaryText),

        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: primaryText,
        ),

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.pill)),

        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),

      // -----------------------------------------------------------------------
      // DIALOGS
      // -----------------------------------------------------------------------
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,

        titleTextStyle: textTheme.titleLarge?.copyWith(color: primaryText),

        contentTextStyle: textTheme.bodyMedium?.copyWith(color: secondaryText),

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.feature),
          side: BorderSide(color: border),
        ),
      ),

      // -----------------------------------------------------------------------
      // BOTTOM SHEETS
      // -----------------------------------------------------------------------
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,

        surfaceTintColor: Colors.transparent,

        showDragHandle: true,

        dragHandleColor: secondaryText.withValues(alpha: .45),

        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.sheet)),
        ),
      ),

      // -----------------------------------------------------------------------
      // PROGRESS
      // -----------------------------------------------------------------------
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primaryPurple,

        linearTrackColor: border.withValues(alpha: .55),
      ),

      // -----------------------------------------------------------------------
      // NAVIGATION
      // -----------------------------------------------------------------------
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,

        elevation: 0,

        indicatorColor: primaryPurple.withValues(
          alpha: brightness == Brightness.dark ? .18 : .10,
        ),

        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? primaryPurple
                : secondaryText,
          );
        }),

        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return textTheme.labelSmall?.copyWith(
            color: states.contains(WidgetState.selected)
                ? primaryPurple
                : secondaryText,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
          );
        }),
      ),

      // -----------------------------------------------------------------------
      // DIVIDERS
      // -----------------------------------------------------------------------
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),

      // -----------------------------------------------------------------------
      // SNACKBAR
      // -----------------------------------------------------------------------
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,

        backgroundColor: brightness == Brightness.dark
            ? AppColors.darkSurface
            : AppColors.lightPrimaryText,

        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: brightness == Brightness.dark
              ? AppColors.darkPrimaryText
              : Colors.white,
        ),

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.control)),
      ),
    );
  }
}
