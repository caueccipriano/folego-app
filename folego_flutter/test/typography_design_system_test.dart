import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/theme/app_color_tokens.dart';
import 'package:folego/core/theme/app_theme.dart';
import 'package:folego/core/theme/app_typography.dart';

void main() {
  test('15 paletas compartilham o mesmo sistema tipográfico', () {
    for (final palette in FolegoColorTokens.catalog) {
      for (final brightness in Brightness.values) {
        final tokens = FolegoColorTokens.fromId(palette.id, brightness);
        final textTheme = AppTypography.textTheme(
          ThemeData(brightness: brightness).textTheme,
          primaryText: tokens.textoPrincipal,
          secondaryText: tokens.textoSecundario,
        );
        expect(textTheme.displayLarge?.fontFamily, 'Unbounded');
        expect(textTheme.headlineLarge?.fontFamily, 'Unbounded');
        expect(textTheme.titleLarge?.fontFamily, 'Manrope');
        expect(textTheme.titleMedium?.fontFamily, 'Manrope');
        expect(textTheme.bodyMedium?.fontFamily, 'Manrope');
        expect(textTheme.labelMedium?.fontSize, 12);
        expect(textTheme.bodySmall?.color, tokens.textoSecundario);
      }
    }
  });

  testWidgets('hierarquia de cifras responsiva e alinhamento tabular',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Builder(builder: (context) {
        final compact = AppTypography.money(context, fontSize: 11);
        final card = AppTypography.money(context, fontSize: 21);
        final hero = AppTypography.money(
          context,
          fontSize: 44,
          color: const Color(0xFFB9C255),
        );
        final title = AppTypography.cardTitle(context);
        final editorial = AppTypography.section(context);
        expect(compact.fontFamily, 'Manrope');
        expect(compact.fontSize, 13);
        expect(compact.fontWeight, FontWeight.w700);
        expect(card.fontWeight, FontWeight.w800);
        expect(card.letterSpacing, -.4);
        expect(hero.fontSize, 44);
        expect(hero.fontWeight, FontWeight.w800);
        expect(hero.height, 1.08);
        expect(hero.letterSpacing, -1.0);
        expect(hero.color, const Color(0xFFB9C255));
        expect(hero.fontFeatures, contains(const FontFeature.tabularFigures()));
        expect(hero.fontFeatures, contains(const FontFeature.liningFigures()));
        expect(title.fontFamily, 'Manrope');
        expect(title.fontWeight, FontWeight.w700);
        expect(editorial.fontFamily, 'Unbounded');
        return const SizedBox();
      }),
    ));
  });

  test('Home, Carteira e prévia usam tokens tipográficos comuns', () {
    final home = File('lib/features/home/home_screen_base.dart').readAsStringSync();
    final wallet = File('lib/features/wallet/wallet_screen_base.dart').readAsStringSync();
    final preview = File('lib/features/profile/profile_widgets.dart').readAsStringSync();
    expect(home, contains('AppTypography.cardTitle('));
    expect(wallet, contains('AppTypography.money(sheetContext, fontSize: 14)'));
    expect(preview, contains('AppTypography.money('));
    expect(preview, contains('AppTypography.cardTitle('));
  });
}
