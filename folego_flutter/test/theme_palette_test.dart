import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/theme/app_color_tokens.dart';
import 'package:folego/core/theme/app_theme.dart';

void main() {
  test('24 paletas coerentes com 2 modos e tokens completos', () {
    expect(FolegoColorTokens.catalog.map((p) => p.id).toSet().length, 24);
    for (final palette in FolegoColorTokens.catalog) {
      for (final brightness in Brightness.values) {
        final t = FolegoColorTokens.fromId(palette.id, brightness);
        final context = '${palette.name} $brightness';
        expect(FolegoColorTokens.contrastRatio(t.textoPrincipal, t.superficie),
          greaterThanOrEqualTo(4.5), reason: '$context texto');
        expect(FolegoColorTokens.contrastRatio(t.textoSecundario, t.superficie),
          greaterThanOrEqualTo(4.5), reason: '$context secundario');
        expect(FolegoColorTokens.contrastRatio(t.marca, t.superficie),
          greaterThanOrEqualTo(4.5), reason: '$context marca na superficie');
        expect(FolegoColorTokens.contrastRatio(t.marca, t.fundo),
          greaterThanOrEqualTo(4.5), reason: '$context marca no fundo');
        expect(FolegoColorTokens.contrastRatio(t.marcaSobre, t.marca),
          greaterThanOrEqualTo(4.5), reason: '$context marca');
        expect(FolegoColorTokens.contrastRatio(t.acaoSobre, t.acao),
          greaterThanOrEqualTo(4.5), reason: '$context acao');
        expect(FolegoColorTokens.contrastRatio(t.marcaHeroSobre, t.marcaHero),
          greaterThanOrEqualTo(4.5), reason: '$context hero');
        for (final value in [t.folga, t.apertado, t.estourado]) {
          expect(FolegoColorTokens.contrastRatio(value, t.superficie),
            greaterThanOrEqualTo(4.5), reason: '$context estado na superficie');
        }
        for (final value in [t.folgaHero, t.apertadoHero, t.estouradoHero]) {
          expect(FolegoColorTokens.contrastRatio(value, t.marcaHero),
            greaterThanOrEqualTo(3.0), reason: '$context estado no hero');
        }
      }
    }
  });

  test('cada paleta tem sua própria base clara e escura', () {
    final lightBackgrounds = <Color>{};
    final darkBackgrounds = <Color>{};
    for (final palette in FolegoColorTokens.catalog) {
      final light = FolegoColorTokens.fromId(palette.id, Brightness.light);
      final dark = FolegoColorTokens.fromId(palette.id, Brightness.dark);
      expect(light.fundo, isNot(dark.fundo), reason: palette.name);
      expect(light.superficie, isNot(dark.superficie), reason: palette.name);
      expect(light.marcaHero, isNot(dark.marcaHero), reason: palette.name);
      expect(palette.description, isNotEmpty);
      expect(lightBackgrounds.add(light.fundo), isTrue,
        reason: 'fundo claro repetido: ${palette.name}');
      expect(darkBackgrounds.add(dark.fundo), isTrue,
        reason: 'fundo escuro repetido: ${palette.name}');
    }
    // Preferências antigas permanecem estáveis ao ampliar o catálogo.
    for (final id in [
      'folego', 'mare', 'salvia', 'chiclete', 'tangerina', 'neon'
    ]) {
      expect(FolegoColorTokens.palette(id).id, id);
    }
    for (final id in [
      'safira', 'mochi', 'cacau',
      'matcha', 'pixel', 'cherry', 'butter', 'orbit', 'disco',
    ]) {
      expect(FolegoColorTokens.palette(id).id, id);
    }
  });

  test('nove novas paletas preservam cores das referências Gen Z', () {
    final expected = <String, Color>{
      'highlighter': const Color(0xFFFFD200),
      'pomar': const Color(0xFFFFCA26),
      'voltagem': const Color(0xFFCDF22B),
      'cosmos': const Color(0xFFE3A750),
      'mostarda': const Color(0xFFF2D04E),
      'groovy': const Color(0xFFFF7A1A),
      'atelie': const Color(0xFFFA2D1A),
      'contraste': const Color(0xFFF94500),
      'terra': const Color(0xFFEACB91),
    };
    for (final entry in expected.entries) {
      final palette = FolegoColorTokens.palette(entry.key);
      expect(palette.id, entry.key);
      expect(palette.action, entry.value, reason: entry.key);
      expect(palette.description, isNotEmpty);
      final light = FolegoColorTokens.fromId(entry.key, Brightness.light);
      final dark = FolegoColorTokens.fromId(entry.key, Brightness.dark);
      expect(light.fundo, isNot(dark.fundo));
      expect(light.superficie, isNot(dark.superficie));
      expect(FolegoColorTokens.contrastRatio(light.acaoHero, light.marcaHero),
        greaterThanOrEqualTo(4.5), reason: '${entry.key} claro');
      expect(FolegoColorTokens.contrastRatio(dark.acaoHero, dark.marcaHero),
        greaterThanOrEqualTo(4.5), reason: '${entry.key} escuro');
    }
  });

  test('ThemeData aplica tokens da própria paleta, sem herdar cores da anterior', () {
    final previous = AppColorSelection.selected.value;
    addTearDown(() => AppColorSelection.choose(previous));
    for (final palette in FolegoColorTokens.catalog) {
      AppColorSelection.choose(palette.id);
      for (final brightness in Brightness.values) {
        final theme = brightness == Brightness.dark
            ? AppTheme.dark() : AppTheme.light();
        final tokens = FolegoColorTokens.fromId(palette.id, brightness);
        expect(theme.scaffoldBackgroundColor, tokens.fundo);
        expect(theme.cardColor, tokens.superficie);
        expect(theme.colorScheme.primary, tokens.marca);
        expect(theme.colorScheme.secondary, tokens.acao);
        expect(theme.colorScheme.tertiary, tokens.acao);
        expect(theme.colorScheme.onSurface, tokens.textoPrincipal);
        expect(theme.colorScheme.surfaceContainer, tokens.superficie);
        expect(theme.colorScheme.surfaceContainerHigh, tokens.superficieAlta);
        expect(theme.colorScheme.onPrimaryContainer, tokens.textoPrincipal);
        expect(theme.colorScheme.onSecondaryContainer, tokens.textoPrincipal);
        expect(FolegoColorTokens.contrastRatio(
          theme.colorScheme.secondaryContainer,
          theme.colorScheme.onSecondaryContainer,
        ), greaterThanOrEqualTo(4.5));
        expect(theme.extension<FolegoColorTokens>()?.marcaHero, tokens.marcaHero);
      }
    }
  });

  test('seleção não modifica cores semânticas de estado', () {
    for (final brightness in Brightness.values) {
      final baseline = FolegoColorTokens.fromId('mare', brightness);
      for (final palette in FolegoColorTokens.catalog) {
        final t = FolegoColorTokens.fromId(palette.id, brightness);
        expect(t.folga, baseline.folga);
        expect(t.apertado, baseline.apertado);
        expect(t.estourado, baseline.estourado);
      }
    }
  });
}
