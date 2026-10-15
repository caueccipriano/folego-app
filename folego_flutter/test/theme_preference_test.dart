import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/preferences/app_preferences.dart';

class _MemoryStore implements AppPreferenceStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }
}

void main() {
  test('paleta e modo persistem independentemente', () async {
    final store = _MemoryStore();
    final preferences = AppPreferenceRepository(store);
    expect(await preferences.loadThemeMode(), ThemeMode.system);
    expect(await preferences.loadPaletteId(), 'folego');

    await preferences.saveThemeMode(ThemeMode.dark);
    await preferences.savePaletteId('mare');
    expect(await preferences.loadThemeMode(), ThemeMode.dark);
    expect(await preferences.loadPaletteId(), 'mare');

    await preferences.saveThemeMode(ThemeMode.light);
    expect(await preferences.loadPaletteId(), 'mare');
    await preferences.savePaletteId('chiclete');
    expect(await preferences.loadThemeMode(), ThemeMode.light);
    expect(await preferences.loadPaletteId(), 'chiclete');
  });

  test('paleta desconhecida volta para Fôlego sem alterar o modo', () async {
    final preferences = AppPreferenceRepository(_MemoryStore());
    await preferences.saveThemeMode(ThemeMode.dark);
    await preferences.savePaletteId('tema-desconhecido');
    expect(await preferences.loadThemeMode(), ThemeMode.dark);
    expect(await preferences.loadPaletteId(), 'folego');
  });
}
