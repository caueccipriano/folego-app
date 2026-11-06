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
  test('Prisma Pastel e modo automático são o padrão', () async {
    final repo = AppPreferenceRepository(_MemoryStore());
    expect(await repo.loadThemeMode(), ThemeMode.system);
    expect(await repo.loadPaletteId(), 'prisma_pastel');
  });

  test('tema e modo claro/escuro/sistema persistem independentemente', () async {
    final store = _MemoryStore();
    final repo = AppPreferenceRepository(store);
    await repo.saveThemeMode(ThemeMode.dark);
    await repo.savePaletteId('velvet_berry');
    expect(await repo.loadThemeMode(), ThemeMode.dark);
    expect(await repo.loadPaletteId(), 'velvet_berry');

    await repo.saveThemeMode(ThemeMode.light);
    expect(await repo.loadPaletteId(), 'velvet_berry');
    await repo.savePaletteId('hyperblue');
    expect(await repo.loadThemeMode(), ThemeMode.light);
    expect(await repo.loadPaletteId(), 'hyperblue');

    await repo.saveThemeMode(ThemeMode.system);
    expect(await repo.loadThemeMode(), ThemeMode.system);
    expect(await repo.loadPaletteId(), 'hyperblue');
  });

  test('preferências antigas migram preservando o modo', () async {
    final store = _MemoryStore();
    final repo = AppPreferenceRepository(store);
    store.values[AppPreferenceRepository.paletteKey] = 'cherry';
    store.values[AppPreferenceRepository.themeKey] = 'dark';
    expect(await repo.loadPaletteId(), 'velvet_berry');
    expect(await repo.loadThemeMode(), ThemeMode.dark);
    store.values[AppPreferenceRepository.paletteKey] = 'fluxo';
    expect(await repo.loadPaletteId(), 'ink');
    await repo.savePaletteId('folego');
    expect(store.values[AppPreferenceRepository.paletteKey], 'prisma_pastel');
  });

  test('tema desconhecido retorna Prisma Pastel sem mudar o modo', () async {
    final repo = AppPreferenceRepository(_MemoryStore());
    await repo.saveThemeMode(ThemeMode.dark);
    await repo.savePaletteId('tema-desconhecido');
    expect(await repo.loadThemeMode(), ThemeMode.dark);
    expect(await repo.loadPaletteId(), 'prisma_pastel');
  });
}
