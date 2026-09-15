import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';
import '../../l10n/locale_controller.dart';

enum AppLanguagePreference {
  system,
  portugueseBrazil,
  english,
  spanish,
}

abstract interface class AppPreferenceStore {
  Future<String?> getString(String key);

  Future<void> setString(String key, String value);
}

final class SharedPreferencesPreferenceStore implements AppPreferenceStore {
  SharedPreferencesPreferenceStore({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> getString(String key) => _preferences.getString(key);

  @override
  Future<void> setString(String key, String value) {
    return _preferences.setString(key, value);
  }
}

final class AppPreferenceRepository {
  AppPreferenceRepository(this._store);

  static const themeKey = 'folego.theme_mode';
  static const languageKey = 'folego.language';

  final AppPreferenceStore _store;

  Future<ThemeMode> loadThemeMode() async {
    return themeModeFromPreference(await _store.getString(themeKey));
  }

  Future<void> saveThemeMode(ThemeMode mode) {
    return _store.setString(themeKey, themeModePreferenceValue(mode));
  }

  Future<AppLanguagePreference> loadLanguagePreference() async {
    return languageFromPreference(await _store.getString(languageKey));
  }

  Future<void> saveLanguagePreference(AppLanguagePreference preference) {
    return _store.setString(
      languageKey,
      languagePreferenceValue(preference),
    );
  }
}

ThemeMode themeModeFromPreference(String? value) {
  switch (value) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    case 'system':
    default:
      return ThemeMode.system;
  }
}

String themeModePreferenceValue(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return 'light';
    case ThemeMode.dark:
      return 'dark';
    case ThemeMode.system:
      return 'system';
  }
}

AppLanguagePreference languageFromPreference(String? value) {
  switch (value) {
    case 'pt_BR':
      return AppLanguagePreference.portugueseBrazil;
    case 'en':
      return AppLanguagePreference.english;
    case 'es':
      return AppLanguagePreference.spanish;
    case 'system':
    default:
      return AppLanguagePreference.system;
  }
}

String languagePreferenceValue(AppLanguagePreference preference) {
  switch (preference) {
    case AppLanguagePreference.system:
      return 'system';
    case AppLanguagePreference.portugueseBrazil:
      return 'pt_BR';
    case AppLanguagePreference.english:
      return 'en';
    case AppLanguagePreference.spanish:
      return 'es';
  }
}

Locale? localeForLanguagePreference(AppLanguagePreference preference) {
  switch (preference) {
    case AppLanguagePreference.system:
      return null;
    case AppLanguagePreference.portugueseBrazil:
      return const Locale('pt', 'BR');
    case AppLanguagePreference.english:
      return const Locale('en');
    case AppLanguagePreference.spanish:
      return const Locale('es');
  }
}

abstract final class AppPreferences {
  static final AppPreferenceRepository _repository = AppPreferenceRepository(
    SharedPreferencesPreferenceStore(),
  );

  static final ValueNotifier<AppLanguagePreference> languagePreference =
      ValueNotifier<AppLanguagePreference>(AppLanguagePreference.system);

  static Future<void> initialize() async {
    var themeMode = ThemeMode.system;
    var language = AppLanguagePreference.system;

    try {
      themeMode = await _repository.loadThemeMode();
    } catch (_) {
      themeMode = ThemeMode.system;
    }

    try {
      language = await _repository.loadLanguagePreference();
    } catch (_) {
      language = AppLanguagePreference.system;
    }

    _applyTheme(themeMode);
    _applyLanguage(language);
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    _applyTheme(mode);
    await _repository.saveThemeMode(mode);
  }

  static Future<void> setLanguagePreference(
    AppLanguagePreference preference,
  ) async {
    _applyLanguage(preference);
    await _repository.saveLanguagePreference(preference);
  }

  static void _applyTheme(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        AppThemeController.setSystem();
        break;
      case ThemeMode.light:
        AppThemeController.setLight();
        break;
      case ThemeMode.dark:
        AppThemeController.setDark();
        break;
    }
  }

  static void _applyLanguage(AppLanguagePreference preference) {
    languagePreference.value = preference;

    switch (preference) {
      case AppLanguagePreference.system:
        LocaleController.useSystem();
        break;
      case AppLanguagePreference.portugueseBrazil:
        LocaleController.usePortuguese();
        break;
      case AppLanguagePreference.english:
        LocaleController.useEnglish();
        break;
      case AppLanguagePreference.spanish:
        LocaleController.useSpanish();
        break;
    }
  }
}
