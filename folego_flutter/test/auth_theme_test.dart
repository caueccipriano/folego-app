import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:folego/core/theme/app_theme.dart';

void main() {
  test('tema padrão selecionável no startup é ThemeMode.system', () {
    AppThemeController.setDark();
    AppThemeController.setSystem();
    expect(AppThemeController.mode.value, ThemeMode.system);
  });
}
