import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/preferences/app_preferences.dart';

Map<String, dynamic> _arb(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

Set<String> _messageKeys(Map<String, dynamic> arb) => arb.keys
    .where((key) => !key.startsWith('@'))
    .toSet();

void main() {
  test('all translation workspaces keep the same message keys', () {
    final pt = _messageKeys(_arb('lib/l10n/app_pt_BR.arb'));
    final en = _messageKeys(_arb('lib/l10n/app_en.arb'));
    final es = _messageKeys(_arb('lib/l10n/app_es.arb'));

    expect(en, pt);
    expect(es, pt);
  });

  test('incomplete languages stay hidden from production', () {
    expect(
      productionSupportedLocales,
      const <Locale>[Locale('pt', 'BR')],
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
}
