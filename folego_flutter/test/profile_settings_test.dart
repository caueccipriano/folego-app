import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:folego/core/app_info/app_version_info.dart';
import 'package:folego/core/layout/app_breakpoints.dart';
import 'package:folego/core/preferences/app_preferences.dart';
import 'package:folego/data/models/profile_export.dart';
import 'package:folego/data/models/profile_identity.dart';
import 'package:folego/features/profile/profile_actions.dart';

class _MemoryPreferenceStore implements AppPreferenceStore {
  final Map<String, String> values = {};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }
}

void main() {
  group('Profile appearance preferences', () {
    test('defaults to ThemeMode.system without stored preference', () async {
      final repository = AppPreferenceRepository(_MemoryPreferenceStore());
      expect(await repository.loadThemeMode(), ThemeMode.system);
    });

    test('persists light, dark and system choices', () async {
      final store = _MemoryPreferenceStore();
      final repository = AppPreferenceRepository(store);

      await repository.saveThemeMode(ThemeMode.light);
      expect(await repository.loadThemeMode(), ThemeMode.light);

      await repository.saveThemeMode(ThemeMode.dark);
      expect(await repository.loadThemeMode(), ThemeMode.dark);

      await repository.saveThemeMode(ThemeMode.system);
      expect(await repository.loadThemeMode(), ThemeMode.system);
    });
  });

  group('Profile language preferences', () {
    test('defaults to system and maps every supported locale', () async {
      final repository = AppPreferenceRepository(_MemoryPreferenceStore());
      expect(
        await repository.loadLanguagePreference(),
        AppLanguagePreference.system,
      );
      expect(localeForLanguagePreference(AppLanguagePreference.system), isNull);
      expect(
        localeForLanguagePreference(AppLanguagePreference.portugueseBrazil),
        const Locale('pt', 'BR'),
      );
      expect(
        localeForLanguagePreference(AppLanguagePreference.english),
        const Locale('en'),
      );
      expect(
        localeForLanguagePreference(AppLanguagePreference.spanish),
        const Locale('es'),
      );
    });

    test('persists pt_BR, en, es and system', () async {
      final store = _MemoryPreferenceStore();
      final repository = AppPreferenceRepository(store);

      for (final preference in AppLanguagePreference.values) {
        await repository.saveLanguagePreference(preference);
        expect(await repository.loadLanguagePreference(), preference);
      }
    });
  });

  group('Profile identity', () {
    test('shows full name and two initials when available', () {
      const identity = ProfileIdentity(
        fullName: 'Cauê Cipriano',
        email: 'caue@example.com',
      );
      expect(identity.displayName, 'Cauê Cipriano');
      expect(identity.initials, 'CC');
      expect(identity.email, 'caue@example.com');
    });

    test('falls back to email local part when name is absent', () {
      const identity = ProfileIdentity(email: 'caue@example.com');
      expect(identity.displayName, 'caue');
      expect(identity.initials, 'CA');
    });

    test('uses neutral fallback without name or email', () {
      const identity = ProfileIdentity(email: '');
      expect(identity.displayName, 'Você');
    });
  });

  group('Profile CSV export', () {
    test('filters rows outside the selected space', () {
      final rows = parseProfileExportRows(
        [
          {
            'space_id': 'space-a',
            'event_type': 'expense',
            'description': 'Mercado',
            'amount': 20,
            'occurred_at': '2026-09-15T10:00:00-03:00',
            'status': 'confirmed',
            'source': 'app',
          },
          {
            'space_id': 'space-b',
            'event_type': 'income',
            'description': 'Outro espaço',
            'amount': 999,
            'occurred_at': '2026-09-15T10:00:00-03:00',
            'status': 'confirmed',
            'source': 'app',
          },
        ],
        expectedSpaceId: 'space-a',
      );

      expect(rows, hasLength(1));
      expect(rows.single.description, 'Mercado');
    });

    test('exports readable headers, accents, comma and quotes safely', () {
      final csv = buildProfileExportCsv([
        ProfileExportRow(
          occurredAt: DateTime(2026, 9, 15, 12, 30),
          description: 'Café, "especial"',
          type: 'despesa',
          amount: 12.5,
          category: 'Alimentação',
          account: 'Conta São Paulo',
          card: 'Cartão',
          status: 'confirmed',
          source: 'app',
        ),
      ]);

      expect(csv.startsWith('\uFEFF'), isTrue);
      expect(csv, contains('"data";"descrição";"tipo";"valor"'));
      expect(csv, contains('"Café, ""especial"""'));
      expect(csv, contains('"Alimentação"'));
      expect(csv, contains('"12,50"'));
    });

    test('does not expose sensitive or technical columns', () {
      expect(profileExportHeaders, isNot(contains('id')));
      expect(profileExportHeaders, isNot(contains('space_id')));
      expect(profileExportHeaders, isNot(contains('token')));
      expect(profileExportHeaders, isNot(contains('jwt')));
      expect(profileExportHeaders, isNot(contains('metadata')));
    });
  });

  group('About app', () {
    test('loads version and build from package metadata', () async {
      final info = await AppVersionInfo.load(
        loader: () async => PackageInfo(
          appName: 'Fôlego',
          packageName: 'com.example.folego',
          version: '0.1.0',
          buildNumber: '1',
        ),
      );

      expect(info.appName, 'Fôlego');
      expect(info.version, '0.1.0');
      expect(info.versionLabel, 'versão 0.1.0 · build 1');
    });
  });

  group('Logout action', () {
    test('dispatches sign out only once while an action is running', () async {
      final completer = Completer<void>();
      var calls = 0;
      final action = ProfileLogoutAction(() {
        calls += 1;
        return completer.future;
      });

      final first = action.run();
      final second = await action.run();

      expect(action.isRunning, isTrue);
      expect(second, isFalse);
      expect(calls, 1);

      completer.complete();
      expect(await first, isTrue);
      expect(action.isRunning, isFalse);
    });
  });

  group('Profile responsive targets', () {
    test('keeps target phones compact and larger surfaces responsive', () {
      expect(AppBreakpoints.fromWidth(375), AppLayoutSize.compact);
      expect(AppBreakpoints.fromWidth(390), AppLayoutSize.compact);
      expect(AppBreakpoints.fromWidth(430), AppLayoutSize.compact);
      expect(AppBreakpoints.fromWidth(768), AppLayoutSize.medium);
      expect(AppBreakpoints.fromWidth(1280), AppLayoutSize.expanded);
      expect(AppBreakpoints.fromWidth(1600), AppLayoutSize.wide);
    });
  });
}
