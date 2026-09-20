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

/// Idiomas expostos como completos no produto.
///
/// Inglês e espanhol já têm a infraestrutura/arquivos-base preparados, mas a
/// interface ainda contém textos legados hardcoded em português. Até a
/// cobertura chegar a 100%, o app não deve oferecer uma experiência híbrida.
const productionSupportedLocales = <Locale>[Locale('pt', 'BR')];

bool isProductionReadyLanguage(AppLanguagePreference preference) =>
    preference == AppLanguagePreference.system ||
    preference == AppLanguagePreference.portugueseBrazil;

AppLanguagePreference normalizeLanguagePreference(
  AppLanguagePreference preference,
) {
  if (isProductionReadyLanguage(preference)) return preference;
  return AppLanguagePreference.portugueseBrazil;
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
  static const firstRunIntroKey = 'folego.first_run_intro_seen';
  static const rememberedEmailKey = 'folego.auth.remembered_email';

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
    final normalized = normalizeLanguagePreference(preference);
    return _store.setString(
      languageKey,
      languagePreferenceValue(normalized),
    );
  }

  Future<bool> loadFirstRunIntroSeen() async {
    return await _store.getString(firstRunIntroKey) == 'true';
  }

  Future<void> saveFirstRunIntroSeen(bool value) {
    return _store.setString(firstRunIntroKey, value ? 'true' : 'false');
  }

  Future<String?> loadRememberedEmail() async {
    final value = (await _store.getString(rememberedEmailKey))?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  Future<void> saveRememberedEmail(String? email) {
    return _store.setString(rememberedEmailKey, email?.trim() ?? '');
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
    // Builds anteriores permitiam selecionar EN/ES com cobertura parcial.
    // Normalize silenciosamente para PT-BR para impedir uma UI misturada.
    case 'en':
    case 'es':
      return AppLanguagePreference.portugueseBrazil;
    case 'system':
    default:
      return AppLanguagePreference.system;
  }
}

String languagePreferenceValue(AppLanguagePreference preference) {
  switch (normalizeLanguagePreference(preference)) {
    case AppLanguagePreference.system:
      return 'system';
    case AppLanguagePreference.portugueseBrazil:
      return 'pt_BR';
    case AppLanguagePreference.english:
    case AppLanguagePreference.spanish:
      return 'pt_BR';
  }
}

Locale? localeForLanguagePreference(AppLanguagePreference preference) {
  switch (normalizeLanguagePreference(preference)) {
    case AppLanguagePreference.system:
      return null;
    case AppLanguagePreference.portugueseBrazil:
      return const Locale('pt', 'BR');
    case AppLanguagePreference.english:
    case AppLanguagePreference.spanish:
      return const Locale('pt', 'BR');
  }
}

abstract final class AppPreferences {
  static final AppPreferenceRepository _repository = AppPreferenceRepository(
    SharedPreferencesPreferenceStore(),
  );

  static final ValueNotifier<AppLanguagePreference> languagePreference =
      ValueNotifier<AppLanguagePreference>(AppLanguagePreference.system);
  static final ValueNotifier<bool> firstRunIntroSeen = ValueNotifier<bool>(false);

  static Future<void> initialize() async {
    var themeMode = ThemeMode.system;
    var language = AppLanguagePreference.system;
    var introSeen = false;

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

    try {
      introSeen = await _repository.loadFirstRunIntroSeen();
    } catch (_) {
      introSeen = false;
    }

    _applyTheme(themeMode);
    _applyLanguage(language);
    firstRunIntroSeen.value = introSeen;
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    _applyTheme(mode);
    await _repository.saveThemeMode(mode);
  }

  static Future<void> setLanguagePreference(
    AppLanguagePreference preference,
  ) async {
    final normalized = normalizeLanguagePreference(preference);
    _applyLanguage(normalized);
    await _repository.saveLanguagePreference(normalized);
  }

  static Future<void> markFirstRunIntroSeen() async {
    firstRunIntroSeen.value = true;
    await _repository.saveFirstRunIntroSeen(true);
  }

  static Future<String?> loadRememberedEmail() {
    return _repository.loadRememberedEmail();
  }

  static Future<void> setRememberedEmail(String? email) {
    return _repository.saveRememberedEmail(email);
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
    final normalized = normalizeLanguagePreference(preference);
    languagePreference.value = normalized;

    switch (normalized) {
      case AppLanguagePreference.system:
        LocaleController.useSystem();
        break;
      case AppLanguagePreference.portugueseBrazil:
        LocaleController.usePortuguese();
        break;
      case AppLanguagePreference.english:
      case AppLanguagePreference.spanish:
        LocaleController.usePortuguese();
        break;
    }
  }
}
