import 'dart:async';
import 'dart:io';

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
    test('only exposes locales with complete product coverage', () async {
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
      expect(productionSupportedLocales, const <Locale>[Locale('pt', 'BR')]);
      expect(
        isProductionReadyLanguage(AppLanguagePreference.portugueseBrazil),
        isTrue,
      );
      expect(
        isProductionReadyLanguage(AppLanguagePreference.english),
        isFalse,
      );
      expect(
        isProductionReadyLanguage(AppLanguagePreference.spanish),
        isFalse,
      );
    });

    test('normalizes legacy partial EN and ES preferences to pt_BR', () async {
      final store = _MemoryPreferenceStore();
      final repository = AppPreferenceRepository(store);

      store.values[AppPreferenceRepository.languageKey] = 'en';
      expect(
        await repository.loadLanguagePreference(),
        AppLanguagePreference.portugueseBrazil,
      );

      store.values[AppPreferenceRepository.languageKey] = 'es';
      expect(
        await repository.loadLanguagePreference(),
        AppLanguagePreference.portugueseBrazil,
      );

      expect(
        localeForLanguagePreference(AppLanguagePreference.english),
        const Locale('pt', 'BR'),
      );
      expect(
        localeForLanguagePreference(AppLanguagePreference.spanish),
        const Locale('pt', 'BR'),
      );
    });

    test('does not persist a partially translated locale', () async {
      final store = _MemoryPreferenceStore();
      final repository = AppPreferenceRepository(store);

      await repository.saveLanguagePreference(AppLanguagePreference.english);
      expect(
        store.values[AppPreferenceRepository.languageKey],
        'pt_BR',
      );
      expect(
        await repository.loadLanguagePreference(),
        AppLanguagePreference.portugueseBrazil,
      );
    });
  });

  group('Remembered login email', () {
    test('persists trimmed email and clears it safely', () async {
      final store = _MemoryPreferenceStore();
      final repository = AppPreferenceRepository(store);

      await repository.saveRememberedEmail('  teste@example.com ');
      expect(await repository.loadRememberedEmail(), 'teste@example.com');

      await repository.saveRememberedEmail(null);
      expect(await repository.loadRememberedEmail(), isNull);
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

  group('Profile account-dialog contracts', () {
    test('email and password errors stay inline and destructive dialogs scroll', () {
      final source = File(
        'lib/features/profile/profile_screen_v2.dart',
      ).readAsStringSync();

      expect(source, contains('errorText: emailError'));
      expect(source, contains('errorText: passwordError'));
      expect(source, contains('errorText: confirmationError'));
      expect(source, contains('setDialogState(() => emailError = error)'));
      expect(source, contains('siga as confirmações enviadas por e-mail'));

      final changeEmail = source.indexOf('Future<void> _changeEmail()');
      final changePassword = source.indexOf('Future<void> _changePassword()');
      final deleteAccount = source.indexOf('Future<void> _deleteAccount()');

      expect(changeEmail, greaterThanOrEqualTo(0));
      expect(changePassword, greaterThan(changeEmail));
      expect(deleteAccount, greaterThan(changePassword));

      final emailBlock = source.substring(changeEmail, changePassword);
      final passwordBlock = source.substring(changePassword, deleteAccount);
      final deleteBlock = source.substring(
        deleteAccount,
        source.indexOf('Future<void> _confirmSignOut()', deleteAccount),
      );

      expect(emailBlock, contains('scrollable: true'));
      expect(passwordBlock, contains('scrollable: true'));
      expect(deleteBlock, contains('scrollable: true'));
      expect(deleteBlock, contains("typed == 'APAGAR'"));
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
