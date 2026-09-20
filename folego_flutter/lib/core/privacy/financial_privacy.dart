import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controle global de privacidade financeira.
///
/// A preferência é persistida no dispositivo para que o usuário não precise
/// ocultar os valores novamente a cada abertura do PWA.
abstract final class FinancialPrivacy {
  static const _key = 'folego.financial_values_hidden';
  static final _preferences = SharedPreferencesAsync();
  static final ValueNotifier<bool> hidden = ValueNotifier<bool>(false);

  static Future<void> initialize() async {
    try {
      hidden.value = await _preferences.getBool(_key) ?? false;
    } catch (_) {
      hidden.value = false;
    }
  }

  static void toggle() {
    hidden.value = !hidden.value;
    unawaited(_preferences.setBool(_key, hidden.value));
  }

  static String maskMoney() => 'R\$ ••••';
}
