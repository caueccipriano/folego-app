import 'package:flutter/foundation.dart';

/// Controle de privacidade financeira em memória.
///
/// O estado é global durante a sessão do app para que Home, Carteira,
/// Lançamentos e demais superfícies usem a mesma preferência.
abstract final class FinancialPrivacy {
  static final ValueNotifier<bool> hidden = ValueNotifier<bool>(false);

  static void toggle() {
    hidden.value = !hidden.value;
  }

  static String maskMoney() => 'R\$ ••••';
}
