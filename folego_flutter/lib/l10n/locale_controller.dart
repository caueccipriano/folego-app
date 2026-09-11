import 'package:flutter/material.dart';

class LocaleController {
  LocaleController._();

  static final ValueNotifier<Locale?> locale = ValueNotifier<Locale?>(null);

  static void useSystem() {
    locale.value = null;
  }

  static void usePortuguese() {
    locale.value = const Locale('pt', 'BR');
  }

  static void useEnglish() {
    locale.value = const Locale('en');
  }

  static void useSpanish() {
    locale.value = const Locale('es');
  }
}
